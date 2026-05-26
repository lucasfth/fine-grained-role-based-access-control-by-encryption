#import "cmds.typ": todo, martinFeedback, delete, speculation

= System Design
<sec:system-design>

What the current OSWS solves is that query engines, which read metadata from Object Store and do not use cached values, will have columnar access control enforced on the data they read.
This ensures that, from the query engine's perspective, they are using S3 directly, but in reality use OSWS, and it can enforce whatever RBAC rules it wants on the clients.
So if you have a dataset with columns `name`, `birthday`, and `relational status`, and the query engine is not granted access to `birthday`, it will receive all columns, but `birthday` will have null or another default value.

Below, the design choices will be described in more depth, together with deeper technical information.

== Architecture Overview

OSWS is set up as a wrapper for S3 and thereby provides S3-compatible API endpoints for clients.
The purpose of OSWS is to provide column-level access controls to S3, whilst not modifying the S3 API.
This ensures that most S3-compatible query engines can use OSWS without modification and will only read what they are supposed to.

The system is built on ASP.NET Core 10 using the minimal API pattern@minimal-api, which replaces traditional MVC with lightweight endpoint definitions.
OSWS uses: PME via. Parquet Sharp, PostgreSQL for RBAC metadata, Azure KV for key management, and a configurable S3-compatible Object Store (tested with Cloudflare R2 and Digital Oceans Spaces for benchmarking).#footnote[Codebase available at #link("https://github.com/lucasfth/osws")[github.com/lucasfth/osws]]

#figure(
  caption: [OSWS system components and their responsibilities],
  table(
    columns: (auto, 1fr),
    align: left + horizon,
    [*Component*], [*Responsibility*],
    [Encryption Gateway],
      [S3-compatible API host. Handles incoming `GetObject`/`PutObject` requests, enforces AWS Signature V4 authentication, and handles encryption, decryption, and column filtering.],
    [Parquet Solver],
      [Encrypts and decrypts Parquet files using PME with ParquetSharp.
      Generates DEKs, wraps them via the Key Manager, and masks unauthorized columns.],
    [Key Manager],
      [Manages cryptographic keys through Azure KV (or an internal provider).
      Wraps/unwraps DEKs using RSA-2048 KEKs stored in the vault.],
    [RBAC Store],
      [PostgreSQL database storing users, roles, role assignments, role inheritance, column permissions, and S3 credentials.
      Evaluated per-request to determine authorized columns.],
    [Admin Frontend],
      [React web UI for managing roles, permissions, and users. Uses OIDC authentication and provides a SQL-like query editor for RBAC operations.],
  ),
)<tab:components>

OSWS consists of the five main components, see~@fig:osws-architecture-overview or~@tab:components.

The *admin frontend* is for RBAC, thus managing roles, permissions, and users within the OSWS system, more specifically within the *RBAC store*, which is the database for storing these relations.
Here, it can be defined what columns a user can access later on and, by extension, which columns will be masked.

The *encryption gateway* is the entry point for retrieving and putting files into the actual S3.
It is responsible for delegating work to the other components, so encrypting and decrypting files, partially, is possible.
Whenever it receives a GET request, it will first get the file from S3 and see which columns the client is able to read, by using the *RBAC store*.
Then it will use the *Parquet solver*, which in turn will handle trying to identify which DEKs are in the Parquet file.
It can then go through the *key manager* to get the unwrapped DEKs based on permission level; it will check locally first, and if not stored, go to KV to get them unwrapped there, and store them for later use.
After the key manager returns the unwrapped DEKs, the Parquet solver can decrypt the columns and mask out the ones it cannot decrypt.
Now the encryption gateway can return the Parquet file, showing only the information that the client has access to.

