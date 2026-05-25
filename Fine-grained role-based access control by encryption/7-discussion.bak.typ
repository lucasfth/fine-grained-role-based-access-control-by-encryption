#import "cmds.typ": todo, delete
#include "7-discussion/ducklake.typ"

= Discussion
<sec:discussion>

OSWS set out to provide columnar access control to 3rd party query engines and "fully managed all-in-one cloud platforms" by encrypting columns individually using PME, provided through the Parquet Sharp library.
Quick summary: During the encryption flow, Parquet Sharp modifies the metadata within, e.g. for the `created_by` value and metadata is added for cryptographic operations, resulting in a changed Parquet file size.
This eliminates query engines, which use the range modifiers based on their own cached ranges, as their ranged queries hit incorrect parts of the data within the Parquet file and do not take the modified Parquet file metadata into account, and probably also the "fully managed all-in-one cloud platforms", but as mentioned in~@sec:sys-design:limitations, have the same issue though not testable due to missing whitelisted URL.
This then eliminates DuckLake@ducklake_cached from using OSWS, as it caches the inserted ranges, and also Snowflake.

Most of these incompatibility issues were from the initial implementation, and first became apparent on the final iteration of designing benchmarking and e2e tests, which, based on the research paper Trøstrup~and~Lucas@own-paper, made sense, but after modifying it to work with the various providers, did not make sense anymore and had unnecessary overhead or created other problems, and as such this section will address those issues, define what should have been done instead, and define which performance improvements can be done in a future OSWS system.

== Metadata
<sec:metadata>

#todo[The original idea for OSWS was to allow 3rd party query engines to decrypt Parquet files themselves locally, while decrypting within OSWS for "fully managed all-in-one cloud platforms".
This would be achieved by storing key IDs within the footer of the Parquet files, and the query engines could then, through an endpoint in OSWS, request the given key and then decrypt the column locally, and OSWS would do the logic itself.
As soon as it was identified that this was not possible with KV to retrieve the keys from it, OSWS was changed to use envelope encryption and store the wrapped DEKs, and the KEK reference in the footer, due to it being partly meant for that purpose.] // Skal det ikke være related work???
#todo[Se om vi skal opdatere med grunden her. Men ville jo argumentere at det allerede står i background. Men omvendt kan man sige det var vel også kun "umuligt" da vi regnede med ikke at bruge envelope enc].
This means that when clients write files using the API, the Parquet file changes from the original file due to the newly added metadata.
This does not affect _schema-on-read_ #todo[måske skal dette begreb introduceres] query engines like DuckDB and Spark; when they later fetch the file, they first perform a HEAD request to get the size of the file, to know in what byte range to look for the footer.
Thus, the reported file size is the _new_ file size with the added metadata. The query engines are then able to perform range requests without any issues.

However, for _schema-on-write_ tools like DuckLake that add a catalogue database, this poses an issue.
When DuckLake writes a Parquet file, it records the size of the written file and the size of the footer in its catalogue database.
This means it can later skip the HEAD request and fetch the footer directly.
For OSWS, however, since the written Parquet file changes, this behaviour is broken.
When DuckLake later attempts to fetch the footer of the tracked file, the byte ranges are no longer correct.

An illustration of this case can be seen in @fig:ducklake-case.
Here, it is shown what happens when DuckLake writes a file and later attempts to query it.
The file sizes are chosen for illustrative purposes and are not real sizes. To begin, DuckLake PUTs a $1000$-byte plaintext Parquet file, with a footer length of 500 bytes.
These sizes are recorded in its catalogue database.
When OSWS encrypts this file, it re-serializes the file to a new Parquet file with encrypted columns; each of these columns store their encrypted DEK in its metadata, adding file size -- ending in a file size of 2000 bytes.
This new, encrypted file is then stored in the storage backend. 

When DuckLake later fetches this file, it looks in its own database and sees a file size of 1000 bytes and a footer length of 500 bytes.
It issues a range request of bytes 500–1000, which it believes constitutes the footer of the file. This range request is propagated to the storage backend
#todo[Denne sektion skal omskrives til at være mere generisk; det nye metadata er ligegyldigt siden det ikke er med i filen der bliver sendt tilbage, problemet er fundamentalt at omskrive filen]

