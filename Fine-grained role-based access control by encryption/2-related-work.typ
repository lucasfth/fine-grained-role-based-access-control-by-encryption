#import "cmds.typ": todo, martinFeedback
= Related Work

== Reviewing options for fine-grained Role-Based Access Control in Data Lakes

This thesis is a continuation of the research paper titled "Reviewing options for fine-grained Role-Based Access Control in Data Lakes"@own-paper. 

This was the foundational work to reflect on how OSWS would theoretically work.
After implementing the OSWS, discoveries revealed that it did not work as initially planned and as described in the research paper.

The biggest change from the research paper is that OSWS does not support third-party query engines being able to decrypt locally, but has to get the decrypted Parquet through OSWS.
As also mentioned later, "fully managed all-in-one cloud platforms", such as Snowflake or Databricks Unity Catalog, are not guaranteed to be supported as they would have to whitelist a URL on which OSWS runs, and have thus not been able to be tested; it is not certain that, given a whitelist, it would work.
Lastly, data lake-specific systems, such as DuckLake, are not supported either, see more in~@sec:discussion, due to modified Parquet files.
Though this is an issue that could be removed in the future, it will require OSWS to add another logical layer that bridges the two design choices.

== Membrane: A Cryptographic Access Control System for  Data Lakes 

Membrane, referenced in Trøstrup~and~Lucas@own-paper, is a proposal to ensure FGAC at the cell level and encryption-at-rest in data lakes using a custom format, Kumar~et~al.@kumaretal2025membraneAC, thus resembling what OSWS sets out to do.
Besides making the original client responsible for handling the original encryption keys to provide access to others, it also forces the query engine to download the whole file to decrypt it with the provided view on its machine.
The advantage of this is that once the query engine has the data, given the view, they only have to make computations on the relevant data.
This differs from OSWS, where it actually runs computations on all data, but instead only gives the query engine the finalized data.
The computation volume for Membrane is therefore correlated to the size of the view size, whereas for OSWS, it is related to the file size, but OSWS supports existing query engines which can interact with S3.

#todo[Missing comparison of if there are diff between research project OSWS and current OSWS against Membrane]

== One Stone, Three Birds: Finer-Grained Encryption with Apache Parquet @ Large Scale

Shang~et~al.@uberpaper present a system for fine-grained encryption of Parquet files at Uber's scale, solving encryption-at-rest and access control as a combined problem—similar to OSWS.
Their approach uses column-specific encryption keys stored in a KMS, where readers and writers perform cryptographic operations directly through a Parquet library extension.

The key difference is where the cryptographic operations occur.
The Uber system requires extending the Parquet reader/writer libraries used by query engines, making it intrusive to adopt.
OSWS performs all cryptographic operations in the Encryption Gateway, exposing a standard S3 API so that unmodified query engines can access data without library changes.
The trade-off is that OSWS introduces a network hop and full-file processing overhead, while Uber's approach avoids both but requires per-engine integration.

#todo[Probably have to refer back to this and say how we differ and something about them only thus supporting modified query engines]