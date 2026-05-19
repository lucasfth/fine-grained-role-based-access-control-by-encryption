#import "cmds.typ": delete, todo, speculation
= Conclusion

#delete[The current implementation of OSWS proves that fine-grained role-based access control is possible within data lakes, and that query engines which do not cache sizing data can use it without any modifications, and that, depending on whether the "fully managed all-in-one cloud platforms" use it or not, the only change needed is to whitelist a third-party link to OSWS.
] // DELETE TO HERE

OSWS demonstrates the possibility of adding fine-grained role-based access control in data lakes by using encryption and thus enforcing it within the Object Store.
Query engines that do not cache Parquet sizing metadata, such as DuckDB, can use OSWS without modifications by pointing their S3 URL to OSWS.

The benchmarks show the DEK cache is an essential part of OSWS.
Without it, cold GET latency for a _5MB_ file is _~3.7s_.
With the DEK cache enabled, the same operations take _92ms_.
Another dominant contributor to latency is the cryptographic operations, which a custom Parquet reader, implementing in-place decryption with AES-CTR, would reduce.

The main limitation with current OSWS is that query engines and "fully managed all-in-one cloud platforms" (such as DuckLake and Snowflake) cache Parquet metadata, and as OSWS encrypts and writes metadata, the Parquet file sizes change, and their internal metadata are no longer correct.
The other limitations are that for larger files, it adds a significant overhead, which would make it unusable in production.
For files of Parquet files of sizes _500MB_ and _1GB_, the query engines timed out, due to too much latency.
For Parquet files of sizes _125MB_, it still had a warm _p95_ GET latency of _~1.8s_ and a cold of _~6s_, which would render OSWS too slow in production.

== Future Work

#delete[As suggested, it is believed that OSWS in its current state is not the proper implementation of how such a system should work, but that it could have a place within the current ecosystem of data lake uses.

The improvements needed are to implement a custom reader and writer, together 

One of the most important changes is to implement the custom reader and writer as mentioned in~@sec:encryption-decryption.
] // DELETE TO HERE

The improvement with the most impact would be the custom Parquet reader and writer, supporting in-place encryption and decryption, using AES-CTR.
This would eliminate sizing changes and enable proper range requests, given that metadata is also moved, but also remove the need to copy over the whole Parquet file.
#speculation[The metadata specifically should be handled internally, and the Parquet footer will not be used to store extra metadata.
Instead, the RBAC database will be extended further to store which DEKs are linked to which columns and those linked to the internal roles.] // Giver dette mening????

Additional future work includes: extending the S3-API coverage, implementing concurrency in row-group processing, and supporting compression pass-through to avoid decompression overhead without changing the size.
