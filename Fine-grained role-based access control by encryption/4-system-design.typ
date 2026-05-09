#import "cmds.typ": todo

= System Design

OSWS set out to provide columnar access control to 3rd party query engines by encrypting the columns individually with PME, provided through the Parquet Sharp library, see @sec:encryption-flow.
In short, during the encryption flow, the Parquet size is changed due to how Parquet Sharp operates, as well as added metadata.
This eliminates query engines, which use the range modifier based on cached sizes and do not read from the modified metadata.
This then eliminates DuckLake from using OSWS, as it caches the inserted ranges~@ducklake_cached.
The same issue is prevalent for "fully managed all-in-one cloud platforms", due to the incompatible design choices made @snowflake_external_tables@snowflake_external_tables_files.
Though some changes can be made to bridge these two different design choices #todo[ref to discussion].
What the current OSWS solves is that query engines, which read metadata from the object storage and do not use cached values, will have enforced columnar access control in the data they read.
This ensures that from the query engine's perspective, they are using S3 directly, but in reality use OSWS, and they can now read and put data into OSWS, without needing to have modifications to the query engine itself.
So if you have a dataset with columns `name`, `birthday`, and `relational status`, and the query engine is not granted access to `birthday`, it will receive a, depending on the setup of OSWS, all three columns, but `birthday` has either null values or an encrypted column.

Below, the design choices will be described in more depth, together with technical information.

== Architecture Overview

OSWS will be set up to be a wrapper for S3 and thereby provide S3-compatible API endpoints for clients.
The purpose of OSWS is to provide column-level access controls to S3, whilst not modifying the S3 API.
This will ensure that most S3-compatible query engines are able to use OSWS without modifications and that they will only be able to read what they are supposed to.

The system is built on ASP.NET Core 10, and uses: PME, minimal API, PostgreSQL for RBAC, Azure Key Vault for key management, Cloudflare R2 as object store (R2 is S3 compatible).

#include "4-system-design/osws-architecture-overview.typ"

== Layered Architecture

The repo is structured into six main .NET projects and one frontend project (written in React).
You can see the structure visually in @fig:osws-architecture-overview. #todo[Remember to update before handin]

=== `OSWS.WebAPI`

WebAPI is the entry point that, from the query engine's perspective, is S3.
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
  It takes the encrypted Parquet file 

=== `OSWS.KeyManager`
<sec:osws-keymanager>

KeyManager provides an abstraction over cryptographic key storage and the relational model.

- `AzureKeyVaultProvider`: Implements `IKeyVaultProvider`.
  It creates keys (which are defined in `OSWS.Common/Configuration/EncryptionSettings`) in Azure Key Vault, performs the wrap and unwrap of the DEKs server side, using the algorithm defined in  within `OSWS.ParquetSolver/Helpers/Cryptography`.
- `InternalKeyVaultProvider`: Implements `IKeyVaultProvider`.
  It works the same as `AzureKeyVaultProvider` but runs on OSWS itself.
- `OswsContext`: Implements `DbContext`.
  Defines the relational schema over PostgreSQL, being users, roles, role assignments, role inheritance, permissions, columns, keys, external identities, and S3 credentials.

=== Shared Libraries

- `OSWS.Models` defines all the DTOs and entities used within the solution.
- `OSWS.Common` contain classes containing settings for the project, including. `EncryptionSettings`, `CacheSettings`, `S3Settings`, `KeyVaultSettings`, and `RateLimitSettings`.
  They are bound to `appsettings.json` at startup, and they also include validation logic for the configuration.
- `OSWS.Library` has utility helpers for AWS credential normalization, S3 metadata translation, HTTP range request parsing, parameter validation, and XML extensions.

== Authentication

Due to the requests from the clients being signed, it is not possible to reuse the signature while encrypting the Parquet columns.
Internal authentications were therefore needed, and OSWS then has its own signature for S3.

=== AWS Signature V4 (S3 API)

