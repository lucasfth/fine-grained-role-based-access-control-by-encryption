#import "cmds.typ": todo

= Discussion

During the final iteration of designing benchmarking and E2E tests, it became apparent that the system design of OSWS had design choices, which, based on the research paper~@own-paper, made sense, but after modifying it to work with the various providers, did not make sense anymore and had a huge overhead or created other problems, and as such this section will address those issues, define what should have been done instead, and define which performance done in OSWS which can be removed.

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

Together with a full range of requests, support for more concurrency can be used.
When OSWS get a request to read a file, it can start retrieving it.
In the meantime, it can also go to the local database and find files which match _1_.
It can then see which keys the client has access to in the RBAC database, and then match the columns with _3_, then for each send _4_ to KV given _5_.

Another improvement is when range requests are given, OSWS can figure out which columns are related to the range due to _2_ and then retrieve the needed parts from S3 and meanwhile retrieve the unwrapped DEKs, to be ready for decryption.

So for metadata, it should only be saved within internal SQL, still, as the current solution relies on SQL, and then the encryption of the columns also needs to change.

== Encryption & Decryption

Currently, encryption and decryption are handled by Parquet Sharp, which is a .NET package which supports PME.
Choosing this library was a mistake, as the way it handles encryption and decryption is reading everything (using cryptographic keys if provided) to then copy it over into a new Parquet file.
If no cryptographic key is provided to an encrypted column, it fails.
So here are two major issues with how it handles cryptography:

+ It reads and copies the entire file regardless if a single column has to be decrypted or all of them.
+ It does not allow for copying over encrypted columns.

Also, as~@sec:metadata, the size of the Parquet file is changed upon encryption, due to PME, and thus creates issues for range requests.

All this could be solved by using the implementing a custom reader and writer for the Parquet files, which would use decrypt and encrypt in place, thus fixing _1_, being able to leave non-authorized columns encrypted, thus solving _2_, and not changing metadata and using the solution described in~@sec:metadata.

== Compression

For Parquet Sharp to copy over a column, it has to decompress the file.
Here, OSWS thus modifies the file size, but 