#import "cmds.typ": todo, speculation, delete, new

= Background

This section will describe the terminology used within this thesis to ensure consistency.
A lot of the definitions will be taken directly from the previously written research paper.

== OSWS
<sec:osws>

Object Store Wrapper Service (OSWS) is the concept of a layer on top of an Object Store that supports S3-compatible API endpoints.
It is meant to provide fine-grained role-based access control (FGRBAC) in data lakes by encryption at the columnar level.
Its trust model is based on that it wants to both ensure that clients can only see what they are authorized to, as well as hide the actual data from the storage layer.
This will be achieved by using Parquet Modular Encryption (PME), and will only decrypt the columns which are authorized to the client requesting a given Parquet file.

== Data Lake

#quote(block: true, attribution: [Trøstrup~and~Hanson~@own-paper])[
  A "data lake" is a centralized repository of data, which could be structured, semi-structured or unstructured.~@ibm-what-datalake
  [Respectively meaning that the data either has a predefined schema or does not have a fixed schema.~@structured-semistructured]
  It differs from a traditional database in that a data lake separates compute and storage layers.
  The data itself is stored in Object Stores like Amazon S3~@amazon-s3, in file formats like CSV, Parquet, etc.
  The compute nodes are simply any query engine, such as Apache Spark~@apache-spark, that connects to the Object Store and uses the data. 
  This could be a data scientist working on their own machine, who connects to a data lake and runs queries; or it could be a part of a managed all-in-one platform like Snowflake [...].
  As the Object Store just contains raw data, both structured and unstructured, this can make it more complicated to query, especially for large data lakes. One approach to querying is "schema on read", in which the query engine infers a schema at query time based on the files in the data lake.
  This is in contrast to "schema-on-write" used in traditional relational databases, where the schema is strictly enforced when writing.
  This doesn't work well for data lakes due to the nature of storing raw data in Object Stores. 
  Typically, data lakes introduce a _catalogue_ on top of the Object Store that manages file schemas, metadata and snapshots, allowing for structured reads and more performant querying through techniques like partitioning, i.e. filtering unnecessary data.
  This has also been referred to as a _data lakehouse_ .~@Databricks2021Lakehouse
]

== Parquet
<sec:parquet>

#quote(block: true, attribution: [Trøstrup~and~Hanson~@own-paper])[
  Parquet~@parquet-file-format is a columnar file format supported by many data processing systems.
  
  A Parquet file is structured using row groups, which contain columns, along with a footer which contains metadata.
  The columns are structured as column chunks, which contain several _data pages_.
  A data page contains a header, which describes information like the size of the page, and following that, the actual values as bytes. 
  The file footer contains metadata that specifies what is stored in the file and where, that is, where a reader should look to find a specific column, or the statistics of a column (e.g. min/max).
  [...]
  The objects that hold metadata, like statistics, and structural information, including physical offsets, such as the footer and page headers, are serialized using Apache Thrift@apache-thrift, a language-agnostic serialization framework, and referred to as "Thrift Structs".
  Essentially, the object that contains the information, for example, a `PageHeader` object [...] or a `ColumnMetaData` object [...], is serialized into bytes using Thrift, which can then later be restored to the same object.~@parquet-modular-encryption-docs)
  Then, to read a Parquet file, the reader de-serializes the Thrift structures to get the necessary metadata, and then reads the actual data values using the information from the metadata. 
]

== RBAC
<sec:background-rbac>

