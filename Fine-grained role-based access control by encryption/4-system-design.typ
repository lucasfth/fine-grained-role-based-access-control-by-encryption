#import "cmds.typ": todo, martinFeedback, delete, speculation, new

= System Design
<sec:system-design>
In this section, OSWS is designed and the reasoning for the choices made.

== Architecture Overview

OSWS is designed as a wrapper for S3 and thus provides S3-compatible API endpoints for clients.
The purpose of OSWS is to provide column-level access controls to S3, whilst not modifying the S3 API.
This ensures that most S3-compatible query engines can use OSWS without modification and will only read what they are supposed to.

The system is built on ASP.NET Core 10 using the minimal API pattern~@minimal-api, which replaces traditional MVC with lightweight endpoint definitions.
OSWS uses: PME via.
Parquet Sharp, PostgreSQL for RBAC metadata, Azure KV for key management, and a configurable S3-compatible Object Store (tested with Cloudflare R2 and Digital Ocean Spaces for benchmarking).

#include "4-system-design/osws-architecture-overview.typ"

#include "4-system-design/system-components.typ"

OSWS consists of five main components, each with its own responsibility for handling incoming requests, handling outgoing requests, or storing/modifying data.
A summary of each can be seen in @tab:components.
In addition, @fig:osws-architecture-overview shows external services as well, and how they interact with the core OSWS system.
The *Frontend* is for users to interact with the API. For regular users, it can be used to create S3 credentials for use with the *encryption gateway*.
For admins, it allows RBAC management, handling roles, permissions, and users within the OSWS system, specifically within the PostgreSQL *RBAC store*, the database that stores these relations.
Here, it can be defined what columns a user can access later on and, by extension, which columns will be masked.

The *encryption gateway* is the entry point for retrieving and putting files into the actual Object Store.
It is responsible for delegating work to the other components.
Whenever it receives a GET request, it will first get the file from the Object Store and see which columns the client is able to read by using the RBAC store.
Users authenticate using credentials generated in the frontend.
Then it will use the *Parquet Solver*,  which in turn will handle trying to identify which DEKs are in the Parquet file.
It can then go through the *Key Manager*, to get the unwrapped DEKs based on permission level; it will check the DEK cache first, and if not stored, go to KV to get them unwrapped there, and store them for later use.
After the key manager returns the unwrapped DEKs, the Parquet Solver can decrypt the columns and mask out the columns that the client is not authorized to view.
Now the encryption gateway can return the Parquet file, showing only the information that the client has access to.

When the encryption gateway gets a PUT request, it first gets the user's active role.
For the PoC, this was simply chosen to be the user's first available role, but optimally should have been selectable by the client.
Then the Parquet solver is given the file and role, so it can generate new DEKs per column and request a KEK for the Parquet file, through KV.
The RBAC store is updated with the new columns and key references, and the file is encrypted afterwards.
The DEKs are wrapped by the KEK using KV, to then save the wrapped version inside the Parquet metadata.

This allows OSWS to ensure fine-grained role-based access control in data lakes, but of course, there are more in-depth design choices that have been made to make this work, both for better and worse.

== Design Choices

=== Database Design

#include "4-system-design/er-diagram.typ"

An Entity Relationship Diagram describing the database design can be seen in~@fig:er-diagram.
The database is mostly used for RBAC metadata; however, it also stores credentials used for AWS Signature V4 request signing, and external identity information from the OpenID Provider(s).

=== RBAC Metadata

In~@sec:background-rbac, RBAC is defined to consist of: _users_, _roles_, _permissions_, _operations_, _objects_ and _sessions_.
OSWS implements RBAC mostly following this, but it differs in a few ways.
In~@fig:er-diagram, the core RBAC entities are shown: the tables `User`, `Role`, `RoleAssignment`, `RoleInheritance`, `Column`, and `Permission`.
`User` and `Role` have a many-to-many relationship through `RoleAssignment`.
Likewise, `Role` and `Column` have a many-to-many relationship through `Permission`.
The `Column` table can be seen as the _object_ of Core RBAC, as it is currently the only secured object to which access is controlled. There is, however, no concept of _operations_, only whether or not access is granted.
There is also no formal concept of _sessions_ as described by Ferraiolo~et.~al.~@ferraiolo1992rbac; however, when a user is authenticated through their S3 Credential, their assigned roles are loaded.
In this way, it can be seen as an activation of all the users assigned roles.