Because OSWS had to use an S3-compatible API, it also had to use the same validation as S3.
A custom `SigV4AuthenticationHandler` has been created to parse the authorization header, which extracts the `AccessKeyId`.
The keys corresponding to the `S3Credential` record are then looked up in the internal PostgreSQL.
The signature is verified using the stored secret key.
On success, a `ClaimsPrincipal` is created carrying the user's database ID, name, email, and default role.

This follows the AWS specification "Authenticating Requests (AWS Signature Version 4)"@aws_signiture_version_4.

=== OIDC
<sec:oidc>

The React frontend, for handling RBAC, authenticates via. OIDC, #link("https://pocket-id.org/")[Pocket ID] has been chosen for OSWS.
Pocket ID was chosen as it is simple to set up, #link("https://github.com/pocket-id/pocket-id")[open-source], and uses passkeys, which are more secure than normal 2FA, as "common multifactor authentication methods can be intercepted or relayed"@bitwarden_passkeys.

The backend still supports other OIDC providers.
To use other providers, `OSWS.WebApi/appsettings.json` has to be updated to reflect the change, and the frontend `.env` has to point to the specified authority and client ID.

On the first login, the `api/me` endpoint triggers JIT provisioning and a new user record and external identity are created in the database.
Subsequent logins will synchronize the OIDC provider's claims.

== Envelope Encryption

To encrypt the Parquet columns, OSWS needs to use DEKs and KEKs to achieve envelope encryption@azure_envelope_encryption.
This deviates from the original proposed solution in Trøstrup and Lucas@own-paper, as KV does not support key retrieval, and the overhead of sending a Parquet column to KV each time for decryption and encryption is high.
By using envelope encryption, OSWS can cache the unwrapped DEKs with a specified TTL to allow quicker decryption.
This solution results in a solution with little overhead, more about this in #todo[Section benchmarking], and ensuring column-level access control.

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
+ The user's current role is computed via role hierar #todo[GET BACK HERE]
+ The permitted columns are now decrypted, while the others are replaced by dummy columns#footnote[Due to limitations in Parquet Sharp, it is not possible to leave the encrypted column alone, and thus has to be replaced.]
+ The decrypted Parquet stream is returned to the client.

== RBAC

=== Role Hierarchy

#todo[Trølle]

=== Column-Level Permissions

Each _Permission_ record maps a _Role_ to a _Column_.
This means that a column is decrypted if and only if one of its roles grants access to the given column.
This ensures fine-grained access control.
If a Parquet file _P1_ with columns _name_, _age_, and _civil\_personal\_register_ exists.
Then a user _U1_ and a user _U2_ can respectively give access to role _R1_ and _R2_.
_R1_ provides access to only _name_ and _R2_ only to _age_ and _civil\_personal\_register_.
Then _U1_ would see a table full of valid _names_ whilst _age_ and _civil\_personal\_register_ are either null values or some dummy encrypted values (depends on the configuration of OSWS), while _U2_ would see _age_ and _civil\_personal\_register_ values.

== Caching

There are two tiers to the caching system used within OSWS, to minimize latency from remote services.

=== Encrypted File Cache

Given the configuration of OSWS, the Parquet files fetched from the object store can be cached.
It uses #todo[SEP (some eviction policy)] to cache the encrypted Parquet files on the local file system.
They are keyed with `SHA256(bucket::key)`, see `OSWS.ParquetSolver/Helpers/EncryptedFileCache.cs`.
As the files are stored in their encrypted format, no new trust boundary is introduced.

=== DEK Cache

Unwrapped DEKs are cached in-memory to avoid repeated calls to KV, as it is one of the major latency attributes, see #todo[Section benchmarking].
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

Endpoints for admin endpoints are restricted to only users who have the `IsRbacAdmin` flag.
The endpo

#include "4-system-design/administrative-endpoints.typ"

== Frontend Architecture

Some info
 