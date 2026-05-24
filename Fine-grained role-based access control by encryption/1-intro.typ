#import "cmds.typ": update, martinFeedback, todo

= Introduction

// Situation (Context) - Describe the problem and motivate its importance
Today, when you want to use a data lake, you have two options.
_Option 1:_ Select a "fully managed all-in-one cloud platform" that integrates with data lakes and provides fine-grained access control.
_Option 2:_ Provide the external query engines the ability to interact with the data lake, but lose the ability for fine-grained access control.
So either you choose _Option 2_ and limit who the data can be shared with, based on whether they should only be able to access part of the data, or choose _Option 1_ and limit the query engines the data scientists want to use.

// Complication (Gap) - Explain why the problem hasn’t been fully solved yet
The Object Stores, such as Amazon S3, being the data lakes, do not understand a granularity finer than file level.
This limitation prevents external access control services from governing access to a finer granularity, such as column-based.
If, instead, the mechanism for access control was moved within the data lake itself, this could enable fine-grained access control.
In the research project "Reviewing options for fine-grained Role-Based Access Control in Data Lakes", Trøstrup~and~Lucas@own-paper, the solution called "Object Store Wrapper Service" (OSWS) was proposed.

// Proposal (Innovation) - Propose a new solution that solves (part of) the problem
The idea of OSWS is to encrypt the Parquet files stored inside the data lake using Parquet Modular Encryption (PME), which supports encrypting each column.
The keys will be stored in a key vault and in wrapped format within the Parquet files, and will be mapped to roles, to limit which roles have access to specific columns.
OSWS will expose an S3-compatible API, which can then decrypt the data for the "fully managed all-in-one cloud platforms" and the external query engines when getting normal S3 requests.
Thus, regardless of where to read the data from, it will have been ensured that they can only see what they are supposed to.

// Contribution
In this thesis, a PoC of OSWS will be created to prove that a system supporting third-party query engines, such as DuckDB, without modifications, can use OSWS, though, as quickly realized, interoperability with the "fully managed all-in-one cloud platforms" is partly a job that the respective companies have to allow.
After developing the PoC and coupling a query engine to it, experiments will be conducted to evaluate the performance and #todo[security of the system], compared to available solutions.
Metrics include end-to-end read and write latency, as well as the cryptographic overhead, in relation to the size of the Parquet file, introduced by the OSWS.
Experiments will use data sizes representative of realistic data sizes.

== Research Questions

Is it possible to create a wrapper service that ensures access control on column-level using RBAC and has interoperability with existing query engines and "fully managed all-in-one cloud platforms" without modifying them?

== Objectives
<sec:into:objectives>

This research paper will have the following objectives:

+ Create OSWS PoC using an underlying S3-compatible Object Store
+ Ensure OSWS enforces access control using RBAC outward using encryption
+ Make it compatible with "fully managed all-in-one cloud platforms"
+ Make it compatible with query engines
+ Benchmark OSWS to measure the latency it adds.
+ Reflect on design decisions and which alternatives would have been better