=== Role Hierarchy

#include "4-system-design/effective-roles.typ"

OSWS also supports Hierarchical RBAC through the `RoleInheritance` table.
This is a self-referential table in which a hierarchical relation is created through the `ParentRoleId` and `ChildRoleId` foreign keys, so that a _parent_ inherits from a _child_, see `RoleInheritance` in~@fig:er-diagram.
This means that all permissions of _child_ also become permissions of _parent_.
To retrieve the full set of effective roles for a user, a recursive SQL query traverses the hierarchy. This can be seen in~@listing:effective-roles.

=== Column-Level Permissions

Each _Permission_ record maps a _Role_ to a _Column_, giving fine-grained control over which columns a user can decrypt.

_Example:_ Given a Parquet file _P1_ with columns _name_, _age_, and _social_security_number_:

- Role _R1_ grants access to: _name_
- Role _R2_ grants access to: _age_, _social_security_number_

A user _U1_ assigned _R1_ sees valid _name_ values: _age_ and _social_security_number_ appear as nulls.
A user _U2_ assigned _R2_ sees the inverse: valid _age_ and _social_security_number_, with _name_ as null.

Furthermore, using the Role Hierarchy, role _R2_ can be made to inherit the permissions of _R1_. Thus, user _U2_ would see all columns, without needing the _R1_ role directly.

=== Encrypted File Cache

Given the configuration of OSWS, the Parquet files fetched from the Object Store can be cached.
It uses the Least Recently Used (LRU) policy to cache the encrypted Parquet files on the local file system.
Each Parquet file is then keyed with a tuple of the bucket name and its key, meaning that it uses the bucket name and the full path and file name to save the Parquet file, reflecting how S3 handles its internal naming.

=== DEK Cache

Unwrapped DEKs are cached in-memory to avoid repeated KV calls, as it is one of the major latency attributes, discussed later.
The cached DEK gets a unique identifier, which, along with the KEK identifier, is used as the cache key.
The cache enforces a maximum capacity and evicts the expired entries first, and then the oldest entries by their TTL.

=== Envelope Encryption

To encrypt the Parquet columns, OSWS needs to use DEKs and KEKs to achieve envelope encryption~@azure_envelope_encryption.
This deviates from the original proposed solution in Trøstrup~and~Hanson~@own-paper, as KV does not support key retrieval, and the overhead of sending a Parquet column to KV each time for decryption and encryption is high.
By using envelope encryption, OSWS can cache the unwrapped DEKs with a specified TTL to allow quicker decryption.
This results in a solution with lesser overhead.

=== Parquet Solver

Parquet Solver handles the cryptographic operations for the Parquet files.
Important design decisions made here are that it uses Parquet Sharp, specifically version 21.0.0.~@parquetsharp
Parquet Sharp was chosen as it supports PME, but does not support partial decryption/reads of Parquet files and thus has to decrypt and copy over all columns into a new Parquet file.
For the unauthorized columns, null, empty strings, or zeros (dummy data) have to be copied instead.

The choice of building around PME and Parquet Sharp turned out to be one of the design choices that later created more problems than it solved. This will be discussed in more detail later.

=== Authentication
<sec:sys-design:authentication>

Since OSWS provides an S3-compatible API, authentication must follow the Amazon Signature V4 scheme as well.
And, since OSWS rewrites the content and re-routes the request, the original signature is no longer valid, so OSWS needs its own credentials as well.
Thus, OSWS both needs to verify the client's request, and correctly sign the new request to the Object Store.

To support AWS Signature V4, a custom SigV4 authentication handler was implemented.
Using this, the corresponding `S3Credential` record is then looked up in the internal PostgreSQL database, displayed in~@fig:er-diagram.
The signature is verified using the stored secret key.
The signing process follows the specification defined in AWS Signature V4~@aws_signiture_version_4.
On success, the request is authenticated, and the user's information is resolved.

