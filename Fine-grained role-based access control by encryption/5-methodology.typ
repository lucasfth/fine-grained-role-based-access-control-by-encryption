#import "cmds.typ": todo, delete, maybeDelete, update

= Methodology
<sec:methodology>

As the intention of OSWS was for it to work on top of S3 and with existing "fully managed all-in-one cloud platforms" and other query engines, both benchmarking and e2e tests are quite important.
This section will cover both the setup of the benchmark and the setup of the e2e test.

== E2E Tests

As one of the goals of the OSWS was to enable third-party query engines to connect without any modification, a test confirming this behaviour is needed.

An end-to-end test will be created that asserts different query engines can connect and perform queries as normal, with OSWS providing column-level security based on the test user's roles.
The end-to-end test suite will contain a seeding step that sets up the necessary users and roles. Python scripts will be used to orchestrate setting up roles and permissions, and asserting that the fetched data does not contain unauthorized data.
#todo[passer det?]
The test will use the "Titanic" sample dataset #footnote(link("https://www.agentsfordata.com/app?sample-id=titanic&tab=local")) and permissions will be configured so two roles have limited access, but to different columns.
One role will inherit both and have direct access to all columns, thus having full access.
This will then test the role hierarchy feature.
Then, the following will be used to fetch the Parquet file through different users and assert that only the permitted columns are viewable:

*Python script* A Python script using an S3 client like `boto3` and a Parquet reader like `pyarrow` to fetch a file from OSWS.

*DuckDB* A DuckDB instance will query the parquet file through OSWS.

*Apache Spark* An Apache Spark instance (through PySpark) will query the parquet file through OSWS.

Each of the different tools should assert that only the permitted data is viewable.

== Benchmarking

All benchmarking of OSWS was run on a Digital Ocean VM with access to 8 cores and 16GB of DRAM, see~@sec:vm-spec, together with Digital Ocean's own Object Store (Spaces), which is S3-compatible. For benchmarks using a key vault, Azure Key Vault was used. All services were kept in the same region to ensure minimal network latency.
The version of OSWS used was #link("https://github.com/lucasfth/osws/releases/tag/V2026.0.0-alpha")[V2026.0.0 Alpha].

=== Micro Benchmarks

#todo[mention the N times it was run]

The micro benchmarks that will be run will show how each major part of OSWS performs to get insights into how much they add of latency.
The following micro-benchmarks will be run:

+ Permission Service
+ Permission Hierarchy
+ Unwrapping
+ Decryption

*Permission Service* will measure the latency of how long it takes to get a user's effective roles to the given columns.
The columns stay at a constant 100, the hierarchy (meaning roles pointing to roles) stays at zero, the roles assigned to the user are varied from four, 64, and 256 roles, and they are each assigned, on average, access to 80% of each of the columns.

*Permission Hierarchy* will measure the latency of how long it takes to get a user's effective roles, but instead, roles are now linked to other roles and lastly to columns.
The number of roles assigned is now constant at one, while the number of roles assigned in depth is varied from 0, 4, 16, and 64 and again, on average, each role is assigned access to 80% of the columns.

*Unwrapping* will measure the end-to-end latency for reading a tiny Parquet file (the small Parquet files are also run but ignored, but can be seen in~@app:micro) with a cold cache.
The varying key sizes of 128, 192, and 256 bits will primarily affect the symmetric AES-GCM decryption.

*Decryption* will measure the latency for reading and decrypting a Parquet file, and the keys for decrypting will have been warmed and thus stored in cache; thus, KV is not taken into account here.
The Parquet sizes that will be used are the same as with e2e benchmarking, being the tiny, small, medium, large, and extra large.

All of the micro-benchmarks were run 15 times to obtain statistically meaningful results.
  
See @tab:todo-benchmarks for an overview of the benchmarks and their configurations, which will be run.

#include "5-methodology/benchmark-config.typ"

=== E2E Benchmarks

The micro benchmarks show the individual parts' contribution to latency, but the overall performance of OSWS is more important to identify if, from a performance perspective if OSWS is usable within production environments.

As OSWS inherently implements different design choices compared to vanilla S3, no standardized benchmarking has been chosen, such as #link("https://github.com/minio/warp")[Warp] which is otherwise used by multiple other Fortune 500 companies.@using_minio_landbase@using_minio_theirstack
The reasoning for this is that OSWS implements its own caching layer and uses a KV; as such, the benchmark would have to ensure that it tests both the throughput of N instances of OSWS running and that the configuration of caching and encryption is considered thoroughly.
OSWS also encrypts each column, resulting in the sizes of the Parquet files having a lot of significance for the end throughput, and Warp does not vary its Parquet file size.
This results in inherently different throughputs and numbers, which are hard to compare OSWS against anything else.
Lastly, OSWS, as mentioned, does not support proper range requests, and it is then apparent that S3 will perform even better for ranged requests, where, regardless of the range or full file request, S3 will perform close to the same.#footnote[A solution to this is proposed within @sec:discussion.]
Thus, the choice was to set up the following e2e benchmarks.
The five Parquet files will be auto-generated by a script.
These will have the following sizes:

- _Parquet Size Tiny:_\~500KB Parquet file with 50 columns and 1,000 rows.
- _Parquet Size Small:_\~5MB Parquet file with 50 columns and 10,000 rows.
- _Parquet Size Medium:_\~125MB Parquet file with 50 columns and 250,000 rows.
- _Parquet Size Large:_\~500MB Parquet file with 50 columns and 1,000,000 rows.
- _Parquet Size X-Large:_\~1GB Parquet file with 50 columns and 2,000,000 rows.

This configuration was chosen to reflect a somewhat realistic distribution of different sizes of Parquet files. Various openly available datasets were compared to settle on the choice of 50 columns. For example, several real-world example datasets available from ClickHouse contain much fewer than 50 columns @clickhouse-datasets. Another is a dataset collecting 1.1 billion taxi and Uber rides in New York City, which contains 51 columns @uber-taxi. 50 columns then seemed like a realistic amount of columns for a large OLAP dataset.

Python scripts will then run Parquet puts and gets against the following setups:

- Directly against an S3-compatible store
- Against OSWS with encryption and with caching
- Against OSWS with encryption and no file cache
- Against OSWS with encryption and no DEK cache
- Against OSWS with no encryption and no caching

The metric for this will be latency, and for each file, the benchmark will be run for a total of 10 times, both cold and warm, allowing comparison of how slow or speed differences occur with and without caches.