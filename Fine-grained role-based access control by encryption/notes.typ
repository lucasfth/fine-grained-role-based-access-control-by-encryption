Quick notes by atro

*"File-size issue"*

- We should probably have a section that outlines the shortcoming/limitation/problem of file sizes for readers that cache and don't rely on HEAD requests, like DuckLake

Since ducklake caches the file sizes in its catalog, when it writes the file it assumes it hasn't changed when fetching it; but when we re-write the file or return it with null columns the file has changed, resulting in corrupted range reads. This is a fundamental design incompatibility: trusting that file doesn't change vs actively changing file by encrypting and masking columns
We could include the experiment with DuckLake that highlights the issue
not sure what the "fix" is here. But we can write about it.

*Wide datasets for benchmark*
It is not as uncommon as we hoped that datasets are more than 50 columns wide. It does exist in some real-world datasets.
https://github.com/cwida/public_bi_benchmark/tree/master/benchmark/USCensus/tables
https://data.transportation.gov/Public-Transit/Monthly-Modal-Time-Series/5ti2-5uiv/about_data
Perhaps we should be ready to discuss what the results would look like on wider datasets or run new benchmarks
