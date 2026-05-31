#import "cmds.typ": todo, delete, new, speculation
#include "7-discussion/ducklake.typ"

= Discussion
<sec:discussion>

This section will provide a discussion about some of the major issues behind the design choices made, and how they could be improved in a future redesign.
In particular, the choice of using PME along with Parquet Sharp introduced many issues, which will be addressed.

== Limitations of the Current Design
<sec:limitations>

The core issue of the current solution stems from the fact that the Parquet files put into OSWS are copied from the original Parquet file into a new one, instead of modifying the original.

When the Parquet file is copied, using Parquet Sharp, the resulting file will be inherently different from the original one, even without taking the encrypted data into account.
Different implementations of Parquet writers cannot be guaranteed to produce the same file structure; metadata fields like `created_by` might be different or there might be different choices of encoding.
This means when the writer ultimately fetches the file again, they cannot be sure it is the same file as they inserted, which introduces a problem for range requests.

The other issue with Parquet Sharp and the way OSWS stores the cryptographic metadata is that to decrypt the Parquet file, the full one first has to be fetched, even if the client only requests a specific range.
When it has been fetched, the DEKs can be unwrapped, and now each column can be decrypted and copied over sequentially, and if there is no access, a dummy column has to be inserted in its place.
Essentially, OSWS has to wait for each step to continue.

This results in OSWS not being able to return the original file, and the encrypted bytes for when a client is not authorized have to be replaced, but also that a lot of operations are not possible to overlap in its fetch, decrypt, and response pipeline.

== Impact on Query Engines
<sec:impact>

The effect of the modified file size differs depending on whether a query engine is _schema-on-read_ or _schema-on-write_.

_Schema-on-read_ engines such as DuckDB and Spark are unaffected by the size change.
When they fetch a file, they first issue a HEAD request to obtain the current file size, and then perform a range request for the footer using that size.
Since this must report the size of the file that would be issued on a regular GET, a HEAD also triggers a full fetch and decrypt, including masking unauthorized columns.
The size of this newly decrypted file is then reported to the query engine, ensuring that subsequent range requests are correct.

_Schema-on-write_ tools that maintain a catalogue database, such as DuckLake~@ducklake_cached, exhibit broken behaviour.

When DuckLake writes a Parquet file, it records both the file and footer size in its catalogue, allowing it to skip the HEAD request on subsequent reads and fetch the footer directly.

For OSWS, however, the written file changes after the client PUT completes, so the recorded ranges are no longer valid.
See~@fig:ducklake-case for an illustration of this issue.
The following describes it in more detail.

To begin, DuckLake uses its internal Parquet writer _ducklake-writer_ to create and PUT a Parquet file of $1000$ bytes.
Then, OSWS uses its writer, Parquet Sharp, to create an encrypted copy.
This is now a whole new Parquet file with encrypted columns, new metadata and possibly different encoding due to the different writers - illustrated by a file size of $2000$ bytes.
This file is then stored in the storage backend. 

When DuckLake later queries the file, it issues a range request of bytes $500$-$1000$, this being the range it thinks contains the footer.

Since OSWS must fetch the entire file to be able to decrypt, the $2000$ byte file is first fetched, and then decrypted.
However, on decryption, the file is again copied into a whole new Parquet file.
Now, the values are the same as the original, DuckLake-written $1000$ byte file, but again, since the writers are not the same, the metadata and encoding might be different.
This is illustrated with a file size of $1250$ bytes. 

To serve the range request, OSWS then slices _this_ file in the range $500$-$1000$, but given the different file size, this results in a wrong range.
This is then sent to DuckLake, which throws an error due to not finding the expected data.

This eliminates DuckLake and probably Snowflake from being compatible with OSWS in its current form.
The root cause is not the specific metadata that is added, but the fundamental incompatibility between recording file ranges at write time and then rewriting the file.

== Proposed Redesign
<sec:redesign>

The issues described above share a common fix: OSWS should neither store cryptographic metadata inside the Parquet file, nor modify the size of the file at all.
This requires two coordinated changes: an internal metadata store and a custom Parquet modifier using a length-preserving encryption scheme like AES-CTR.

=== Internal Metadata Store
<sec:redesign:metadata>

Cryptographic metadata should be stored in an internal SQL database within OSWS rather than in the Parquet file column metadata.
For each Parquet file, the database should contain:

+ Internal file identifier for the footer#footnote[Defined within~@parquet-encryption]<footnote:parquet-encryption>
+ Byte range of the start and end index
+ Internal file identifier for the column index@footnote:parquet-encryption
+ Wrapped DEK
+ KEK reference
+ Row chunk size

When a read request arrives, OSWS can retrieve the file from the Object Store while concurrently querying the internal database for matching entries under the given identifier.
It can then cross-reference the client's RBAC permissions, match authorized columns against the internal identifier and column index, and unwrap the DEKs with KV using the KEK reference.
For range requests, OSWS no longer needs to fetch the full file, but can instead fetch the same range requested.
Then, the internal metadata store can be used to determine what columns this range covers, thus knowing what DEKs will be needed to decrypt.

