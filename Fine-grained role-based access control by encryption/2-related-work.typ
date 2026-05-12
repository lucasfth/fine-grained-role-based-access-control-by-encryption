#import "cmds.typ": todo
= Related Work

== Reviewing options for fine-grained Role-Based Access Control in Data Lakes

This thesis is a continuation on the research paper titled "Reviewing options for fine-grained Role-Based Access Control in Data Lakes"@own-paper. 

This was the foundational work to reflect on how OSWS would theoretically work.
After starting to implement the OSWS, discoveries resulted in the OSWS not working as initially planned and described in the research paper.

The biggest change was that OSWS does not support external query engines being able to decrypt locally, but has to get the decrypted Parquet through OSWS.
As also mentioned later, "fully managed all-in-one cloud platforms", such as Snowflake or Databricks Unity Catalog, are not guaranteed to be supported as they would have to whitelist a URL on which OSWS runs, and have thus not been able to be tested; it is not certain that, given a whitelist, it would work.
Lastly, data lake-specific, such as DuckLake, are not supported either, see more in~@sec:discussion, due to modified Parquet files.
Though this is an issue which could be removed in the future, it will require OSWS to have another logical layer which bridges the two different design choices.

== Membrane: A Cryptographic Access Control System for  Data Lakes 

Membrane, referenced in @own-paper as well, is a proposal for ensuring FGAC at the cell-level and encryption-at-rest in data lakes with a custom format @kumaretal2025membraneAC, thus resembling what OSWS sets out to do.
Besides making the original client the one responsible for handling the original encryption keys, to provide access to others, it also makes the query engine have to download the whole file to then decrypt it with a provided view, on its machine.
The advantage of this is that once the query engine has the data, given the view, they only have to make computations on the relevant data.
This differs from OSWS, where it actually runs computations on all data, but instead only gives the query engine the finalized data.
The computation volume for Membrane is therefore correlated to the size of the view size, whereas for OSWS, it is related to the file size, but OSWS supports existing query engines which can interact with S3.

== Uber Paper

#todo[We should probably cite the uber paper]
