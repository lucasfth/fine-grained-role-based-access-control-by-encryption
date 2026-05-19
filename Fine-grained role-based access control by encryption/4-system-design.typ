#import "cmds.typ": todo, martinFeedback, delete, speculation

= System Design
<sec:system-design>

OSWS set out to provide columnar access control to 3rd party query engines and "fully managed all-in-one cloud platforms" by encrypting columns individually using PME, provided through the Parquet Sharp library, see~@sec:encryption-flow.
But due to how some of these work on specific query engines can work with OSWS, see~@sec:discussion for more info.
// bedre? ↑ Trøstrup resten af infoen er rykket til diskussion
Though some changes can be made to bridge these two different design choices, see more in~@sec:discussion.
What the current OSWS solves is that query engines, which read metadata from object storage and do not use cached values, will have columnar access control enforced on the data they read.
This ensures that, from the query engine's perspective, they are using S3 directly, but in reality use OSWS, and they can now read and write data to S3 as usual, but role-based access control is ensured on the column level.
So if you have a dataset with columns `name`, `birthday`, and `relational status`, and the query engine is not granted access to `birthday`, it will receive, depending on the setup of OSWS, all columns, but `birthday` will be either null values or an encrypted column.

Below, the design choices will be described in more depth, together with deeper technical information.

== Architecture Overview

OSWS is set up as a wrapper for S3 and thereby provides S3-compatible API endpoints for clients.
The purpose of OSWS is to provide column-level access controls to S3, whilst not modifying the S3 API.
This ensures that most S3-compatible query engines are able to use OSWS without modifications and that they will only be able to read what they are supposed to.

The system is built on ASP.NET Core 10 using the minimal API pattern@minimal-api, which replaces traditional MVC with lightweight endpoint definitions.
OSWS uses: PME via. Parquet Sharp, PostgreSQL for RBAC metadata, Azure KV for key management, and a configurable S3-compatible Object Store (tested with Cloudflare R2 and Digital Ocean Spaces).#footnote[Codebase available at #link("https://github.com/lucasfth/osws")[github.com/lucasfth/osws]]

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
#speculation[This is mistakenly done by taking their first role, but should have been tied to their base role instead.
] // DIS OKAY?
Then the Parquet solver is given the file and role, so it can generate new DEKs per column and a KEK for the Parquet file.
The RBAC store is updated with the new columns and key references, and the file is encrypted afterwards.
It also handles wrapping the keys initially so the wrapped DEKs can be put into the metadata, and KEK is given to the key manager to insert into KV.

This allows OSWS to ensure fine-grained role-based access control in data lakes, but of course, there are more in-depth design choices that have been made to make this work, both for better and worse.

== Design Choices

#include "4-system-design/osws-architecture-overview.typ"

=== Database Design

#include "4-system-design/er-diagram.typ"

An Entity Relationship describing the database design can be seen in @er-diagram.
The database is mostly used for RBAC metadata; however, it also stores credentials used for AWS Signature V4 request signing, see @sec:sigv4, and external identity information from the OpenID Provider(s).

=== Role Hierarchy

OSWS also supports Hierarchical RBAC through the `RoleInheritance` tables. This is a self-referential table in which a hierarchical relation is created through the `ParentRoleId` and `ChildRoleId` foreign keys, so that a _parent_ inherits from a `child` (see `RoleInheritance` in @er-diagram.) This means that all permissions of _child_ also become permissions of _parent_.
To get the full set of effective roles for a user, a recursive SQL query is used to navigate the hierarchy. This can be seen in @listing:effective-roles.
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
Then _U1_ would see a table full of valid _names_ whilst _age_ and _civil\_personal\_register_ are either null values or some dummy encrypted values (depends on the configuration of OSWS), while _U2_ would see _age_ and _civil\_personal\_register_ values.

== Caching

There are two tiers to the caching system used within OSWS with the intention of minimizing latency from remote services.

=== Encrypted File Cache

Given the configuration of OSWS, the Parquet files fetched from the object store can be cached.
It uses the LRU (Least Recently Used) policy to cache the encrypted Parquet files on the local file system.
They are keyed with `SHA256(bucket::key)`, see `OSWS.ParquetSolver/Helpers/EncryptedFileCache.cs`.

=== DEK Cache

Unwrapped DEKs are cached in-memory to avoid repeated calls to KV, as it is one of the major latency attributes, see @sec:benchmarking.
The cached DEK is keyed with the KEK identifier, and in the configuration, the TTL can be defined for regular and admin users, as admin users' keys are most often more privileged.
The cache enforces a maximum capacity and evicts the expired entries first and then the oldest entries by expiration date.

=== Envelope Encryption

