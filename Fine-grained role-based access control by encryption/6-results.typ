#import "cmds.typ": update, todo, speculation, delete

= Results

This section will cover the results of running both the benchmarks and e2e tests described in~@sec:methodology, and describe their significance.

== E2E Tests

An e2e test suite was written to test Python using PyArrow, DuckDB and PySpark against OSWS as an S3 endpoint.
No modifications were made to the tools outside of changing the S3-endpoint to an instance of OSWS.
The test suite shows that all three tools are successfully able to query a Parquet file and perform operations on the result.
The users are identified through their credentials, and columns that the users' roles do not give access to are masked correctly.

This demonstrates that OSWS works as a drop-in replacement for S3 when working with query engines that fetch Parquet files directly and do not store metadata.

The same e2e test was tried to be done for DuckLake, but due to how OSWS modifies the Parquet file, it was not supported.

== Benchmarking
<sec:benchmarking>

=== Micro-Benchmarks
<sec:microbench>

#import "6-results/micro-boxplot.typ": microboxplot
#microboxplot

In @fig:micro-boxplot, all box-plots increase in duration whenever their role depth, flat roles, or the number of rows increases (Note that the $y$ axis are not necessarily using the same scale, and three of them are log-scaled).
The latency for Permission Hierarchy Benchmark, see~@fig:permission-hier-boxplot, and Permission Service Benchmark, see~@fig:permission-service-boxplot, both have a minor contribution to latency, which is expected for RBAC-related calls.
These will not be referenced more as optimizations for these would not provide much benefit.

The major contributors to latency are decryption, see~@fig:decryption-boxplot, and DEK unwrapping, see~@fig:unwrap-boxplot.

_DEK unwrapping_ is close to constant.
But the time is not something that can be improved much besides changing the KV service provider to a faster alternative, and then, as OSWS currently does, cache the unwrapped DEK heavily to use KV as little as possible.
The values can be seen in more details in more details in @app:micro, but essentially the _p95_ time for unwrapping key size $256$ of a tiny file is $4.11$ seconds, with a mean of $3.92$ seconds, meaning that caching the unwrapped DEKs is essential, as if not cached this time would have to be added to each time a column has to be decrypted.

_Decryption_ is the other main contributor.
With the tiny file, it has a _p95_ of $17.1$ milliseconds and a mean of $13.6$ms, whilst for the medium and x-large, they are respectively, _p95_ $1.8$ seconds, mean $1.68$ seconds, and _p95_ $15.5$ seconds, mean $14.7$ seconds.
So, essentially, to make OSWS usable for larger files, changes are needed in the decryption step.

The large numbers for the decryptions are due to a few design decisions.
First of #link("https://github.com/lucasfth/osws/releases/tag/V2026.0.0-alpha")[V2026.0.0 Alpha] relies on Parquet Sharp version 21.0.0, which, as mentioned, makes it necessary, regardless of permission level, to copy over the whole Parquet file.
To optimize this, a custom low-level reader would be needed, which could decrypt the columns in place.
This would help, as the current decryption micro-benchmark also takes the copying into account, though the main improvement would be seen when columns are not authorized to the client, and can thus be left as is.
So instead of the computations being directly related to the number of Parquet columns, they will be related to the number of authorized columns.

#set math.equation(numbering: none)
$ "Decryption:" O(|"columns"|) >= O(|"columns"_"authorized"|) $


=== E2E Benchmarks
<sec:e2e-bench>

#include "6-results/dekcachelatency.typ"

#import "6-results/e2e-bar-plots.typ": e2eplots

To begin with, comparison of cold GET latency with and without the DEK cache enabled is shown in~@fig:dekcachelatency.
It can be seen that a ceiling is hit at $~600$ seconds for the large and x-large Parquet files, without DEK cache enabled.
This can be attributed to the benchmarking timing out.
The DEK cache can be seen to be invaluable on even small Parquet files, and on larger files, the system gets unusably slow without the DEK cache.
At first, it seemed surprising that there was such a significant difference between a cold GET and a warm GET.
For the tiny GET, it was close to $120$ times and $3562$ms slower on average, and for the medium, it was close to $4$ times and $4148$ms slower.#footnote[Calculated from the results shown in~@app:e2e-res]
However, it makes sense given that the DEK cache is warmed up as the file is being read, since reading a row chunk will populate the DEK cache with the given columns of that chunk.
Since the whole column is encrypted with the same DEK, once that column is reached again in a new row chunk, the cache is warm.
This shows that the DEK cache is a must-have for OSWS.
For that reason, the "no DEK cache" configuration is omitted from here on. 

#speculation[@fig:e2eplot shows the results of the rest of the e2e benchmark suite.
The large and x-large Parquet file size results should be omitted in the evaluation, as the benchmarks became increasingly chaotic.
This can be due to various factors, but is reasoned to be due to data fragmentation increasing over the benchmark runs.
Lastly, reading from the data lake and the encrypted file cache might also have some unforeseen consequences, as they respectively use a memory stream and a file stream.
But as the main latencies in the system were related to encryption/decryption and KV, this was down-prioritized.
] // Ændring til her

#e2eplots

Looking at~@fig:median-get-latenct-warm-cache for a warm GET, it is again clear that the DEK cache clearly decreases latency.
On smaller files, all OSWS configurations come close to the direct Digital Ocean fetch, though the overhead is significant.
Interestingly, the "no encrypt" is seemingly a bit _slower_ than the other configurations for the "tiny" and "small" configuration, even though it should just be the pure network overhead.
However, disabling encryption also disables the file cache, which might be why it is slower -- due to it having to go to Digital Ocean every time.

In~@fig:median-get-latency-cold-cache cold GET is shown.
Direct fetch is omitted here due to there being no "cold" path -- this is the same as~@fig:median-get-latenct-warm-cache.
Here, the "no encryption" configuration is an order of magnitude faster for the "tiny" and "small" configurations, which highlights the overhead of the decryption step.
However, as the files get larger, the network overhead starts to show as well, when the "no encryption" configuration starts to approach the other configurations.

Generally, both~@fig:median-get-latenct-warm-cache and~@fig:median-get-latency-cold-cache also show that the file cache is mostly useful when files are large; this is not surprising, as the encrypted file cache only helps with reducing S3-fetches, as the file must still be decrypted again. But when the network cost starts getting visible, the file cache matters.

@fig:median-put-latency shows the PUT latency.
Unsurprisingly, there is massive overhead on the "tiny" configuration, as the direct upload is in millisecond-level, while OSWS must spend time encrypting the file and making calls to KV.
Again, as files get larger, the relative overhead reduces as network transfer becomes a factor.
