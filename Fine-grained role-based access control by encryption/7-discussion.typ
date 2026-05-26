#import "cmds.typ": todo, delete, new
#include "7-discussion/ducklake.typ"

= Discussion
<sec:discussion>

OSWS set out to provide columnar access control to 3rd party query engines and "fully managed all-in-one cloud platforms" by encrypting columns individually using PME, provided through the Parquet Sharp library.
During the encryption flow, Parquet Sharp rewrites the entire Parquet file: it decompresses columns, copies them row-group by row-group into a new file, and adds cryptographic metadata such as wrapped DEKs and KEK references, as well as modifying existing metadata, e.g. the `created_by` field.
The resulting file is larger than the original and no longer byte-compatible with it.
This single root cause is responsible for the majority of the incompatibilities identified during the final iteration of benchmarking and end-to-end testing, and this section addresses those issues, defines what should have been done instead, and outlines the performance improvements available to a future OSWS system.

== Limitations of the Current Design
<sec:limitations>

#new[
The core issue of the current solution stems from the fact that the Parquet files put into OSWS are copied from the original Parquet file into a new one, instead of modifying the original.
When the Parquet file is copied, using Parquet Sharp, the metadata in the new Parquet file is different from the original one; incl. fields such as `created_by`.
So when schema-on-write external query engines put a file into OSWS they are not able to query it again, as the file is not the same as they inserted.

The other issue with Parquet Sharp and the way OSWS stores the cryptographic metadata is that to decrypt the Parquet file, the full one first has to be fetched, even if the client only requests a specific range.
When it has been fetched, the DEKs can be unwrapped, and now each column can be decrypted and copied over sequentially, and if no access, a dummy column has to be inserted in its place.
Essentially OSWS has to wait for each step to continue.

This results in OSWS not being able to return the original file, and the encrypted bytes for when a client is not authorized has to be replaced, but also that a lot of operations are not possible to overlap in its fetch, decrypt, and response pipeline.
]
// The core issue introduced by Parquet Sharp is that the written Parquet file no longer matches the file seen by clients.
// The core issue introduced by the encryption and decryption flow is re-writing of the originally written Parquet file. This means that the file the clients write is not the same file they get returned byte-for-byte when later fetching it, even with full access.
// #todo[Er det reelt ParquetSharp der er problemet her, eller vores valg? ved godt ParqeutSharp ikke supporter det vi gerne vil - men spørgsmåle er om det ikke stadig er vores valg]
// Three concrete effects follow from this:

// - _Modified metadata:_ Cryptographic metadata -- wrapped DEKs, KEK references, and modified fields such as `created_by` -- is appended to the file footer and column metadata, increasing the total file size.
// #delete[
// - _Decompressed columns:_ Parquet Sharp requires columns to be decompressed before they can be copied.
//   #todo[Not entirely correct, we just use default settings, which is uncompressed. It could have been compressed.]
//   The re-serialized file is therefore stored without compression, further inflating the file size relative to the original.
// ]
// - _Sequential, full-file processing:_ Parquet Sharp reads the entire file regardless of the byte range a client requests.
//   Keys are unwrapped one by one after the full file has been fetched, and columns are then copied sequentially. Each step waits for the previous to complete.

// Together, these mean that OSWS cannot return the original encrypted bytes for non-authorized columns, cannot serve range requests correctly once file size has changed, and cannot overlap any part of its fetch, decrypt, and response pipeline.


== Impact on Query Engines
<sec:impact>

The effect of the modified file size differs depending on whether a query engine is _schema-on-read_ or _schema-on-write_.

_Schema-on-read_ engines such as DuckDB and Spark are unaffected by the size change.
When they fetch a file, they first issue a HEAD request to obtain the current file size, and then perform a range request for the footer using that size.
Since the HEAD request returns the new encrypted file size, the subsequent range request is correct.

_Schema-on-write_ tools that maintain a catalogue database, such as DuckLake@ducklake_cached, exhibit broken behaviour.
When DuckLake writes a Parquet file, it records both the file size and the footer byte range in its catalogue, allowing it to skip the HEAD request on subsequent reads and fetch the footer directly.
For OSWS, however, the written file changes after the client PUT completes, so the recorded ranges are no longer valid.
See~@fig:ducklake-case for an illustration of this issue. The following describes it in more detail.

To begin, DuckLake uses its internal Parquet writer "ducklake-writer" to create and PUT a Parquet file of $1000$ bytes. Then, OSWS uses its writer, ParquetSharp, to create an encrypted copy. This is now a whole new Parquet file with encrypted columns, new metadata and possibly different encoding due to the different writers - illustrated by a file size of $2000$ bytes. This file is then stored in the storage backend. 

When DuckLake later queries the file, it issues a range request of bytes 500--1000, being the range it thinks contains the footer.

Since OSWS must fetch the entire file to be able to decrypt, the $2000$ byte file is first fetched, and then decrypted. However, on decryption, the file is again copied into a whole new Parquet file. Now, the values are the same as the original, DuckLake-written $1000$ byte file, but again, since the writers are not the same, the metadata and encoding might be different. This is illustrated with a file size of $1250$ bytes. 

To serve the range request, OSWS then slices _this_ file in the range 500-1000, but given the different file size, this results in a wrong range.
This is then sent to DuckLake, which throws an error due to not finding the expected data.

This eliminates DuckLake and probably Snowflake from being compatible with OSWS in its current form.
The root cause is not the specific metadata that is added, but the fundamental incompatibility between recording file ranges at write time and then rewriting the file.

== Proposed Redesign
<sec:redesign>

The issues described above share a common fix: OSWS should neither store cryptographic metadata inside the Parquet file, nor rewrite the file at all.
This requires two coordinated changes: an internal metadata store, and a custom Parquet reader and writer using AES CTR.

