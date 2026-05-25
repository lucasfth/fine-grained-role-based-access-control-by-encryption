#import "cmds.typ": delete, todo, speculation

= Conclusion


The PoC OSWS demonstrates the possibility of adding fine-grained role-based access control in data lakes by using encryption with native Parquet files, and thus enforcing it within the Object Store.
Query engines that do not cache Parquet sizing metadata, such as DuckDB, can use OSWS without modifications by pointing their S3 URL to OSWS.

This thesis had the following five objectives:

#import "1-intro.typ": objectives
#objectives

Only four of the objectives were partially completed, as _3_ were not possible due to limitations of whitelisting.
Fine-grained RBAC with column-level encryption was achieved in OSWS, proved by an e2e test, and addressing objectives _1_ and _2_.
3rd party query engines not using cached metadata, such as DuckDB, could have OSWS dropped in as an S3 replacement without modifying them, partially solving objective _4_.

The whole system was benchmarked, and showed that a DEK cache is non-negotiable, even with small Parquet files; the latency improved dramatically when using it.
This solved objective _5_.
But generally, it showed that OSWS in its current state is not production-ready, due to the design choices made.

The results of the current state of OSWS are better seen as design proof that such a system could work.
The issues identified were a lot of sequential work, modified metadata, and unsupported range requests internally.
But these issues have been reflected upon and potential solutions proposed within~@sec:discussion, thus addressing objective _6_.