#quote(block: true, attribution: [Trøstrup~and~Hanson~@own-paper])[
  Role-based Access Control (RBAC) @ferraiolo1992rbac is an approach to access control based around assigning permissions to roles, and grouping users into these roles. Access control is then managed by controlling what roles are allowed to do what, instead of managing each user individually.
  The "Core RBAC" model, as defined by Ferraiolo et.~al.~@ferraiolo2001proposal, consists of five basic elements: _users_, _roles_, _permissions_, _operations_ and _objects_.
  A _user_ is some actor, typically a human user, but could also be an autonomous actor, who needs to be authorized for some set of actions.
  A user is assigned one or more _roles_.
  A role is simply some named collection of authorizations; for example, a job title.
  A role is assigned one or more _permissions_, which are what give authorization to perform an _operation_ on a secured _object_.
  [...]
  In addition, Core RBAC also describes _sessions_.
  A _session_ is a mapping of one user to a subset of the roles they are authorized for; i.e. a user "activates" one or more roles that have the necessary permissions, when they need to perform a specific operation on an object.
  This allows for finer control of roles that are active in a given context, to prevent unnecessary access levels. 
  Commonly, a hierarchy is introduced to allow for structuring roles which should inherit some base permissions; for example, a Doctor and Nurse role might inherit permissions from some base "Healthcare Worker" role.
  This is referred to as "Hierarchical RBAC"~@ferraiolo2001proposal.
]

== OIDC

OpenID Connect (OIDC) is an identity authentication protocol based on the authorization OAuth 2.0 framework.~@what-is-oidc
It provides developers with a standardized, simple way to verify the identity of users trying to access web applications.
It allows users to authenticate using their existing accounts previously registered with an OpenID Provider, such as Microsoft Entra ID~@what-is-entra or Pocket ID~@what-is-pocketid, which the web application can then contact to verify their identity.
Thus, it eliminates the need to implement an authentication layer in the web application.

== KMS/KV
<sec:kv>

Key Management Service (KMS) and Key Vault (KV) are both services used to manage keys.~@aws-kms@azure-kv
KMS, both as a term and service, is widely used within data storage, and is what AWS use to refer to their system, whereas Azure uses KV.
This paper will use the term KV, as OSWS has been set up against Azure KV, but could have used AWS KMS.
KV is a way to store cryptographic keys.
When the cryptographic keys are within the KV, they can no longer be retrieved, and thus, if data has to be encrypted/decrypted, it either has to be sent to the KV or envelope encryption can be used, so the KV is responsible for unwrapping the DEK.

== PME
<sec:pme>

Parquet Modular Encryption (PME) is a way to allow granular control of how the Parquet file data and metadata should be encrypted.
Its trust model is based on ensuring that the client-side written data is not read by the storage layer.~@parquet-modular-encryption-docs
Singular columns can be encrypted, and the footer as well.
When encryption is used, serialized Thrift structs are encrypted using the given cryptographic key, and the data pages themselves are encrypted as well.

#figure(
  image("3-background/pem_plainfooter.png"),
  scope: "parent",
  placement: top,
  caption: [
      Illustration of a Parquet file using Plaintext footer. The red key denotes what is encrypted with the column key. From~@parquet-modular-encryption-docs. 
  ],
  supplement: "Figure",
  kind: "figure"
)<fig:encrypted-parquet>

The encryption algorithms used in PME are the AES standard, and support the standard 128, 192, and 256 bit sizes.

Both AES-GCM~@nist-cgm and a combination of AES-GCM and AES-CTR~@nist-block-ciphers can be used, each with its own tradeoffs.
AES-GCM provides both data confidentiality and data integrity verification.
Because of the integrity verification, the result of encryption is both a ciphertext and an authentication tag.
When used for Parquet files, these are stored in their metadata, resulting in a modified file size.
This comes at the cost of the speed of encryption and decryption.

On the other hand, AES-CTR only provides confidentiality due to not performing integrity validation, but it is faster, and adds no additional length to the encrypted Parquet file.
However, PME does not support a pure AES-CTR mode.
Instead, an `AES_GCM_CTR_V1` mode is available, where the metadata is encrypted with AES-GCM and the rest with AES-CTR, still resulting in a changed Parquet file size.~@parquet-modular-encryption-docs

In short, AES-GCM provides confidentiality as well as integrity by also signing the ciphertext, and AES-CTR instead focuses on making the encrypted data into a stream cipher, but has no integrity verification due to not signing the ciphertext. 

=== Encryption in Parquet