When the encryption gateway gets a PUT request, it first gets the user's base role.
For testing purposes it was tied to the user's first role, but should have been tied to their base role or the one provided through the credential.
#todo[TRØLLE DO SOMSING]
Then the Parquet solver is given the file and role, so it can generate new DEKs per column and a KEK for the Parquet file.
The RBAC store is updated with the new columns and key references, and the file is encrypted afterwards.
It also handles wrapping the keys initially so the wrapped DEKs can be put into the metadata, and the KEK is given to the key manager to insert into KV.

This allows OSWS to ensure fine-grained role-based access control in data lakes, but of course, there are more in-depth design choices that have been made to make this work, both for better and worse.

== Design Choices

#include "4-system-design/osws-architecture-overview.typ"

=== Database Design

#include "4-system-design/er-diagram.typ"

An Entity Relationship describing the database design can be seen in @fig:er-diagram.
The database is mostly used for RBAC metadata; however, it also stores credentials used for AWS Signature V4 request signing, and external identity information from the OpenID Provider(s).

=== RBAC Metadata

In~@sec:background-rbac, RBAC is defined to consist of: _users_, _roles_, _permissions_, _operations_, _objects_ and _sessions_.
OSWS implements RBAC mostly following this, but it differs in a few ways.
In~@fig:er-diagram, the core RBAC entities are shown: the tables `User`, `Role`, `RoleAssignment`, `RoleInheritance`, `Column`, and `Permission`.
`User` and `Role` have a many-to-many relationship through `RoleAssignment`.
Likewise, `Role` and `Column` have a many-to-many relationship through `Permission`.
The `Column` table can be seen as the _object_ of Core RBAC, as it is currently the only secured object to which access is controlled. There is, however, no concept of _operations_, only whether or not access is granted. 
There is also no formal concept of _sessions_ as described by Ferraiolo~et~al.@ferraiolo1992rbac; however, when a user is authenticated through their S3 Credential, their assigned roles are loaded. In this way, it can be seen as an activation of all the users assigned roles.

=== Role Hierarchy

OSWS also supports Hierarchical RBAC through the `RoleInheritance` tables.
This is a self-referential table in which a hierarchical relation is created through the `ParentRoleId` and `ChildRoleId` foreign keys, so that a _parent_ inherits from a `child`, see `RoleInheritance` in~@fig:er-diagram.
This means that all permissions of _child_ also become permissions of _parent_.
To retrieve the full set of effective roles for a user, a recursive SQL query traverses the hierarchy. This can be seen in @listing:effective-roles.

#figure(
  kind: "listing",
  supplement: "Listing",
  caption: [A recursive SQL query to get the full set of effective roles given a `userId`.],
  (
    ```sql
  WITH RECURSIVE effective AS (
    SELECT ra."RoleId" AS "Id"
    FROM "RoleAssignments" ra
    WHERE ra."UserId" = {userId}
    UNION
    SELECT ri."ChildRoleId"
    FROM "RoleInheritances" ri
    JOIN effective e
    ON ri."ParentRoleId" = e."Id"
  )
  SELECT DISTINCT r."Id", r."Name"
  FROM "Roles" r
  JOIN effective e ON r."Id" = e."Id"
```
  )
)<listing:effective-roles>

=== Column-Level Permissions

Each _Permission_ record maps a _Role_ to a _Column_.
This means that a column is decrypted if and only if one of its roles grants access to the given column.
This ensures fine-grained access control.
If a Parquet file _P1_ with columns _name_, _age_, and _civil\_personal\_register_ exists.
Then a user _U1_ and a user _U2_ can respectively give access to role _R1_ and _R2_.
_R1_ provides access to only _name_ and _R2_ only to _age_ and _civil\_personal\_register_.
Then _U1_ would see a table full of valid _names_ whilst _age_ and _civil\_personal\_register_ are null/default values, while _U2_ would see _age_ and _civil\_personal\_register_ values.

== Caching

There are two tiers to the caching system used within OSWS with the intention of minimizing latency from remote services.

=== Encrypted File Cache

