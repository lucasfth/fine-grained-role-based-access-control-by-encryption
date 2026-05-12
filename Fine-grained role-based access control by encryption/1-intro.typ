#import "cmds.typ": update

// #quote(block: true, attribution: [@bill-gates])[Power comes not from knowledge kept but from knowledge shared. A company’s values and reward system should reflect that idea.]

= Introduction

// Situation (Context) - Describe the problem and motivate its importance
Today, when you want to use a data lake, you have two options.
Option 1: Select a "fully managed all-in-one cloud platform"#footnote[See~@sec:all-in-one] that integrates with data lakes and provides fine-grained access control.
Option 2: Provide the external query engines the ability to interact with the data lake, but lose the ability for fine-grained access control.
This limits who the data can be shared with, based on whether they should only be able to access part of the data, or if they have their own data analysis tool they wish to use.

// Complication (Gap) - Explain why the problem hasn’t been fully solved yet
The Object Stores, such as Amazon S3, being the data lakes, do not understand a granularity finer than file level.
This limitation prevents external access control services from governing access to a finer granularity, such as column-based.
If, instead, the mechanism for access control was moved within the data lake itself, this could enable fine-grained access control.
In the paper "Reviewing options for fine-grained Role-Based Access Control in Data Lakes"@own-paper, the solution called OSWS#footnote[See~@sec:osws] was proposed.

// Proposal (Innovation) - Propose a new solution that solves (part of) the problem
The idea of OSWS is to encrypt the files within the data lake using Parquet Modular Encryption, which supports encrypting each column.
The keys will be stored in a key vault and in wrapped format within the Parquet files, and will be mapped to roles, to limit which roles have access to specific columns.
OSWS will expose an S3-compatible API, which can then decrypt the data for the "fully managed all-in-one cloud platforms" and the external query engines when getting normal S3 requests.
Thus, regardless of where to read the data from, it will have been ensured that they can only see what they are supposed to.

// Contribution
In this thesis, an MVP of OSWS will be created to prove that a system supporting external query engines, without modifications, can use OSWS, though, as quickly realized, interoperability with the "fully managed all-in-one cloud platforms" is partly a job that the respective companies have to allow#footnote[See @sec:discussion].
After developing the MVP and coupling a query engine to it, experiments will be conducted to evaluate the performance and  security of the system, compared to available solutions.
Metrics include end-to-end read and write latency, as well as the cryptographic overhead introduced by the OSWS.
Experiments will use data sizes representative of realistic workloads, tending towards the lower bounds.

== Research Questions

Is it possible to create a wrapper service that ensures access control on column-level using RBAC and has interoperability with existing query engines and "fully managed all-in-one cloud platforms" without modifying them?

== Objectives

This research paper will have the following objectives:

+ Create OSWS MVP using an underlying S3-compatible Object Store
+ Ensure OSWS enforces access control using RBAC outward using encryption
+ Make it compatible with "fully managed all-in-one cloud platforms"
+ Make it compatible with query engines
+ Benchmark OSWS to measure the latency it adds.
+ Reflect on design decisions and which alternatives would have been better
