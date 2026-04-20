#import "cmds.typ": update
= Introduction

#update[
// Situation (Context) - Describe the problem and motivate its importance
Today, when you want to use a data lake system, you have two options.
Option 1: Select a fully managed platform that integrates with the data lake and provides fine-grained access control.
Option 2: Provide external query engines the ability to interact with the data lake, but lose the ability for fine-grained access control.
This is one of the main reasons that data lakes might be limited in terms of how they can be interacted with and what trade-offs each approach offers.

// Complication (Gap) - Explain why the problem hasn’t been fully solved yet
The object store services, e.g. Amazon S3, which contain the data lake, have no knowledge of the data within files.
This limitation prevents external access control services from governing access to a finer granularity, such as column-based.
If, instead, the mechanism for access control was moved within the data lake itself, this could enable fine-grained access control.
In the paper "Reviewing options for fine-grained Role-Based Access Control in Data Lakes"@own-paper, the solution called "Fine-grained access-control in data lakes by encryption" (FGRBAC by Encryption) was proposed.

// Proposal (Innovation) - Propose a new solution that solves (part of) the problem
The idea is to encrypt the files within the data lake using Parquet Modular Encryption, which supports encrypting each column /* with its own key*/.
The keys will be stored within a key management system, mapped to the roles which should have access to the column.
A wrapper implementing the S3 API can then decrypt the data for the fully managed platforms, whereas external query engines can be modified to retrieve data directly from S3 and fetch the keys from the wrapper.
This will allow the external query engine to lazily decrypt the data, thereby reducing some of the overhead that the wrapper could experience.

// Contribution
In this project, we will develop an MVP of said wrapper to ensure operability of both fully managed platforms, in our case Snowflake, interacting with data lakes, and a Spark-based query engine.
This also includes defining the standard of how the query engine should handle the decryption step of the data.
After developing the MVP and modifying the query engine, experiments will be conducted to evaluate the performance and security of the system, compared to available solutions.
Metrics include end-to-end read and write latency, as well as the cryptographic overhead introduced by the wrapper.
Experiments will use data sizes representative of realistic workloads, tending towards the lower bounds.
]