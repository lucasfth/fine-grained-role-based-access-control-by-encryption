#import "cmds.typ": update, martinFeedback, todo

= Introduction

// Situation (Context) - Describe the problem and motivate its importance
Today, when you want to enforce access control in a data lake, you have two options.
_Option 1:_ Select a "fully managed all-in-one cloud platform" that integrates with data lakes and provides fine-grained access control (FGAC).
_Option 2:_ Use a service which governs access to the data lake, but limit access control to the file level.
So either you choose _Option 2_ and limit who the data can be shared with, based on whether they should only be able to access part of the data, or choose _Option 1_ and limit the query engines that clients can use.

// Complication (Gap) - Explain why the problem hasn’t been fully solved yet
Object Stores, such as Amazon S3, which can be used as data lakes, do not understand a granularity finer than file level.
This limitation prevents external access control services from governing access to a finer granularity, such as column-based.
If, instead, the mechanism for access control was moved within the data lake itself, by leveraging column-based encryption in Parquet files, this could enable fine-grained access control.
In the research project "Reviewing options for fine-grained Role-Based Access Control in Data Lakes", Trøstrup~and~Hanson~@own-paper, a solution called Object Store Wrapper Service (OSWS) was proposed.

// Proposal (Innovation) - Propose a new solution that solves (part of) the problem
The idea of OSWS is to encrypt the Parquet files stored inside the data lake using Parquet Modular Encryption (PME), which supports encrypting each column.
The keys will be stored in a key vault and in their wrapped format within the Parquet files, and will be mapped to roles, to limit which roles have access to specific columns.
OSWS will expose an S3-compatible API, which will both handle decrypting and encrypting Parquet files for the clients, whilst ensuring they only have access to reading their authorized columns.

// Contribution
In this thesis, a proof-of-concept (PoC) of OSWS will be created to prove that a system supporting external query engines, such as DuckDB, without modifications, can use OSWS; however, it was quickly realized interoperability with the "fully managed all-in-one cloud platforms" depends on the providers allowing custom S3 endpoints.
After developing the PoC and coupling a query engine to it, experiments will be conducted to evaluate the performance and functionality, compared to a plain S3-compatible Object Store.
Metrics include end-to-end read and write latency in relation to the size of the Parquet file, introduced by OSWS.
The data sizes will be based on real-world datasets.

== Research Questions

Is it possible to create a wrapper service that ensures access control on column-level using role-based-access-control (RBAC) and has interoperability with existing query engines and "fully managed all-in-one cloud platforms" without modifying them?

== Objectives
<sec:into:objectives>

This research paper will have the following objectives:

#let objectives = [
+ Create a PoC of OSWS using an underlying S3-compatible Object Store
+ Ensure OSWS enforces access control using RBAC and encryption
+ Make it compatible with "fully managed all-in-one cloud platforms"
+ Make it compatible with "external query engines"
+ Benchmark OSWS to measure the latency it adds.
+ Reflect on design decisions and which alternatives would have been better
]
#objectives
