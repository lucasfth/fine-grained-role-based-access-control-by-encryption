#import "cmds.typ": todo, martinFeedback, delete, new
= Related Work

== Reviewing options for fine-grained Role-Based Access Control in Data Lakes
<sec:rel:our>

This thesis is a continuation of the research paper titled "Reviewing options for fine-grained Role-Based Access Control in Data Lakes", Trøstrup~and~Hanson~@own-paper.

This showed that there is a gap within the data lake field regarding access control.
One option is to use "fully managed all-in-one cloud platforms", such as Databricks Unity Catalog or Snowflake, to provide granular control of what clients can see, with the platform's own built-in query engine.
The other option is to use solutions using vended credentials, such as Lakekeeper or Apache Polaris; essentially, providing temporary credentials to clients, who use whatever external query engine they want to use, but in exchange, only file-level granularity can be controlled.

Based on this, OSWS was proposed to be able to provide both columnar access control and let clients use whatever external query engine they wanted to use.

This was the foundational work to reflect on how OSWS could theoretically work.

After beginning to implement OSWS, discoveries revealed that it did not work as initially planned, and as described in the research paper.

The biggest change from the research paper is that OSWS does not support external query engines decrypting locally, but has to get the decrypted Parquet through OSWS.

As also mentioned later, "fully managed all-in-one cloud platforms", such as Snowflake @snowflake-sigmod or Databricks Unity Catalog @unity-catalog, are not guaranteed to be supported as they would have to whitelist a URL on which OSWS runs, and have thus not been able to be tested.
Lakehouse tools like DuckLake are not supported either because they cache metadata, and the Parquet file is modified in OSWS, which will also be discussed later.

Though this is an issue that could be addressed in the future, it will require OSWS to adopt a different system design than the one it currently has.

== Membrane: A Cryptographic Access Control System for  Data Lakes 

Membrane, referenced in Trøstrup~and~Hanson @own-paper, is a proposal by Kumar~et.~al.~@kumaretal2025membraneAC to ensure both FGAC at the cell level, and encryption-at-rest in data lakes using a custom format, thus resembling what OSWS attempts to achieve.
Besides making the original client responsible for handling the original encryption keys to provide access to others, it also forces the query engine to download the whole table to decrypt it with the provided view on its machine.
The advantage of this is that once the query engine has the data, given the view, they only have to make computations on the relevant data.
This differs from OSWS, where it actually runs computations on all data, but instead only gives the query engine the finalized data.
For Membrane, the overhead of the querying time stems from the size of the view, whereas for OSWS it stems from the size of the Parquet file.
Membrane also has finer-granularity access-control than OSWS, cell-level vs column level, but this comes at the cost of using a proprietary format.

== One Stone, Three Birds: Finer-Grained Encryption with Apache Parquet @ Large Scale

While Membrane offers cell-level granularity at the expense of a custom format, Shang~et.~al.~@uberpaper proposes a system more like OSWS, in that it enforces access control in the storage layer.
In their paper, they present a system for fine-grained encryption of Parquet files at Uber's scale, solving encryption-at-rest and access control as a combined problem, similar to OSWS.
Their approach uses column-specific encryption keys stored in KMS, with readers and writers performing cryptographic operations directly through a Parquet library extension.

The key difference is where the cryptographic operations occur.
The Uber system requires extending the Parquet reader/writer libraries, which internally use PME, used by the external query engines, making it intrusive to adopt.
OSWS performs all cryptographic operations in the Encryption Gateway, exposing a standard S3 API so that unmodified query engines can access data without library changes.
The trade-off is that OSWS introduces a network hop and full-file processing overhead, while Uber's approach avoids both but requires per-engine integration.