=== OIDC
<sec:oidc>

The React frontend, for handling RBAC, uses OIDC for the authentication flow.
The backend has been made to be OIDC provider-agnostic, and the users can bring their own provider of choice.
The desired provider can be changed through the application's configuration files.
While building the prototype, Pocket ID#footnote[https://github.com/pocket-id/pocket-id] was used as an OIDC Provider, due to being open-source and simple to set up.

On the first login, the `api/me` endpoint triggers JIT provisioning, and a new `User` record and `ExternalIdentity` record are created in the database.
Subsequent logins will synchronize the OIDC provider's claims.
The admins of the system can then define what the given clients can access in the admin frontend.

=== Key Hierarchy

The KEK sizes are specified within the KV that the admin chooses.
Azure KV is used to store the KEKs, chosen due to pricing, but is able to be switched out.
RSA-2048 keys are used with the RSA-OAEP-256 @rsa-rfc8017 encryption scheme for wrapping and unwrapping.
These are generated in the KV itself.

KV will then be called by OSWS to wrap and unwrap the DEKs, which themselves are stored within the Parquet metadata.
The DEKs are created within OSWS as well, and use AES
Based on the setup, they can have sizes 128, 192, or 256 bits, and are specifically created during the encryption flow.

=== Frontend Architecture
<sec:sys-design:fe>

A frontend for managing credentials and for admins, managing RBAC, was created using TypeScript with React.
A user can log in using Pocket ID as an OIDC provider.
Here, the user can create credentials to be used for the S3-Compatible API endpoints.
If the user is an RBAC Admin, they get access to the admin panel for managing roles.
The admin panel includes a table view for viewing currently existing users, roles, columns and permissions.

#include "4-system-design/peggy.typ"

To interact with the administrative API, a "query editor" was built to manage RBAC operations in an SQL-like syntax, reminiscent of the syntax used to manage permissions in e.g. PostgreSQL.#footnote[#link("https://www.postgresql.org/docs/current/sql-grant.html")]
Using the JavaScript library `peggyjs` @peggyjs, a simple grammar was written to parse statements into API calls.
Some example statements to configure RBAC permissions and the API calls they parse can be seen in~@listing:peggy.
The API endpoints will be described in more detail in @sec:api.

== Walkthrough Examples

=== Encryption Flow
#label("sec:encryption-flow")

#import "4-system-design/crypto-flow.typ": encryptionFlow
#encryptionFlow

@fig:encryptionflow shows the flow of how encryption works in OSWS, from the client's PUT call to the client receiving an acknowledgement that it has been completed.
It follows the given flow:

+ Client uploads an unencrypted Parquet file to OSWS -- through the encryption gateway
+ OSWS checks the client credentials and resolves their first role -- which is a simplification and should use a default role
+ Encryption Gateway then hands over the work to the Parquet solver
+ Parquet Solver uses KV to generate a KEK and gets a reference ID
+ Parquet Solver generates a DEK per column
+ All the DEKs are sent to KV to get wrapped
+ The Parquet file columns are encrypted and copied over to the new Parquet file, and the KEK ID and wrapped DEKs are saved within the Parquet metadata
+ Parquet solver hands the work back to the Encryption Gateway with relevant metadata
+ Encryption Gateway then persists the metadata in the PostgreSQL database
+ OSWS then inserts the Parquet file into the Object Store
+ OSWS sends back the acknowledgement that it has been inserted

=== Decryption Flow
<sec:sys-design:decryption>

#import "4-system-design/crypto-flow.typ": decryptionFlow
#decryptionFlow

@fig:decryptionflow shows the flow of how decryption works in OSWS, from the client's GET call to them receiving a Parquet file back.
It follows the given flow:

