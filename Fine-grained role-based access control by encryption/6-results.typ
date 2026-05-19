#import "cmds.typ": update, todo, speculation, delete

= Results

This section will cover the results of running both the benchmarks and e2e tests described in~@sec:methodology, and quickly define what they mean.

// #delete[After running both the tests and benchmarks, important observations have been made.
// OSWS works with query engines without modification, as seen by #todo[add proof of e2e test], but modifications to both OSWS and managed all-in-one platforms are needed for interoperability, see #todo[ref to sec].]

== E2E Tests

An end-to-end test suite was written to test Python using PyArrow, DuckDB and PySpark against OSWS as an S3 endpoint.
No modifications were made to the tools outside of changing the S3-endpoint to an instance of OSWS.
The test suite shows that all three tools are successfully able to query a Parquet file and perform operations on the result.
The users are identified through their credentials, and columns that the users' roles do not give access to are masked correctly.

This demonstrates that OSWS works as a drop-in replacement for S3 when working with query engines that fetch Parquet files directly and do not store metadata.

#todo[ducklake here?]

== Benchmarking
<sec:benchmarking>

=== Micro-Benchmarks
<sec:microbench>

#import "6-results/micro-boxplot.typ": microboxplot

In @fig:micro-boxplot, all box-plots increase in duration whenever their role depth, flat roles, or the number of rows increases (Note that the y axis is not equal, and some of them are linear and others logarithmic).
The latency for Permission Hierarchy Benchmark, see~@fig:permission-hier-boxplot, and Permission Service Benchmark, see~@fig:permission-service-boxplot, both have a minor contribution to latency.

The major contributors to latency are decryption, see @fig:decryption-boxplot, and DEK unwrapping.

*DEK unwrapping* is close to constant.
But the time is not something that can be improved much besides changing the KV service provider to a faster alternative, and then, as OSWS currently does, cache the unwrapped DEK heavily to use KV as little as possible.
The values can be seen in more details in more details in @app:micro, but essentially the _p99_ time for unwrapping key size 256 of a tiny file is _4.11 seconds_, with a mean of _3.92 seconds_, meaning that caching the unwrapped DEKs is essential.

*Decryption* is the other main contributor.
With the tiny file, it has a _p99_ of _17.1 milliseconds_ and a mean of _13.6ms_, whilst for the medium and extra large, they are respectively, _p99_ _1.8 seconds_, mean _1.68 seconds_, and _p99_ _15.5 seconds_, mean _14.7 seconds_.
So, essentially, to make OSWS usable for larger files, changes are needed in the decryption.

The large numbers for the decryptions are due to a few design decisions.
First of #link("https://github.com/lucasfth/osws/releases/tag/V2026.0.0-alpha")[V2026.0.0 Alpha] relies on Parquet Sharp version 21.0.0, which, as mentioned, makes it necessary, regardless of permission level, to copy over the whole Parquet file.
To optimize this, a custom low-level reader would be needed, which could decrypt the columns in place.
This would help, as the current decryption micro-benchmark also takes the copying into account, though the main improvement would be seen when columns are not authorized to the client, and can thus be left as is.
So instead of the computations being directly related to the number of Parquet columns, they will be related to the number of authorized columns.

$ "Decryption:" O(|"columns"|) >= O(|"columns"_"authorized"|) $

#microboxplot

=== E2E Benchmarks
<sec:e2e-bench>

#import "6-results/e2e-bar-plots.typ": e2eplots

To begin with, comparison of cold GET latency with and without the DEK cache enabled is shown in @fig:dekcachelatency. Only tiny to medium is included due to the benchmark timing out on larger files (>600s).
#todo[se om vi skal bruge large og xlarge selvom de timer ud jf martin feedback]
However, even without large files, the DEK cache is invaluable even on small files, and on larger files, the system gets unusably slow without the DEK cache.
At first, it seemed surprising that the difference between a _cold_ GET, that is, where the DEK cache is empty from the start, and a GET where the DEK cache is not enabled, is this large.
However, it makes sense given that the DEK cache is warmed up as the file is being read, since reading a row chunk will populate the DEK cache with the columns of that chunk.
Since the whole column is encrypted with the same DEK, once that column is reached again in a new row chunk, the cache is warm.
This shows that the DEK cache is a must-have for OSWS.
For that reason, the "no DEK cache" configuration is omitted from here. 

@fig:e2eplot shows the results of the rest of the end-to-end benchmark suite. 
Originally, the intent was to have an x-large file size as well, but this turned out to be too slow to reasonably include in the plots.
This also shows that there is a weakness when the files get to the ~1GB size.

However, looking at~@fig:median-get-latenct-warm-cache for a *warm* GET, it is again clear that the DEK cache is a must-have.
On smaller files, all configurations of OSWS actually come close to the direct Digital Ocean fetch, though there is clearly a lot of overhead still.
Interestingly, the "no encrypt" is seemingly a bit _slower_ than the other configurations for the "tiny" and "small" configuration, even though it should just be the pure network overhead.
However, disabling encryption also disables the file cache, which might be why it is slower -- due to it having to go to Digital Ocean every time.

In~@fig:median-get-latency-cold-cache *cold* GET is shown.
Direct fetch is omitted here due to there being no "cold" path -- this is the same as~@fig:median-get-latenct-warm-cache.
Here, the "no encryption" configuration is an order of magnitude faster for the "tiny" and "small" configurations, which highlights the overhead of the decryption step. However, as the files get larger, the network overhead starts to show as well, when the "no encryption" configuration starts to approach the other configurations.

Generally, both~@fig:median-get-latenct-warm-cache and~@fig:median-get-latency-cold-cache also show that the file cache is mostly useful when files are large; this is not surprising, as the encrypted file cache only helps with reducing S3-fetches, as the file must still be decrypted again. But when the network cost starts getting visible, the file cache matters.

@fig:median-put-latency shows the PUT latency. Unsurprisingly, there is massive overhead on the "tiny" configuration, as the direct upload is in millisecond-level, while OSWS must spend time encrypting the file and making calls to KV.
Again, as files get larger, the relative overhead reduces as network transfer becomes a factor.

#include "6-results/dekcachelatency.typ"

#todo[Probably needs some specific numbers mentioned. Like takes this amount of sec for this size. And something like this setup is XXX sec/ms slower than S3 direct...]

#e2eplots