To encrypt the Parquet columns, OSWS needs to use DEKs and KEKs to achieve envelope encryption@azure_envelope_encryption.
This deviates from the original proposed solution in Trøstrup~and~Hanson~@own-paper, as KV does not support key retrieval, and the overhead of sending a Parquet column to KV each time for decryption and encryption is high.
By using envelope encryption, OSWS can cache the unwrapped DEKs with a specified TTL to allow quicker decryption.
This results in a solution with little overhead, more about this in~@sec:e2e-bench, and ensuring column-level access control.

=== Parquet Solver

Parquet Solver handles the cryptographic operations for the Parquet files.
Important design decisions made here are that it uses Parquet Sharp.
Parquet Sharp was chosen as it supports PME, but does not support partial decryption/reads of Parquet files.
This results in the fact that when a Parquet file has to be decrypted, it essentially decrypts and copies over all the columns into a new Parquet file.
But it does not support copying over the columns which are not supposed to be decrypted.
As a result, dummy columns are created, and given the setup of OSWS, they are encrypted and copied over into the new Parquet file.

This is one of the design choices made that later created more problems than it solved.

=== Authentication

Due to S3 requiring signage, the calls from the clients going to OSWS are signed as well, and as a result, OSWS cannot reuse the signature and encrypt the Parquet columns.
Internal authentications were therefore needed, and OSWS then has its own signature for S3.

=== AWS Signature V4 (S3 API)
<sec:sigv4>

Because OSWS had to use an S3-compatible API, it also had to use the same validation as S3.
A custom `SigV4AuthenticationHandler` has been created to parse the authorization header and extract the `AccessKeyId`.
The keys corresponding to the `S3Credential` record are then looked up in the internal PostgreSQL, see the `S3Credential` table in @er-diagram.
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

In @sec:background-rbac, RBAC is defined to consist of: _users_, _roles_, _permissions_, _operations_, _objects_ and _sessions_. Our implementation of RBAC follows this mostly, but differs in a few ways. In @er-diagram, the core RBAC entities are shown: the tables `User`, `Role`, `RoleAssignment`, `RoleInheritance`, `Column`, and `Permission`.
`User` and `Role` have a many-to-many relationship through `RoleAssignment`.
Likewise, `Role` and `Column` have a many-to-many relationship through `Permission`.
The `Column` table can be seen as the _object_ of Core RBAC, as it is currently the only secured object to which access is controlled. There is however, no concept of _operations_, only whether or not access is granted. 
There is also no formal concept of _sessions_ as described by Ferraiolo~et~al.@ferraiolo1992rbac; however, when a user is authenticated through their S3 Credential, their assigned roles are loaded. In this way, it can be seen as an activation of all the users assigned roles.

=== Key Hierarchy

The KEK sizes are specified within the KV that the admin chooses.
Due to having student credits available in Azure, which was only available for a low-cost KV, RSA-2048 was used.
The KEKs are created in OSWS (inside `OSWS.KeyManager/Providers/AzureKeyVaultProvider`), but after that, the KEK never leaves KV again, and are then called by OSWS to wrap and unwrap the DEKs.

For the DEKs OSWS, create these themselves.
These symmetric AES keys have sizes 128, 192, or 256, and are created during the encryption of Parquet files.

=== Administrative Endpoints

Endpoints for admin endpoints are restricted to only users who have the `IsRbacAdmin` flag, seen in the `User` table in @er-diagram. This field is populated from the `ClaimsPrincipal` when provisioning the user in the `/api/me` route. Thus, it requires the OIDC Provider to include this claim on users who should have admin access. Alternatively, it can be set manually.

#include "4-system-design/administrative-endpoints.typ"

=== Frontend Architecture

A frontend for interacting with the endpoints described in @tab:applications-endpoints and @tab:admin-endpoints was built using Typescript-React. To quickly create a user-friendly working prototype, UI components from the open-source project `shadcn` @shadcn was used. A user can login using PocketID, as described in @sec:oidc. Here, the user can create credentials to be used for the S3-Compatible API endpoint. If the user is an RBAC Admin, they get access to the admin panel for managing roles.
The admin panel includes a table view for viewing currently existing users, roles, columns and permissions.
To interact with the endpoints described in @tab:admin-endpoints, a "query editor" was built to manage RBAC operations in an SQL-like syntax, reminiscent of the syntax used to manage permissions in e.g. PostgreSQL.#footnote[#link("https://www.postgresql.org/docs/current/sql-grant.html")] Using the JavaScript library `peggyjs` @peggyjs, a simple grammar was written to parse statements into API calls. Some example statements to configure RBAC permissions and the API calls they parse to can be seen in @listing:peggy.
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