This breaks many query engines, where they themselves store size metadata, and range requests are not fully functional.
The solution to this would most likely be to have an internal SQL server running in OSWS.
This database should contain the following information per Parquet file inserted:

+ Internal File Identifier for footer#footnote[Defined within @parquet-encryption]<footnote:parquet-encryption>
+ Byte range of the start and end index
+ Internal File Identifier for Column Index@footnote:parquet-encryption
+ Wrapped DEK
+ KEK reference
+ Row chunk size

Together with a full range of requests, support for more concurrency can be used.
When OSWS get a request to read a file, it can start retrieving it.
In the meantime, it can also go to the local database and find files which match _1_.
It can then see which keys the client has access to in the RBAC database, and then match the columns with _3_, then for each send _4_ to KV given _5_.

Another improvement is when range requests are given, OSWS can figure out which ranges are related to which columns given _2_ and then retrieve them from S3.
Meanwhile, it can retrieve the unwrapped DEKs to be ready for decryption.
Now for decryption, it can use the row chunk size _6_ to be able to decrypt the small part, though only possible if AES CTR is used, more on this in~@sec:encryption-decryption.

So for metadata, it should only be saved within internal SQL, still, as the current solution relies on SQL, and then the encryption of the columns also needs to change.

== Encryption & Decryption
<sec:encryption-decryption>

Currently, encryption and decryption are handled by Parquet Sharp, being a .NET package which supports PME.
Choosing this library was a mistake as it imposes a sequential read of the Parquet file, increasing the latency of OSWS.
Because the library requires reading the entire file, copying it column-by-column into a new Parquet file, and does not do it asynchronously, OSWS cannot overlap cryptographic operations.
A custom Parquet reader and writer using AES CTR would enable the following optimizations, given that the metadata is also stored within the internal OSWS store and not in the Parquet file metadata:

+ _Asynchronous key pre-fetching:_ While the encrypted Parquet file is being streamed from the Object Store, OSWS can concurrently request DEK unwrapping from the KV.
  By the time the file has arrived, the unwrapped keys are ready, eliminating KV latency from the critical path.
+ _In-place decryption:_ Rather than copying the entire Parquet file, only the requested column chunks are decrypted in place, using AES CTR's lack of padding to preserve byte offsets.
+ _True streaming:_ As soon as a row chunk arrives and its key is ready, decryption can begin immediately, without waiting for the entire file to be fully fetched and copied.

Without these changes, Parquet Sharp is forced to read the whole Parquet file regardless of the byte range requested by the client, and it is the first step to not having OSWS be embarrassingly sequential; currently, the flow is fetch the entire file, then unwrap keys one-by-one, then copy the entire file column-by-column.
Each step waits for the previous to complete.

Also, as~@sec:metadata, the size of the Parquet file changes upon encryption, due to PME and Parquet Sharp, and thus creates issues for range requests, but could be solved by using AES CTR and by using a custom reader/writer.

These design changes in OSWS would allow more efficient decryption and encryption, and address the issue of not being able to return the original encrypted data for non-authorized columns to the clients.

All this could be solved by implementing a custom reader and writer for the Parquet files, which would use decrypt and encrypt in place, thus fixing _1_, being able to leave non-authorized columns encrypted, thus solving _2_, and not changing metadata and using the solution described in~@sec:metadata.
Important for the encryption is that AES CTR, which does not use any padding, and thus is also a contributor to not modifying any part of the size of the file.@Dworkin_2001
The issues and things to account for when using CTR have been discussed by~@Helger2000 and include the following:

- No integrity: CTR provides no message integrity, but can be handled by MAC.
- Error propagation: Bit flips are localized and not propagated. Though this issue should be solved in another layer.
- Stateful encryption: Important that the system does not reuse keys, but that is already how OSWS operates.
- Sensitivity to usage errors: Counter-values are not to be reused, but given that OSWS generates a new key for each column, this can be ignored.

To argue even more for why CTR is the correct choice: given a column size in the Parquet file, there are multiple row chunks, which individually are encrypted.
By knowing the column chunk size and the column size, the OSWS could identify the offset within the range query a client might have sent, only fetching the range from S3 and only decrypting that part, essentially removing a big part of the overhead OSWS currently experiences.

