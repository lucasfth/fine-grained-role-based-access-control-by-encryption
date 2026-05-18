#import "cmds.typ": todo, martinFeedback

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

The system is built on ASP.NET Core 10, and uses: PME, minimal API, PostgreSQL for RBAC, and was manually run and configured with Azure Key Vault for key management, Cloudflare R2 as Object Store (R2 is S3 compatible).#footnote[Codebase available at #link("https://github.com/lucasfth/osws")[github.com/lucasfth/osws]]
Minimal API being that there are no controllers, and that minimal dependencies exist to set it up, Anderson~and~Dykstra@minimal-api.

== Layered Architecture

#include "4-system-design/osws-architecture-overview.typ"
#todo[Address comment: (6)   The headline says “Layered Architecture”, but you describe the “repo” in the text and in Figure 1. It would be better if you described the architecture. So instead of describing which source files exist in which directories, describe the main components of your system, what they do, and how they interact with each other. As Figure 1 include an architectural diagram, which normally consists of system components, system boundaries, and input and output. Try to find literature that describes the architecture of a system or database and modify your description to follow more common standards.]
The repo is structured into six main .NET projects and one frontend project, written in React.
You can see the structure visually in @fig:osws-architecture-overview together with the client entry-point to OSWS.

=== `OSWS.WebAPI`

WebAPI is the entry-point that, from the query engine's perspective, is S3.
It is responsible for hosting the ASP.NET Core minimal API and registers all the services.

- Files within `Authentication` are responsible for the authentication schemes which are provided in incoming requests, including AWS Signature V4 (SigV4) for S3 API calls, and JWT Bearer validation for OIDC-authenticated calls.
- Files within `Endpoints` are all the endpoints OSWS supports, both for S3-compatible API endpoints and the endpoints needed to use the frontend to ensure RBAC can be handled.
- Files within `Extensions` ensures to load up all configurations for the setup of OSWS.
  This includes OIDC, rate limiting, endpoints, and object store to use for this specific setup of OSWS.
- `Interfaces` folder contains the S3-endpoints interfaces, so implementations can easily be changed out.
- `Models` contain `OidcUserInfo`, which defines the record of the type `OidcUserInfo`.
- `Services` defines the services used to handle and resolve users, Parquet uploads, which columns a user is authorized to see, transitive roles memberships, S3 object retrieval, and user info retrieval.
- `Program` is the entry point to run OSWS itself and add all relevant services.

=== `OSWS.ParquetSolver`

ParquetSolver handles the cryptographic operations for the Parquet files.

- `Interfaces` contain the interfaces `IDekCache`, `IParquetReader`, and `IParquetWriter`.
- `KeyRetriever`: Implements `ParquetSharp.DecryptionKeyRetriever`, and handles retrieving the correct keys given the metadata within the Parquet files.
- `ParquetWriter`: Implements `Interfaces/IParquetWriter` and takes a plain-text Parquet file and encrypts the columns if needed.
  This is done by generating an AES key of a size defined either within `OSWS.Common/Configuration/EncryptionSettings` or in `appsettings.json`.
  The DEK is then wrapped in a KEK (see @sec:osws-keymanager).´
  The wrapped DEKs are serialized, and the Parquet file is written with `ParquetSharp` using the serialized DEKs in the footer, and it is then sent to S3.
- `ParquetReader`: Implements `Interfaces/IParquetReader`.
  It takes the encrypted Parquet file and copies it to a decrypted version, decrypting using the metadata stored in the file. Forbidden columns are masked with dummy data.

Parquet Sharp was chosen as it supported PME, but it does not support partial decryption/reads of Parquet files, as it has to copy over all the columns to read.
This results in the fact that, from OSWS to S3, ranged requests are not supported, but from a client's perspective, it is supported (a solution to this has been proposed in~@sec:encryption-decryption).

=== `OSWS.KeyManager`
<sec:osws-keymanager>

KeyManager provides an abstraction over cryptographic key storage and the relational model.

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

== Database Design

#include "4-system-design/er-diagram.typ"

An Entity Relationship describing the database design can be seen in @er-diagram.
The database is mostly used for RBAC metadata; however, it also stores credentials used for AWS Signature V4 request signing, see @sec:sigv4, and external identity information from the OpenID Provider(s).

== Authentication

#martinFeedback[Due to S3 requiring signage, the calls from the clients going to OSWS are signed as well, and as a result, OSWS cannot reuse the signature and encrypt the Parquet columns.]
// Due to the requests from the clients being signed, it is not possible to reuse the signature while encrypting the Parquet columns.
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