// DELETE FROM SYSD2 =============================================================================================
#delete[OSWS consists of the five main components, see~@fig:osws-architecture-overview.

The data flow for a read request is as follows: the client sends an S3 `GetObject` request to the Encryption Gateway, which authenticates via SigV4.
Then the gateway retrieves the encrypted Parquet file from the Object Store - checking the file cache first.
The DEKs, which the client has access to, are sent to KV to get unwrapped if they were not found in the DEK cache.
The "Parquet Solver" then decrypts the available columns and replaces any that cannot be decrypted.
The new Parquet file is now returned to the client.

For a write request, the client uploads a Parquet file via. `PutObject`.
The "Parquet Solver" encrypts the columns with newly generated DEKs, wraps them via. KV, and stored the wrapped DEKs inside the Parquet files.
Columns and permissions are persisted inside the RBAC database.

=== Key Manager
<sec:osws-keymanager>

The Key Manager provides an abstraction over cryptographic key storage and the relational model.

- `AzureKeyVaultProvider`: Implements `IKeyVaultProvider`.
  It creates keys (which are defined in `OSWS.Common/Configuration/EncryptionSettings`) in Azure Key Vault, performs the wrap and unwrap of the DEKs server-side, using the algorithm defined within `OSWS.ParquetSolver/Helpers/Cryptography`.
- `InternalKeyVaultProvider`: Implements `IKeyVaultProvider`.
  It works the same as `AzureKeyVaultProvider` but runs on OSWS itself.\
  As long as `IKeyVaultProvider` is implemented together with a key vault provider, which means it supports the following functions: encrypt, decrypt, get key info, and list keys, most providers should be able to be used.
- `OswsContext`: Implements `DbContext`.
  Defines the relational schema over PostgreSQL, including users, roles, role assignments, role inheritance, permissions, columns, keys, external identities, and S3 credentials.

=== Shared Libraries

- `OSWS.Models` defines all the DTOs and entities used within the solution.
- `OSWS.Common` contain classes containing settings for the project, including. `EncryptionSettings`, `CacheSettings`, `S3Settings`, `KeyVaultSettings`, and `RateLimitSettings`.
  They are bound to `appsettings.json` at startup, and they also include validation logic for the configuration.
- `OSWS.Library` has utility helpers for AWS credential normalization, S3 metadata translation, HTTP range request parsing, parameter validation, and XML extensions.

=== Encryption Flow
#label("sec:encryption-flow")

The encryption flow works as follows:

+ Client uploads unencrypted Parquet file, via `PUT /s3/{bucket}/{key}`.
+ OSWS creates an RSA-2048 key and is tagged with the uploading user's role.
+ For each column designated for encryption, an AES DEK of specified sizes is generated and encrypted, within `OSWS.ParquetSolver/Helpers/Cryptography`.
+ Each DEK are then wrapped by using the KV, then serialized, and put into the footer of the Parquet file.
+ The encrypted Parquet file is then written using Parquet Sharp.
+ Parquet file is then sent to the S3-compatible object store.
+ Columns, key IDs, and permissions are persisted in local PostgreSQL.

=== Decryption Flow

The decryption flow works as follows:

+ The client requests a Parquet file, via `GET /s3/{bucket}/{key}`.
+ OSWS fetches the encrypted Parquet file, first tries in local cache, then if not found, it goes to S3-compatible object store (see `OSWS.WebApi/Services/Services/S3ObjectFetcher`)
+ Wrapped DEKs are read from the Parquet footer.
+ For each wrapped DEK, OSWS checks the in-memory DEK cache.
  On a cache miss, it calls the KV decrypt method to unwrap the DEK and caches the result.
+ The user's effective roles are computed via @listing:effective-roles.
+ The permitted columns are now decrypted, while the others are replaced by dummy columns#footnote[Due to limitations in Parquet Sharp, it is not possible to leave the encrypted column alone, and thus has to be replaced.]
+ The decrypted Parquet stream is returned to the client.

== API

OSWS exposes three different endpoint groups.

=== S3-Compatible Endpoints

A subset of S3 required endpoints is implemented to allow for the object store operations.
These operations can be seen in @tab:s3-compatible-endpoints.

#include "4-system-design/s3-compatible-endpoints.typ"

Currently, non-Parquet files pass through the encryption step, and the endpoints defined are only to allow operations made by most query engines, and thus suffice for making an MVP.
In the future, this should be extended to also allow non-Parquet files to be encrypted and then include the KEK reference within the Parquet file referencing it, and the endpoints should also be extended.

=== Application Endpoints

OIDC-protected endpoints for the web frontend.
See the endpoints in @tab:applications-endpoints.

#include "4-system-design/application-endpoints.typ"


]// DELETE SYSD2 all to here, I guess ===========================================================================
