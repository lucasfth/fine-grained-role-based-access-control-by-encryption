#import "cmds.typ": todo, delete, maybeDelete

= Methodology

== Benchmarking

Since the OSWS will act as a wrapper for the real S3, it is essential to measure the baseline overhead of the OSWS.

For this #link("https://github.com/minio/warp")[Warp] by #link("https://www.min.io/")[MinIO] will be used.
MinIO previously provided the OSS #link("https://github.com/minio/minio")[MinIO], a S3-compatible object store.
MinIO's services are used by multiple Fortune 500 companies, such as Apple and Intel.@using_minio_landbase@using_minio_theirstack
Their benchmark is chosen as it is specifically created to benchmark S3-compatible systems, and they themselves, and #link("https://github.com/seaweedfs/seaweedfs#run-warp-and-launch-a-mixed-benchmark")[SeaweedFS] use it to benchmark their systems.
Warp is also used within academia, e.g. in "Performance analysis of mdx II: A next-generation cloud platform for cross-disciplinary data science research" by Takashi et.al.@takahashi2025performanceanalysismdxii
A large community also supports Warp; it has 39 contributors and 767 stars on GitHub and is on the stable 1.4.1 release, as of the day of writing.#footnote[Written 2026/04/14].
Alternatives such as #link("https://github.com/intel-cloud/cosbench")[COSBench] or #link("https://github.com/igneous-systems/s3bench")[S3Bench] are respectively in pre-release and archived, and thus these were not chosen.
Other benchmarks also exist, but they are usually designed, e.g. OLAP and OLTP, and are therefore not representative of data lakes' workloads.
Warp will then be run directly against S3, against OSWS with cryptographic operations skipped, against OSWS with encryption but without caching, and against OSWS with encryption and with caching.
This will allow comparison between the basic overhead OSWS might add, but also enable a general comparison between other systems, which ensures access control by encryption.
To see if OSWS scales, it is necessary to test with multiple instances.
This will be done by running the benchmark with the following varying number of instances: one, two, four, and eight.
Since it was run on personal computers, it was limited to eight cores, as the computers were limited to 12 cores in total, and 6 of them were performance cores, and therefore, the rest of the cores were used by other background tasks.
See @fig:hardware-specs for hardware specifications.

Given the results, it is relevant to identify what causes overhead.
Tiny benchmarks are useful to identify which parts are to blame for the overhead and when something can be fixed by changing the implementation.
The following tiny benchmarks will be measured:

- *Authorization:* How long it takes to authorize the user's access to a column.\
  Should be done for an RBAC system with four roles: 64 and 256.
- *Unwrapping:* How long it takes to unwrap a key.\
  Should be done for key sizes of 128 and 256 bits.
  This 
- *Decryption:* How long it takes to decrypt a column.\
  Should be done for 5000 rows, 10,000 rows, and 10,000,000 rows, columns will stay constant at 2,000 columns\
  The encryption algorithm used within Parquet Sharp is AES.

See @tab:todo-benchmarks for an overview of the benchmarks and their configurations which will be run.

#figure(
  // Used https://www.latex-tables.com/?format=typst for generation
  caption: [Main configurations of benchmarks that are to be run],
  placement: top,
  scope: "parent", // either parent or column
  table(
    columns: 4,
    align: left + horizon,
  [*Category*], [*Benchmark*], [*Configuration*], [*Measurements*],
  [*Baseline*],
    [S3],
    [Instances: 1, 2, 4, 8],
    [IOPS, Throughput],
  [*Baseline*],
    [OSWS - encryption],
    [Instances: 1, 2, 4, 8],
    [IOPS, Throughput],
  [*Baseline*],
    [OSWS + encryption - caching],
    [Instances: 1, 2, 4, 8],
    [IOPS, Throughput],
  [*Baseline*],
    [OSWS + encryption + caching],
    [Instances: 1, 2, 4, 8],
    [IOPS, Throughput],
  [*Micro*],
    [Authorization],
    [No. roles: 4, 64, 256],
    [Latency],
  [*Micro*],
    [Unwrapping],
    [Key size: 128, 256 bits],
    [Latency],
  [*Micro*],
    [Decryption],
    [No. rows: 5,000, 10,000, 10,000,000 (2,000 columns)],
    [Latency],
  )
)<tab:todo-benchmarks>

It will also be identifiable if the caching is effective in improving IOPS and throughput, and if it scales with multiple instances of OSWS running at once.
But of course, the performance of the OSWS and another is the compatibility of it.

=== Testing

As one of the goals of the OSWS was to enable all query engines and fully managed data lake platforms to use it, a few tests are needed.

One query engine and one fully managed data lake platform should be able to connect to the OSWS by only changing the URL for the real S3 to the OSWS one.
// I den rigtige rapport skal vi nok inkludere præcise definitioner af setuppet her; hvad er det for en query engine? i hvilket setup? og hvad for en "fully managed data lake platform" (plus måske også definere hvad vi mener med det). Desuden er det vigtigt at specificere at det vi mener er at en fully managed data lake platform's QUERY ENGINE skal kunne bruge os, hvilket kræver at de supporter det (fx Snowflakes external tables)
Both should be able to put and get files (given sufficient permissions) as they normally do.
Depending on how they read the data, some modifications might be needed as the columns might still be encrypted, which will result in an error, but this cannot be addressed without changing the actual schema in the OSWS.