Given the configuration of OSWS, the Parquet files fetched from the Object Store can be cached.
It uses the Least Recently Used (LRU) policy to cache the encrypted Parquet files on the local file system.
Each Parquet file is then keyed with a tuple of the bucket name and its key, meaning that it uses the bucket name and the full path and file name to save the Parquet file - reflecting how S3 handles its internal naming.

=== DEK Cache

Unwrapped DEKs are cached in-memory to avoid repeated KV calls, as it is one of the major latency attributes, discussed later.
The cached DEK is keyed with the KEK identifier, and in the configuration, the TTL can be defined for regular and admin users, as admin users' keys are most often more privileged.
The cache enforces a maximum capacity and evicts the expired entries first, and then the oldest entries by expiration date.

=== Envelope Encryption

To encrypt the Parquet columns, OSWS needs to use DEKs and KEKs to achieve envelope encryption@azure_envelope_encryption.
This deviates from the original proposed solution in Trøstrup~and~Hanson@own-paper, as KV does not support key retrieval, and the overhead of sending a Parquet column to KV each time for decryption and encryption is high.
By using envelope encryption, OSWS can cache the unwrapped DEKs with a specified TTL to allow quicker decryption.
This results in a solution with lesser overhead and ensures column-level access control.

=== Parquet Solver

#todo[Inkluder en paragraf om hvordan vi storer metadata i parquet filen ift. hvordan forskellene er fra den "rigtige" spec og hvordan vi gør det. Hvis vi har overskud ville et diagram nok være nice]
Parquet Solver handles the cryptographic operations for the Parquet files.
Important design decisions made here are that it uses Parquet Sharp.
Parquet Sharp was chosen as it supports PME, but does not support partial decryption/reads of Parquet files.
This results in the fact that when a Parquet file has to be decrypted, it essentially decrypts and copies over all the columns into a new Parquet file.
But it does not support copying over the columns which are not supposed to be decrypted.
As a result, dummy columns are created and copied over into the new Parquet file.

This is one of the design choices made that later created more problems than it solved.

=== Authentication
<sec:sys-design:authentication>

Due to S3 requiring signage, the calls from the clients going to OSWS are signed as well, and as a result, OSWS cannot reuse the signature and encrypt the Parquet columns.
Internal authentications were therefore needed, and OSWS then has its own signature for S3.

#todo[Give some love. Skal den også delvist merges med Application Endpoints?? Nej Lukas bare nej. Ejj kan du ikke engang huske hvordan man staver mit navn 😢]

=== AWS Signature V4 (S3 API)
<sec:sigv4>

Because OSWS had to use an S3-compatible API, it also had to use the same validation as S3.
A custom `SigV4AuthenticationHandler` has been created to parse the authorization header and extract the `AccessKeyId`.
The keys corresponding to the `S3Credential` record are then looked up in the internal PostgreSQL, see the `S3Credential` table in~@fig:er-diagram.
The signature is verified using the stored secret key.
On success, a `ClaimsPrincipal` is created carrying the user's database ID, name, email, and default role.

This follows the AWS specification "Authenticating Requests (AWS Signature Version 4)"@aws_signiture_version_4.

=== OIDC
<sec:oidc>

The React frontend, for handling RBAC, uses OIDC for the authentication flow.
The OIDC provider chosen for OSWS is #link("https://pocket-id.org/")[Pocket ID], as it is simple to set up, is #link("https://github.com/pocket-id/pocket-id")[open-source], and uses passkeys, which are more secure than standard MFA, as "common multifactor authentication methods can be intercepted or relayed"@bitwarden_passkeys.

The backend still supports other OIDC providers.
To use other providers, `OSWS.WebApi/appsettings.json` needs to be updated to reflect the change, and the frontend `.env` has to point to the specified authority and client ID.

On the first login, the `api/me` endpoint triggers JIT provisioning, and a new `User` record and `ExternalIdentity` record are created in the database.
Subsequent logins will synchronize the OIDC provider's claims.