=== Internal Metadata Store
<sec:redesign:metadata>

Cryptographic metadata should be stored in an internal SQL database within OSWS rather than in the Parquet file column metadata.
For each Parquet file, the database should contain:

+ Internal file identifier for the footer#footnote[Defined within @parquet-encryption]<footnote:parquet-encryption>
+ Byte range of the start and end index
+ Internal file identifier for the column index@footnote:parquet-encryption
+ Wrapped DEK
+ KEK reference
+ Row chunk size

When a read request arrives, OSWS can retrieve the file from the object store while concurrently querying the local database for matching entries under _1_.
It can then cross-reference the client's RBAC permissions and match authorized columns against _3_, fetching wrapped DEKs from KV using _5_.
For range requests, OSWS can use _2_ to determine which columns the requested byte range covers, fetching only those from S3 and requesting only the relevant DEKs — rather than fetching the entire file.

=== Custom Reader and Writer with AES CTR
<sec:redesign:encryption>

The current dependency on Parquet Sharp should be replaced with a custom Parquet reader and writer that encrypts and decrypts in place using AES CTR.
AES CTR uses no padding, which means the encrypted form of a column chunk is the same size as the plaintext, preserving all byte offsets and leaving the file size unchanged.
Since column metadata is no longer embedded in the file, compression can also be left intact, as there is no longer a need to decompress columns before encryption.

This enables three concrete improvements over the current design:

+ _Asynchronous key pre-fetching:_ While the encrypted Parquet file is being streamed from the object store, OSWS can concurrently request DEK unwrapping from KV.
  By the time the file has arrived, the unwrapped keys are ready, removing KV latency from the critical path.
+ _In-place decryption:_ Rather than copying the entire file, only the requested column chunks are decrypted, using AES CTR's preserved byte offsets to locate them directly.
+ _True streaming:_ As soon as a row chunk arrives and its key is ready, decryption can begin immediately, without waiting for the entire file to be fetched first.

AES CTR does carry known considerations, discussed by Helger~et~al.@Helger2000:

- No integrity: CTR provides no message integrity, but this can be handled by a MAC layer.
- Error propagation: Bit flips are localized and do not propagate. This should be addressed at a separate layer.
- Stateful encryption: Keys must not be reused, which is already enforced by OSWS generating a new DEK per column.
- Counter reuse: Counter values must not be reused; given per-column key generation, this is satisfied.

Additionally, knowing the column chunk size and row chunk size from the internal store allows OSWS to identify the precise offset within a range query, fetch only the relevant bytes from S3, and decrypt only that portion, which substantially reduces the overhead compared to the current full-file fetch.

=== Parallelization
<sec:redesign:parallelization>

With in-place encryption and decryption, row group processing becomes an embarrassingly parallelisable operation.
OSWS can spawn threads to process independent row groups concurrently rather than sequentially, which should reduce processing overhead substantially.
This was not feasible with Parquet Sharp, which provides no API for writing bytes at a specific offset.

== Encrypted Parquet Storage Cache
<sec:file-cache>

When Parquet files are fetched from S3, they are stored in local storage in their encrypted format.
As seen in~@sec:e2e-bench, this yields negligible improvement for smaller files, with more significant gains on larger ones.
With proper range request support, this improvement is likely to diminish further, since most requests will cover only a portion of a file rather than fetching it in full.
Caching in unencrypted form in DRAM would offer additional performance gains, but it introduces complexity around column-level access control and memory pressure.
This is therefore considered a later-stage optimization to be evaluated on a future OSWS system.

== Correct Decisions & OSWS Future
<sec:correct-decisions>

Despite the design issues outlined above, several decisions made in the current OSWS implementation are considered sound and should be carried over to a V2 system.

=== Envelope Encryption
<sec:correct-decisions:envelope>

Envelope encryption should be retained.
While it carries a significant initial overhead, this is substantially mitigated by the decrypted DEK cache.
It also enables straightforward key rotation, which is an important property for future security improvements.
A fully fledged key vault inside OSWS would be an alternative that eliminates the KV dependency, but would require significant additional security measures.

=== DEK Cache
<sec:correct-decisions:dek>

The decrypted DEK cache must be carried over to any future version that uses a KV store.
As seen in both~@sec:e2e-bench and~@sec:microbench, DEK unwrapping carries a significant overhead, and the cache is the primary mechanism for keeping it off the critical path on repeated accesses.

=== RBAC Metadata Storage

The microbenchmarks in~@sec:microbench showed that authorizing users via the RBAC database contributes negligible overhead relative to cryptographic operations and network transfer.
A PostgreSQL database with the implemented schema is therefore a sound choice for RBAC metadata storage going forward.

=== Role Management

Role management — creating and assigning roles, granting permissions — using the implemented query editor provided an intuitive and familiar interface over the admin API.
While this is a wrapper that could be implemented in many ways, it is a valid option for future versions.

=== Known Security Considerations

Two implementation-level security issues are acknowledged in the current OSWS release, documented in #link("https://github.com/lucasfth/osws/blob/V2026.0.0-alpha/KNOWN_ISSUES.md")[`KNOWN_ISSUES.md`].

First, S3 credential secret keys are stored in plaintext in the PostgreSQL database, as the SigV4 authentication handler requires the raw key for HMAC derivation.
If the database is compromised, all S3 credentials become immediately usable.
A mitigation would be to encrypt secret keys at rest using Azure Key Vault, decrypting on read during SigV4 verification.

Second, the RBAC admin flag is provisioned just-in-time from OIDC claims on every login.
If the OIDC provider exposes this as a self-service field, users could grant themselves admin access.
This is dependent on the OIDC provider configuration and can be mitigated by using a dedicated admin identity provider or restricting claim sources.