In PME, column encryption is always enabled, but it provides two options for footer encryption: an encrypted or plaintext footer.~@fig:encrypted-parquet shows a Parquet file with plaintext footer enabled.
In plaintext footer mode, a `ColumnCryptoMetaData` struct is added to each column chunk, which contains the necessary metadata to decrypt the column, such as key ID and algorithm.
This is shown on the right side of~@fig:encrypted-parquet.
Notably, each column's statistics are moved to an encrypted `ColumnMetaData` struct, also shown on the right side of~@fig:encrypted-parquet.
This ensures that no information about the values can be gained without decrypting the columns. Non-sensitive information, like the offsets and other metadata, is stored as-is without encryption.

== Envelope Encryption (KEK, DEK)
<sec:kek:dek>

KV does not support retrieving keys, and as a result, OSWS uses envelope encryption.
This means that during encryption of a column, cryptographic keys for each are generated, called a data-encryption-key (DEK), which is used to encrypt the columns.
Then a single key-encryption-key (KEK) is generated for the whole Parquet file, resulting in less data compared to if each DEK had its own separate KEK within KV.
This KEK then encrypts all the DEKs, also called wrapped DEKs, and gets stored in KV.
The wrapped DEKs are then stored in the metadata for the Parquet file together with a KEK ID.
When the columns are to be decrypted, the wrapped DEKs are sent to KV to be unwrapped, and the columns can be decrypted.~@envelope-encryption

== TTL

Time-to-live (TTL) is a way to define the lifetime of some item within a dataset.
// When either the item's TTL expires or the dataset is full, the item closest to its TTL is removed.@ttl
When either the item's TTL is reached or the dataset is full, the item will be evicted.~@ttl
In OSWS, TTL defines the lifetime of unwrapped DEKs in the cache.
When the TTL is reached, the data will be removed and has to be re-unwrapped from the KV when needed again.
In a NIST paper~@Barker_2020, it is recommended to use two different TTLs, one for admin and one for the rest.
This was not fully implemented, and currently defaults to 15 minutes if no configuration changes are made.

== Fully managed all-in-one cloud platforms
<sec:all-in-one>

In this paper, "fully managed all-in-one cloud platforms" will be used to define solutions such as Snowflake and Databricks Unity Catalog.
Access control within those solutions is managed by the query engines together with the catalogue.
This means the query engine is trusted to filter out rows that are not permitted, and it then masks or removes those values, which is possible as the platforms themselves manage it.

== External Query Engines

"External query engines" will be used to refer to query engines that operate separately from the data lake.
This is one of the key features of data lakes; the compute and data layers can be separated.
Compared to a "fully managed all-in-one cloud platform", the query engine is not managed by a platform and can be any with the ability to fetch Parquet files from an S3-compatible API and perform operations on these.
This means the query engine cannot be trusted to filter out unauthorized data, as with "fully managed all-in-one cloud platforms".

Examples of these tools include Apache Spark~@apache-spark, and DuckDB~@duckdb-s3.
Lakehouse solutions such as DuckLake~@ducklake also exist. However, DuckLake is not just a basic query engine.
Besides bringing a query engine, it also provides a catalogue and other features, such as time-travelling.
The catalogue is the main difference, providing a way to store metadata about the files, including their size, location, etc, and makes use of "schema on write"; it stores the schema of the file when it writes it.

DuckLake will be included in the definition of "external query engine" as the use in the context of OSWS is the same.
The important distinction between a query engine like DuckDB and a DuckLake-like system is that DuckDB infers the schema when it reads, while DuckLake stores it on write, and thus does not need to infer it later.
This has a major impact on how they interact with OSWS and will be addressed later.

== Amazon Signature V4

When clients communicate with Amazon S3 or S3-compatible API's like Cloudflare R2, an authentication scheme known as AWS Signature V4~@aws_signiture_version_4 is used.
A pair of credentials known as the _client ID_ and _client secret_ is generated by the service, and both parties, client and service, store the information.
When requests are made, the request is signed using the _client secret_ and the _client ID_ is appended as well.
The service can find the credentials through the ID and re-signs the request.
The request is authenticated if the signatures match.

== JIT Provisioning

Just-In-Time (JIT) Provisioning is an identity management process handling creating user accounts when they are needed.~@jit-provisioning
This is needed during the initial user creation.
