#import "cmds.typ": delete, todo, speculation

= Conclusion

#delete[The current implementation of OSWS proves that fine-grained role-based access control is possible within data lakes, and that query engines which do not cache sizing data can use it without any modifications, and that, depending on whether the "fully managed all-in-one cloud platforms" use it or not, the only change needed is to whitelist a third-party link to OSWS.
] // DELETE TO HERE

The PoC OSWS demonstrates the possibility of adding fine-grained role-based access control in data lakes by using encryption with native Parquet files, and thus enforcing it within the Object Store.
Query engines that do not cache Parquet sizing metadata, such as DuckDB, can use OSWS without modifications by pointing their S3 URL to OSWS.

The benchmarks showed that the DEK cache implemented in the OSWS was a completely necessary optimization.
Without it, cold GET latency for a $5$MB file is $\~3.7$ seconds.
With the DEK cache enabled, the same operations take $92$ms.
But as soon as larger files were used, the latency quickly became large enough to make the current state of OSWS usable in production.
These latencies were found to be the fault of two major parts of the system, and another one which has not been measured.

_1st_ one was the latency given the KV.
For this part, OSWS could do little to improve cold latency, though using caching helped a lot.
For cold improvements, the KV would have to be switched out with a more performant alternative.

_2nd_ was the decryption.
As Parquet Sharp was used within OSWS, some limitations were hit, such as the fact that the decryption had to be done sequentially, but also that when decryption happens, it actually has to copy the new data into a new Parquet file.
This is extremely inefficient if a client only has access to a single column, and the result is that the whole file still has to be written.

The last thing, which was known, is that OSWS internally does not support ranged requests, as OSWS does not save metadata related to the byte-ranges nor the wrapped DEKs.
This means that when a client requests a narrow range of information, OSWS has to fetch the whole file, and then it can find out which DEKs are needed in their unwrapped format.
It can then copy over all the data, column-by-column, to reflect the actual Parquet file in its correct size, as it does not copy over the DEK metadata.
Now it can return the range to the client.
This is an extreme amount of operations compared to the minuscule amount of data the client might be requesting, but given the design choices made, this has to be done this way.

These things limit the use-case of OSWS, and can be more used as learnings for creating a future OSWS which solves these issues.
Because in the current state, OSWS has only solved objectives one and three to some extent OSWS is not a viable state.
Ojbective one and three being, making it support fine-grained access control by encryption in data lakes with RBAC and then partially supporting 3rd party query engines.
Objective two was completely missed, supporting "fully managed all-in-one cloud platforms".

As discussed in~@sec:discussion some design changes would be able to solve these issues.


== Future Work

First, the cryptographic metadata has to have its location changed from being in the Parquet metadata to being part of OSWS's internal store.

The design changes needed are to implement a custom reader/writer.

The improvement with the most impact would be the custom Parquet reader and writer, supporting in-place encryption and decryption, using AES-CTR.
This would eliminate sizing changes and enable proper range requests, given that metadata is also moved, but also remove the need to copy over the whole Parquet file.
#speculation[The metadata specifically should be handled internally, and the Parquet footer will not be used to store extra metadata.
Instead, the RBAC database will be extended further to store which DEKs are linked to which columns and those linked to the internal roles.] // Giver dette mening????

Additional future work includes: extending the S3-API coverage, implementing concurrency in row-group processing, and supporting compression pass-through to avoid decompression overhead without changing the size.