=== Custom Modifier with AES-CTR
<sec:redesign:encryption>

The current dependency on Parquet Sharp should be replaced with a custom Parquet modifier that encrypts and decrypts in place using AES-CTR.
With this in place, there is also no need to rely on PME.
AES-CTR uses no padding and, in contrast to AES-GCM, adds no authentication tag.
This means the encrypted form of a column chunk is the same size as the plaintext, preserving all byte offsets and leaving the file size unchanged.
Since there is no need to rewrite the file, compression can also be left intact.

This enables three concrete improvements over the current design:

+ _Asynchronous key pre-fetching:_ While the encrypted Parquet file is being streamed from the Object Store, OSWS can concurrently request DEK unwrapping from KV.
  By the time the file has arrived, the unwrapped keys are ready, removing KV latency from the critical path.
+ _In-place decryption:_ Rather than copying the entire file, only the requested column chunks are decrypted, using AES-CTR's preserved byte offsets to locate them directly.

Ultimately, Parquet Modular Encryption is not the right fit for OSWS, as it was built for an entirely different use case and trust model.
PME was built for a scenario where the client handles all encryption and decryption themselves, as they do not trust the storage server.
In this scenario, it makes sense to store cryptographic metadata in the Parquet file itself; when it is later read, the client knows how to decrypt it immediately.

For OSWS, the scenario is different.
Here, the client trusts OSWS to handle cryptography and access control.
Since OSWS is the sole handler of cryptography, it does not need to adhere to the specification set by PME, and can thus store metadata elsewhere and encrypt using its own strategy -- as long as it correctly handles access control and the original writer can get the same file back when later fetched.
Thus, PME should be discarded in favour of a fully custom modifier.

Additionally, knowing the column chunk-size and row-chunk size from the internal store allows OSWS to identify the precise offset within a range query, fetch only the relevant bytes from S3, and decrypt only that portion, which substantially reduces overhead compared to the current full-file fetch.

=== Parallelization
<sec:redesign:parallelization>

With in-place encryption and decryption, row-group processing becomes an embarrassingly parallelizable operation.
OSWS can spawn threads to process independent row groups concurrently rather than sequentially, which should reduce latency substantially.
This was not feasible with Parquet Sharp, which provides no API for writing bytes at a specific offset.

== Encrypted Parquet Storage Cache
<sec:file-cache>

When Parquet files are fetched from S3, they are stored in local storage in their encrypted format.
As seen in~@sec:e2e-bench, this yields negligible improvement for smaller files, with more significant gains on larger ones.
With proper range request support, this improvement is likely to diminish further, since most requests will cover only a portion of a file rather than fetching it in full.
Caching in decrypted form in-memory would offer additional performance gains, but it introduces complexity around column-level access control and memory pressure.
This is therefore considered a later-stage optimization to be evaluated on a future OSWS system.

== Correct Decisions & OSWS Future
<sec:correct-decisions>

Despite the design issues outlined above, several decisions made in the current OSWS implementation are considered sound and should be carried over to a V2 system.

=== Envelope Encryption
<sec:correct-decisions:envelope>

Envelope encryption should be retained.
While it carries a significant initial overhead, this is substantially mitigated by the decrypted DEK cache.
A fully fledged key vault inside OSWS would be an alternative that eliminates the KV dependency, but would require significant additional security measures.

#v(20pt)
=== DEK Cache
<sec:correct-decisions:dek>

The decrypted DEK cache must be carried over to any future version that uses a KV store.
As seen in both~@sec:e2e-bench~and~@sec:microbench, DEK unwrapping carries a significant overhead, and the cache is the primary mechanism for keeping it off the critical path on repeated accesses.

=== RBAC Metadata Storage

The micro-benchmarks in~@sec:microbench showed that authorizing users via the RBAC database contributes negligible overhead relative to cryptographic operations and network transfer.
A PostgreSQL database with the implemented schema is therefore a sound choice for RBAC metadata storage going forward.

=== Role Management

Role management -- creating and assigning roles, granting permissions -- using the implemented query editor provided an intuitive and familiar interface over the admin API.
While this is a wrapper that could be implemented in many ways, it is a valid option for future versions.

=== Known Security Considerations

Two implementation-level security issues are acknowledged in the current OSWS release, documented in `KNOWN_ISSUES.md`.
#footnote[https://github.com/lucasfth/osws/blob/V2026.0.0-alpha/KNOWN_ISSUES.md]

First, S3 credential secret keys are stored in plaintext in the PostgreSQL database, as the SigV4 authentication handler requires the raw key for HMAC derivation.
If the database is compromised, all S3 credentials become immediately usable.

This could be mitigated by encrypting secret keys at rest using Azure Key Vault and decrypting on read during SigV4 authentication.

Second, the RBAC admin flag is provisioned just-in-time from OIDC claims on every login.
If the OIDC provider exposes this as a self-service field, users could grant themselves admin access.
This is dependent on the OIDC provider configuration and can be mitigated by using a dedicated admin identity provider or restricting claim sources.