=== Parallelization

When encrypting/decrypting the Parquet file, OSWS currently copies each row group sequentially.
This should be an "embarrassingly parallelisable" operation, i.e. it could spawn threads to copy a cutout of the row groups to the new Parquet file so the row groups are copied in parallel.
This should reduce copying overhead drastically, though in light of~@sec:encryption-decryption, it should be a write in place instead of a copy.
//#delete[But it would require a hand-written or at least modified low-level Parquet library, as this is not something ParquetSharp can do currently -- there is no API for inserting bytes at a specific offset.
//Offset handling would be the big challenge; how would the library handle where to write row chunks?] // Ikke allerede nævnt i encryption og decryption ovenfor?

== Compression
<sec:compression>

For Parquet Sharp to copy over a column, it has to decompress the file.
Here, OSWS thus modifies the file size and just keeps the file decompressed afterwards, when put into S3.
It could have compressed it again, but it would not have fixed range queries due to modified metadata, etc.
Here, with the custom reader and writer, it is not even needed to decompress the file.
OSWS could potentially just keep the current format and still encrypt, etc., on a compressed or non-compressed file and thus leave all the sizes untouched.

== Encrypted Parquet Storage Cache
<sec:file-cache>

When Parquet files are fetched from S3, they are stored in local storage in their encrypted format.
But as seen in~@sec:e2e-bench, it has negligible performance improvements on the smaller files, while more significant improvements on larger Parquet files.
This improvement might even become smaller and less useful with proper range support, as oftentimes only ranges of data are required and not the full file, and will thus be one of the later improvements, which might be tested on a future OSWS system.
Of course, putting the caching in their unencrypted state and in DRAM cache could enhance performance as well, but would raise issues with handling access control on columns and size issues of the Parquet files, ending up filling up DRAM too quickly.

== Correct Decisions & OSWS Future
<sec:correct-decisions>

Even though OSWS has a lot of design choices, in light of prior subsections, a lot of correct decisions are believed to have been implemented, and are believed to need to be carried over to a V2 of a similar system.

=== Envelope Encryption
<sec:correct-decisions:envelope>

Envelope encryption should still be used, even though it carries an initial significant overhead, but it is partly solved by having the decrypted DEK cache.
This will also enable easier key rotation for future security improvements.
A potential alternative would be to implement a fully fledged key vault inside OSWS, eliminating envelope encryption, though this would require many security measures.

=== DEK Cache
<sec:correct-decisions:dek>

The decrypted DEK cache is another one of these design choices which has to be carried over to a new version, given that a KV is used, as seen by @sec:e2e-bench and @sec:microbench, that unwrapping DEKs carries a significant overhead.

=== RBAC Metadata Storage

The microbenchmarks in @sec:microbench also showed that the impact of authorizing users using the RBAC database was insignificant compared to the overhead of cryptographic operations and network transfer in general. This shows that a PostgreSQL database with the implemented design is a good option for RBAC Metadata Storage in the future.

=== Role Management

Role management (creating and assigning roles, granting permissions) using the implemented "query editor" provided an intuitive and familiar way of managing roles. Though this is just a wrapper over the admin API, and it could be implemented in many ways, this "query editor" is a valid option that could be used in the future.

=== Known Security Considerations

Two implementation-level security issues are acknowledged in the current OSWS release, within #link("https://github.com/lucasfth/osws/blob/V2026.0.0-alpha/KNOWN_ISSUES.md")[`KNOWN_ISSUES.md`].

First, S3 credential secret keys are stored in plaintext in the PostgreSQL database, as the SigV4 authentication handler requires the raw key for HMAC derivation.
If the database is compromised, all S3 credentials become immediately usable.
A mitigation would be to encrypt secret keys at rest using Azure Key Vault, decrypting on read during SigV4 verification.

Second, the RBAC admin flag is provisioned just-in-time from OIDC claims on every login.
If the OIDC provider exposes this as a self-service field, users could grant themselves admin access.
This is dependent on the OIDC provider configuration and can be mitigated by using a dedicated admin identity provider or restricting claim sources.