== RBAC
#todo[RBAC ting er blevet rykket, hvad skal dette afsnit være? nok rykkes rundt på nogle ting]


=== Key Hierarchy

The KEK sizes are specified within the KV that the admin chooses.
Azure KV is used to store the KEKs, chosen due to pricing, but is able to be switched out, and RSA-2048 is used for the keys.
The KEKs are created in OSWS, but after that, the KEK never leaves KV again, and are then called by OSWS to wrap and unwrap the DEKs, which themselves are stored within the Parquet metadata.
The DEKs are created within OSWS as well, use AES, and, based on the setup, can have sizes 128, 192, or 256, and are specifically created during the encryption flow.

=== Administrative Endpoints

Endpoints for admin endpoints are restricted to only users who have the `IsRbacAdmin` flag, seen in the `User` table in @fig:er-diagram. This field is populated from the `ClaimsPrincipal` when provisioning the user in the `/api/me` route. Thus, it requires the OIDC Provider to include this claim on users who should have admin access. Alternatively, it can be set manually.

#include "4-system-design/administrative-endpoints.typ"

=== Frontend Architecture
<sec:sys-design:fe>

A frontend for interacting with the endpoints described in @tab:applications-endpoints and @tab:admin-endpoints was built using Typescript-React.
A user can log in using Pocket ID, as described in @sec:oidc.
Here, the user can create credentials to be used for the S3-Compatible API endpoint.
If the user is an RBAC Admin, they get access to the admin panel for managing roles.
The admin panel includes a table view for viewing currently existing users, roles, columns and permissions.
To interact with the endpoints described in @tab:admin-endpoints, a "query editor" was built to manage RBAC operations in an SQL-like syntax, reminiscent of the syntax used to manage permissions in e.g. PostgreSQL.#footnote[#link("https://www.postgresql.org/docs/current/sql-grant.html")]
Using the JavaScript library `peggyjs` @peggyjs, a simple grammar was written to parse statements into API calls.
Some example statements to configure RBAC permissions and the API calls they parse can be seen in @listing:peggy.

#figure(
  kind: "listing",
  supplement: "Listing",
  caption: [Example statements and their parsed API calls],
  (```sql
CREATE ROLE admin;
=> POST /api/admin/roles { name: "admin" }
CREATE ROLE intern;
=> POST /api/admin/roles { name: "intern" }
GRANT intern TO ROLE admin;
=> POST /api/admin/roles/1/inherit/2
GRANT ACCESS ON name TO intern;
=> POST /api/admin/columns/1/roles/1
GRANT ACCESS ON ssn TO admin;
=> POST /api/admin/columns/2/roles/2
GRANT admin TO USER alice;
=> POST /api/admin/users/1/roles/1
```)
)<listing:peggy>


=== Encryption Flow
#label("sec:encryption-flow")

#import "4-system-design/crypto-flow.typ": encryptionFlow
#encryptionFlow

@fig:encryptionflow shows the flow of how encryption works in OSWS, from the client's PUT call to the client receiving an acknowledgement that it has been completed.
It follows the given flow:

+ Client uploads an unencrypted Parquet file to OSWS - through the encryption gateway
+ OSWS checks the client credentials and resolves their first role
+ OSWS encryption then hands over the work to the Parquet solver
+ OSWS Parquet solver generates a KEK, submits it to KV to get a reference ID
+ OSWS generates a DEK per column
+ All the DEKs are sent to KV to get wrapped
+ The Parquet file columns are encrypted and copied over to the new Parquet file, and the KEK ID and wrapped DEKs are saved within the Parquet metadata
+ The OSWS Parquet solver hands the work back to the OSWS Encryption gateway with relevant metadata
+ The OSWS Encryption gateway then persists the RBAC metadata
+ OSWS sends back the acknowledgement that it has been inserted

=== Decryption Flow

#import "4-system-design/crypto-flow.typ": decryptionFlow
#decryptionFlow

