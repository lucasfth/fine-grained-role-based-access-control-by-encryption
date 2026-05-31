#import "cmds.typ": delete, todo, speculation, new

= Conclusion


The proof-of-concept version OSWS demonstrates the feasibility of adding fine-grained role-based access control in data lakes by encryption with native Parquet files, and thus enforcing it within the Object Store.
Query engines that do not cache Parquet sizing metadata, such as DuckDB, can use OSWS without modifications by pointing their S3 URL to OSWS.

This thesis had the following six objectives:

#import "1-intro.typ": objectives
#objectives

Four of the six objectives were partially completed.

The OSWS PoC was successfully created and supports column-level RBAC using encryption.

Making it compatible with "fully managed all-in-one cloud platforms" was not possible to test, due to whitelisting limitations.

External query engines were able to be connected to the system without needing any modifications -- though only for the ones that do not cache metadata on write.
Meaning that objective _4_ was only partially completed.
DuckDB could use OSWS as a drop-in replacement for S3 without needing any modifications, but DuckLake was not able to use OSWS.

OSWS was benchmarked, and showed that a DEK cache is a non-negotiable, even with small Parquet files; going from no DEK cache entirely to a cold cache resulted in a $\~5.6$#sym.times improvement from $20.1$ seconds on average to $3.6$ seconds on average. Going from a cold to a warm DEK cache further improved latency by about $\~120$#sym.times down to $30$ milliseconds. While still a $\~2.5$#sym.times overhead, it remains practically usable.

However, generally the benchmarks showed that OSWS in its current state is not production-ready, due to design choices; $1$GB Parquet files made the system time out and for $125$MB Parquet files, retrieving them in their best case would take $1.6$ seconds.

The results of the current state of OSWS are better seen as a design proof that the suggested system is possible.
A lot of design decisions have to be carried over into a potential future version of it, including: DEK caching, envelope encryption, KV provider agnostic, and OIDC provider agnostic.
While the design decisions of using PME, Parquet Sharp, and the way metadata is handled have to be changed, to ensure a system supporting more asynchronous work and internally supported range requests.
These ideas have been reflected upon, and a more detailed solution is proposed within~@sec:discussion.
