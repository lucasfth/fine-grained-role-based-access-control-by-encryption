Quick notes by atro

*"File-size issue"*

- We should probably have a section that outlines the shortcoming/limitation/problem of file sizes for readers that cache and don't rely on HEAD requests, like Ducklake

Since ducklake caches the file sizes in its catalog, when it writes the file it assumes it hasn't changed when fetching it; but when we re-write the file or return it with null columns the file has changed, resulting in corrupted range reads. This is a fundamental design incompatibility: trusting that file doesn't change vs actively changing file by encrypting and masking columns
We could include the experiment with Ducklake that highlights the issue
not sure what the "fix" is here. But we can write about it.