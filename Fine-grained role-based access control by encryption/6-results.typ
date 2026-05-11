#import "cmds.typ": update, todo, speculation, delete
= Results

This section will cover the results of running both the benchmarks and e2e tests described in~@sec:methodology, and quickly define what they mean.

#delete[After running both the tests and benchmarks, important observations have been made.
OSWS works with query engines without modification, as seen by #todo[add proof of e2e test], but modifications to both OSWS and managed all-in-one platforms are needed for interoperability, see #todo[ref to sec].]

== E2E Tests

#todo[Trøstrup]

== Benchmarking

=== E2E Benchmarks
<sec:e2e-bench>

#todo[Trøstrup]

=== Micro-Benchmarks

#import "6-results/micro-boxplot.typ": microboxplot

#microboxplot

In @fig:micro-boxplot, all box-plots increase in duration whenever their role depth, flat roles, or the number of rows increases (Note that the y axis is not equal, and some of them are linear and others logarithmic).
The latency for Permission Hierarchy Benchmark, see~@fig:permission-hier-boxplot, and Permission Service Benchmark, see~@fig:permission-service-boxplot, both have a minor contribution to latency.
The major contributors to latency are decryption, see @fig:decryption-boxplot, and DEK unwrapping.
The unwrapping of the DEKs remains close to constant.
The DEK unwrapping is not something that can be improved much besides changing the KV service provider to a faster alternative, and then, as OSWS currently does, cache the unwrapped DEK heavily to use KV as little as possible.
Decryption is easier to optimize, due to OSWS, as per version #link("https://github.com/lucasfth/osws/releases/tag/V2026.0.0-alpha")[2026-alpha], relying on Parquet Sharp version 21.0.0.
To improve it, OSWS would need to implement a custom low-level decrypter, which would also allow for not needing to copy the partially decrypted Parquet file over to another Parquet file, but instead rewrite the columns in place, if decryption is needed.
This would help, as the current decryption micro-benchmark also takes the copying into account, though the main improvement would be seen when columns are not authorized to the client, and can thus be left as is.
So instead of the computations being directly related to the number of Parquet columns, they will be related to the number of authorized columns.

$ "Decryption:" O(|"columns"|) >= O(|"columns"_"authorized"|) $