+ Client requests a Parquet file to OSWS, through the encryption gateway
+ OSWS checks the client credentials and resolves which roles they have access to
+ OSWS then fetches the full Parquet file from S3 -- or from the disk cache if available
+ OSWS then starts to work on decrypting the file, given the allowed columns
  + For each authorized column, it goes to KV to get the related DEK unwrapped - if not already present in the in-memory DEK cache
  + The columns are now decrypted and copied into a new Parquet file, and for the ones where the unwrapped DEK is not there, a dummy column will be inserted in its place
+ The Parquet file is now created, and the whole file can now be returned to the client, or sliced in memory if they only requested a range

This also highlights that OSWS does not use range requests itself when querying S3, but provides the clients the option to use range requests, meaning that regardless of which range the client queries, OSWS fetches the whole Parquet file and then slices it for them.
  
== API
<sec:api>

OSWS exposes three different endpoint groups.
These are either related to:

- Being S3 compliant and providing the endpoints to interact with the data lake
- Managing credentials for authentication
- Managing RBAC and access control


#include "4-system-design/s3-compatible-endpoints.typ"

=== S3-Compatible Endpoints
  
For the S3 endpoints, only a subset of endpoints has been implemented to ensure Object Store operations would work and be S3 compatible.
The endpoints can be seen in~@tab:s3-compatible-endpoints.
This enables listing what is in the Object Store, and also the create, update, and delete operations.

Currently, non-Parquet files pass through the encryption step, and the endpoints defined are only to allow operations made by most query engines, and thus suffice for making a PoC.

=== Application Endpoints

Usually, when using S3, the AWS IAM solution is used.
But due to the previously mentioned rerouting limitation and OSWS signage, in~@sec:sys-design:authentication, it has to provide endpoints for the clients to use to authenticate against.
The endpoints provided can be seen in~@tab:applications-endpoints, and include listing the existing credentials, creating new ones, and deleting them.

#include "4-system-design/application-endpoints.typ"
#include "4-system-design/administrative-endpoints.typ"
=== Administrative Endpoints

Endpoints for admin functionality can be seen in @tab:admin-endpoints.
These are restricted to only users who have the `IsRbacAdmin` flag, seen in the `User` table in @fig:er-diagram.
This field is populated from the `ClaimsPrincipal` when provisioning the user in the `/api/me` route.
Thus, it requires the OIDC Provider to include this claim for users who should have admin access. Alternatively, it can be set manually.

== Limitations
<sec:sys-design:limitations>

OSWS set out to provide columnar access control to external query engines and "fully managed all-in-one cloud platforms" by encrypting columns individually using PME, provided through the Parquet Sharp library.
But due to early design decisions, this was not possible.
As OSWS uses Parquet Sharp and stores cryptographic keys within the metadata of the Parquet files, a few issues appear with some query engines.
First, Parquet Sharp uses Apache Arrow, which itself supports writing metadata.~@ParquetSharp_2026-repo
This in itself makes sense, as it is possible by looking at e.g. `created_by` to see who created the Parquet file.~@apache-arrow
But as Parquet Sharp needs to write when encrypting the Parquet file, the file is essentially changed with new metadata, and it will no longer be the same Parquet file that the external query engine inserted.
This becomes a problem for query engines that store metadata themselves when writing.
Since OSWS rewrites the file, the query engine will have outdated information, which can break range requests.

On top of that, OSWS saves cryptographic-related metadata within the column metadata, and that is yet another modification.
As such, for this to work with all query engines, it would have to be ensured that all ranges of data remain the same, also after encryption.

The same issue is likely prevalent on most “fully managed all-in-one cloud platforms”, but it is not possible to test, due to it needing to have a URL whitelisted by the providers to test the OSWS system.
But given documentation of e.g. Snowflake, it seems to point towards incompatibility.~@snowflake_external_tables@snowflake_external_tables_files

In~@sec:discussion, this will be discussed in more depth, along with possible solutions to bridge these two design incompatibilities.

Lastly, initially, it was intended to make OSWS return unauthorized columns in their encrypted form, so that they would not be readable.
But due to the limitations in Parquet Sharp, it was not possible, and the current solution is instead to create dummy data entries for the unauthorized columns.