@fig:decryptionflow shows the flow of how decryption works in OSWS, from the client's GET call to them receiving a Parquet file back.
It follows the given flow:

+ Client requests a Parquet file to OSWS - through the encryption gateway
+ OSWS checks the client credentials and resolves which roles they have access to
+ OSWS then fetches the Parquet file from S3 - or from the disk cache if available
+ OSWS then starts to work on decrypting the file, given the allowed columns
  + For each authorized column, it goes to KV to get the related DEK unwrapped - if not already present in the in-memory DEK cache
  + The columns are now decrypted and copied into a new Parquet file, and for the ones where the unwrapped DEK is not there, a dummy column will be inserted in its place
+ The Parquet file is now created, and the requested range/whole file can now be returned to the client
  
== API

OSWS exposes three different endpoint groups.
These are either related to:

- Being S3 compliant and providing the endpoints to interact with the data lake
- Managing authentication, which, when using S3, is done by using IAM@iam
- Managing RBAC and access control, described in~@sec:sys-design:fe

=== S3-Compatible Endpoints

#include "4-system-design/s3-compatible-endpoints.typ"

For the S3 endpoints, only a subset of endpoints has been implemented to ensure Object Store operations would work and be S3 compatible.
The endpoints can be seen in~@tab:s3-compatible-endpoints.
This enables listing what is in the Object Store, and also the create, update, and delete operations.

Currently, non-Parquet files pass through the encryption step, and the endpoints defined are only to allow operations made by most query engines, and thus suffice for making an MVP.
In the future, this should be extended to also allow non-Parquet files to be encrypted and then include the KEK reference within the Parquet file referencing it, and the endpoints should also be extended.

=== Application Endpoints

#include "4-system-design/application-endpoints.typ"

Usually, when using S3, the AWS IAM solution is used.
But due to the previously mentioned rerouting limitation and OSWS signage, in~@sec:sys-design:authentication, it has to provide endpoints for the clients to use to authenticate against.
The endpoints provided can be seen in~@tab:applications-endpoints, and include listing the existing credentials, creating new ones, and deleting them.

== Limitations
<sec:sys-design:limitations>

OSWS set out to provide columnar access control to external query engines and "fully managed all-in-one cloud platforms" by encrypting columns individually using PME, provided through the Parquet Sharp library.
But due to early design decisions, this was not possible.
As OSWS uses Parquet Sharp and stores cryptographic keys within the metadata of the Parquet files, a few issues appear with some query engines.
First, Parquet Sharp uses Apache Arrow, which itself supports writing metadata.@ParquetSharp_2026-repo
This in itself makes sense, as it is possible by looking at e.g. `created_by` to see who created the Parquet file.@apache-arrow
But as Parquet Sharp needs to write when encrypting the Parquet file, the file is essentially changed with new metadata, and it will no longer be the same Parquet file that the query engine inserted.
This results in the fact that if the query engine stores metadata for ranges that are incorrect, which break their range requests.
On top of that, OSWS saves cryptographic-related metadata within the column metadata, and that is yet another modification.
As such, for this to work with all query engines, it would have to be ensured that all ranges of data remain the same, also after encryption.

The same issue is likely prevalent on most “fully managed all-in-one cloud platforms”, but it is not possible to test, due to it needing to have a URL whitelisted by the providers to test the OSWS system.
But given documentation of e.g. Snowflake, it seems to point towards incompatibility.@snowflake_external_tables@snowflake_external_tables_files

In~@sec:discussion, this will be discussed in more depth and possible solutions to bridge these two design incompatibilities.

Lastly, initially, it was intended to make OSWS return the encrypted columns.
But due to the limitations in Parquet Sharp, it was not possible, and the current solution is instead to create null/default (dummy) data entries for the column.
There is an unimplemented method ready to encrypt this dummy data to simulate the idea of returning encrypted data, but it was not implemented due to being redundant, as OSWS already had the previously mentioned limitations.
