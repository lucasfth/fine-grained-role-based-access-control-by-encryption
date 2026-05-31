#import "cmds.typ": update, todo, speculation, delete, new

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


In~@fig:micro-boxplot, the box-plots for the micro-benchmarks are shown, and it is important to note that not all $y$ axes use the same scale, and some use logarithmic scaling.

The latency for Permission Hierarchy Benchmark, see~@fig:permission-hier-boxplot, and Permission Service Benchmark, see~@fig:permission-service-boxplot, both have a minor contribution to latency, which is expected for RBAC-related calls.

The major contributors to latency are decryption, see~@fig:decryption-boxplot, and DEK unwrapping, see~@fig:unwrap-boxplot.

Latency for _DEK unwrapping_ does not grow much across the different key sizes.
This is expected as the DEKs are unwrapped asynchronously, and the number of columns remains constant.
Also, the time is not something that can be improved much besides changing the KV service provider to a faster alternative, and then, as OSWS currently does, cache the unwrapped DEK to use KV as little as possible.
The values can be seen in more details in more details in~@app:micro, but essentially the _p95_ time for unwrapping key size $256$ of a tiny file is $4.11$ seconds, with an average of $3.92$ seconds, meaning that caching the unwrapped DEKs is essential, as if not cached this time would have to be added to each time a column has to be decrypted.

- Tiny had a _p95_ latency of $17.1$ milliseconds and an average of $13.6$ milliseconds
- Medium had a _p95_ latency of $1.8$ seconds and an average of $1.68$ seconds
- X-Large had a _p95_ latency of $15.5$ seconds and an average of $14.7$ seconds

So, essentially, to make OSWS usable for larger files, fundamental design changes are needed in the decryption step.

The large numbers for the decryptions are due to a few design decisions.
OSWS relies on Parquet Sharp, which, as mentioned, makes it necessary, regardless of permission level, to copy over the whole Parquet file.
To optimize this, a custom low-level reader would be needed, which could decrypt the columns in place.
This would help, as the current decryption micro-benchmark also takes the copying into account, though the main improvement would be seen when columns are not authorized to the client, and can thus be left as is.
So instead of the computations being directly related to the number of Parquet columns, they will be related to the number of authorized columns.

=== E2E Benchmarks
<sec:e2e-bench>

#include "6-results/dekcachelatency.typ"

#import "6-results/e2e-bar-plots.typ": e2eplots

To begin with, a comparison of cold GET latency, with and without the DEK cache enabled, is shown in~@fig:dekcachelatency.
It can be seen that a ceiling is hit at \~600 seconds for the _large_ and _x-large_ Parquet files, without DEK cache enabled.
This can be attributed to the benchmarking timing out.
This shows that on files at $\~500$MB and $\~1$GB, the system is unusably slow without the DEK cache.
However, there is a huge difference even for smaller files.
For the _tiny_ GET, it was about $\~5.6$#sym.times slower, and for _medium,_ it was about times $\~13$#sym.times slower.#footnote[Calculated from the results shown in~@app:e2e-res]

At first, it seemed surprising that there was such a large difference in having the DEK cache enabled, given that the cache is _cold_ in this benchmark. 
However, this can be explained by the DEK cache warming up _as the file is being read_, since reading a row chunk will populate the DEK cache with the given columns of that chunk.
Since the whole column is encrypted with the same DEK, once that column is reached again in a new row chunk, the cache is warm.
These results show that the DEK cache is a must-have for OSWS.
For that reason, the *no DEK cache* configuration is omitted from here on. 

#e2eplots

Looking at~@fig:median-get-latenct-warm-cache for a warm GET, it is again clear that the DEK cache decreases latency noticeably.
On the _tiny_ file size, all OSWS configurations sit at around $\~30$ milliseconds, thus being comparatively fast to larger file sizes.
However, the relative overhead compared to direct fetch is still significant, with the direct fetch about $\~10$ milliseconds.
Specifically, the results show an overhead of $\~2.5$#sym.times for OSWS with caching and direct fetch, with an average of $30$ and $12$ milliseconds, respectively.#footnote[See @app:e2e-res for full results]
While the relative overhead is large, OSWS at $30$ milliseconds remains practically useful.

Interestingly, the *no encrypt* is seemingly a bit slower than the other configurations for the _tiny_ and _small_ configuration, even though it should just be the pure network overhead.
However, disabling encryption also disables the file cache, which might be why it is slower -- due to it having to go to Digital Ocean every time.
This is hinted at by it being very close to the *no file cache* configuration.
But this is mostly speculation and would require further benchmarks to prove.
More strangely, the _x-large_ size on *warm GET* is seemingly much slower than *cold GET*.
This result does not make much sense and should likely be disregarded entirely. 
This can be due to various factors, but is reasoned to be due to data fragmentation increasing over the benchmark runs.
Lastly, reading from the data lake and the encrypted file cache might also have some unforeseen consequences, as they respectively use a memory stream and a file stream.
But as the main latencies in the system were related to encryption/decryption and KV, this was down-prioritized.

In~@fig:median-get-latency-cold-cache cold GET is shown.
Direct fetch is omitted here due to there being no _cold_ path -- this is the same as~@fig:median-get-latenct-warm-cache.

Here, the *no encryption* configuration is much faster than the others for smaller files, at almost two orders of magnitude faster for the _tiny_ file.

For OSWS with and without file caching, there is generally little difference in latency from the _tiny_ to _medium_ files.
This highlights the overhead of fetching DEKs from the KV and performing decryption itself.
However, as the files get larger, the network overhead of simply fetching the file starts to show as well, when the *no encryption* configuration starts to approach the other configurations.

Both~@fig:median-get-latenct-warm-cache~and~@fig:median-get-latency-cold-cache also show that the file cache is mostly useful when files are large; this is not surprising, as the encrypted file cache only helps with reducing S3-fetches, as the file must still be decrypted again.
But when the network cost of fetching starts getting meaningful, the file cache matters.

@fig:median-put-latency shows the PUT latency.
Unsurprisingly, there is massive overhead on the _tiny_ configuration, with the direct upload at around $\~30$ milliseconds, and OSWS at $\~3000$ milliseconds.
This is explained by the direct upload being pure network latency to the Object Store, while OSWS must spend time encrypting the file and making calls to KV, on top of uploading the resulting file.
Again, as files get larger, the relative overhead reduces as the network cost of uploading becomes the dominating factor.
