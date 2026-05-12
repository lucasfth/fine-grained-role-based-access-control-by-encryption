#import "cmds.typ": todo, delete

= Discussion
<sec:discussion>

OSWS set out to provide columnar access control to 3rd party query engines and "fully managed all-in-one cloud platforms" by encrypting columns individually using PME, provided through the Parquet Sharp library, see @sec:encryption-flow.
In short, during the encryption flow, the Parquet size is changed due to how Parquet Sharp operates, as well as added metadata.
This eliminates query engines, which use the range modifier based on cached sizes and do not read from the modified metadata.
This then eliminates DuckLake from using OSWS, as it caches the inserted ranges~@ducklake_cached.
The same issue is prevalent for "fully managed all-in-one cloud platforms", due to the incompatible design choices made @snowflake_external_tables@snowflake_external_tables_files.

OSWS was intended to support all 3rd party query engines and "fully managed all-in-one cloud platforms", but in its current state the platforms and some query engines are not supported.
For the platforms, it has not been possible to test OSWS, as it would need the providers to whitelist a URL where OSWS would run.
But most of these incompatibility issues are from the initial design choices made during the start, but first became apparent on the final iteration of designing benchmarking and e2e tests, which, based on the research paper~@own-paper, made sense, but after modifying it to work with the various providers, did not make sense anymore and had unnecessary overhead or created other problems, and as such this section will address those issues, define what should have been done instead, and define which performance done in OSWS which can be removed.

== Metadata
<sec:metadata>

The idea for OSWS was to allow third-party query engines to decrypt Parquet files themselves locally, while decrypting within OSWS for "fully-managed cloud data lake platforms".
This would be achieved by storing key IDs within the footer of the Parquet files, and the query engines could then, through an endpoint in OSWS, request the given key and then decrypt the column locally, and OSWS would do the logic itself.
As soon as it was identified that this was not possible with KV to retrieve the keys from it, OSWS was changed to use envelope encryption and store the wrapped DEKs, and the KEK reference in the footer, due to it being partly meant for that purpose.
When a client puts a file through OSWS, the Parquet file size is modified to contain related wrapped DEKs and KEK reference.
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

Another improvement is when range requests are given, OSWS can figure out which ranges are related to which columns given _2_ and then retrieve it from S3.
Meanwhile it can retrieve the unwrapped DEKs, to be ready for decryption.
Now for decryption it can use the row chunk size _6_ to be able to decrypt the small part, though only possible if AES CTR is used, more on this in~@sec:encryption-decryption.

So for metadata, it should only be saved within internal SQL, still, as the current solution relies on SQL, and then the encryption of the columns also needs to change.

== Encryption & Decryption
<sec:encryption-decryption>

Currently, encryption and decryption are handled by Parquet Sharp, which is a .NET package which supports PME.
Choosing this library was a mistake, as it handles encryption and decryption by reading everything (using cryptographic keys if provided) and copying it into a new Parquet file.
If no cryptographic key is provided to an encrypted column, it fails.
So here are two major issues with how it handles cryptography:

+ It reads and copies the entire file regardless of whether a single column has to be decrypted or all of them.
+ It does not allow for copying over encrypted columns.

Also, as~@sec:metadata, the size of the Parquet file changes upon encryption, due to PME, and thus creates issues for range requests.

All this could be solved by using the implementing a custom reader and writer for the Parquet files, which would use decrypt and encrypt in place, thus fixing _1_, being able to leave non-authorized columns encrypted, thus solving _2_, and not changing metadata and using the solution described in~@sec:metadata.
Important for the encryption is that AES CTR, which does not use any padding, and thus is also a contributor to not modifying any part of the size of the file.Dworkin_2001
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
This improvement might even become smaller and less useful with proper range support, and will thus be one of the later improvements which might be tested on a future OSWS system.
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