#martinFeedback[The React frontend, for handling RBAC, uses OIDC for authentication flow.
The OIDC provider chosen for OSWS is #link("https://pocket-id.org/")[Pocket ID], as it is simple to set up, is #link("https://github.com/pocket-id/pocket-id")[open-source], and uses passkeys, which are more secure than standard MFA, as "common multifactor authentication methods can be intercepted or relayed"@bitwarden_passkeys.]

// The React frontend, for handling RBAC, authenticates via. OIDC, #link("https://pocket-id.org/")[Pocket ID] has been chosen for OSWS.
// Pocket ID was chosen as it is simple to set up, being #link("https://github.com/pocket-id/pocket-id")[open-source], and uses passkeys, which are more secure than standard MFA, as "common multifactor authentication methods can be intercepted or relayed"@bitwarden_passkeys.

The backend still supports other OIDC providers.
To use other providers, `OSWS.WebApi/appsettings.json` needs to be updated to reflect the change, and the frontend `.env` has to point to the specified authority and client ID.

On the first login, the `api/me` endpoint triggers JIT provisioning, and a new `User` record and `ExternalIdentity` record are created in the database.
Subsequent logins will synchronize the OIDC provider's claims.

== Envelope Encryption

To encrypt the Parquet columns, OSWS needs to use DEKs and KEKs to achieve envelope encryption@azure_envelope_encryption.
This deviates from the original proposed solution in~@own-paper, as KV does not support key retrieval, and the overhead of sending a Parquet column to KV each time for decryption and encryption is high.
By using envelope encryption, OSWS can cache the unwrapped DEKs with a specified TTL to allow quicker decryption.
#martinFeedback[This results in a solution with little overhead, more about this in~@sec:e2e-bench, and ensuring column-level access control.]
// This solution results in a solution with little overhead, more about this in~@sec:e2e-bench, and ensuring column-level access control.

=== Key Hierarchy

The KEK sizes are specified within the KV that the admin chooses.
Due to having student credits available in Azure, which was only available for a low-cost KV, RSA-2048 was used.
The KEKs are created in OSWS (inside `OSWS.KeyManager/Providers/AzureKeyVaultProvider`), but after that, the KEK never leaves KV again, and are then called by OSWS to wrap and unwrap the DEKs.

For the DEKs OSWS, create these themselves.
These symmetric AES keys have sizes 128, 192, or 256, and are created during the encryption of Parquet files.

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

== RBAC

In @sec:background-rbac, RBAC is defined to consist of: _users_, _roles_, _permissions_, _operations_, _objects_ and _sessions_. Our implementation of RBAC follows this mostly, but differs in a few ways. In @er-diagram, the core RBAC entities are shown: the tables `User`, `Role`, `RoleAssignment`, `RoleInheritance`, `Column`, and `Permission`.
`User` and `Role` have a many-to-many relationship through `RoleAssignment`.
Likewise, `Role` and `Column` have a many-to-many relationship through `Permission`.
The `Column` table can be seen as the _object_ of Core RBAC, as it is currently the only secured object to which access is controlled. There is however no concept of _operations_, only whether or not access is granted. 
There is also no formal concept of _sessions_ as described by #cite(<ferraiolo1992rbac>, form: "prose"), however, when a user is authenticated through their S3 Credential, their assigned roles are loaded. In this way, it can be seen as an activation of all the users assigned roles.

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
As the files are stored in their encrypted format, no new trust boundary is introduced.

=== DEK Cache

Unwrapped DEKs are cached in-memory to avoid repeated calls to KV, as it is one of the major latency attributes, see @sec:benchmarking.
The cached DEK is keyed with the KEK identifier, and in the configuration, the TTL can be defined for regular and admin users, as admin users' keys are most often more privileged.
The cache enforces a maximum capacity and evicts the expired entries first and then the oldest entries by expiration date.

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

=== Administrative Endpoints

Endpoints for admin endpoints are restricted to only users who have the `IsRbacAdmin` flag, seen in the `User` table in @er-diagram. This field is populated from the `ClaimsPrincipal` when provisioning the user in the `/api/me` route. Thus, it requires the OIDC Provider to include this claim on users who should have admin access. Alternatively, it can be set manually.

#include "4-system-design/administrative-endpoints.typ"

== Frontend Architecture

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
