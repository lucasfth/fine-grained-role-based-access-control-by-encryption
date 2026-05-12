#import "cmds.typ": todo

= Background

Data lakes are not a new concept, but the term was first coined in 2011 by Dixon @ibm-what-datalake, and some of the terminology is a bit inconsistent.
This section will describe the terminology used within this thesis to ensure consistency.
A lot of the definitions will be taken directly from the previously written research paper, which will be referenced and quoted accordingly.

== OSWS
<sec:osws>

Object Store Wrapper Service (OSWS) is the concept of a layer on top of an Object Store and which support S3-compatible API endpoints.
It is meant to provide fine-grained role-based access control by encryption.
This should be achieved through using PME, see~@sec:pme, and will only decrypt the columns which are authorized to the client requesting a given Parquet file.
See more in~@sec:system-design.

== JIT Provisioning

Just-In-Time (JIT) Provisioning is an identity management process handling creating user accounts when they are needed.@jit-provisioning
This is needed during the initial user creation, see @sec:oidc.

== RBAC
<sec:background-rbac>

In @own-paper, Role-Based Access Control (RBAC) was defined as follows:

#quote(block: true, attribution: [@own-paper])[
  Role-based Access Control (RBAC) @ferraiolo1992rbac is an approach to access control based around assigning permissions to roles, and grouping users into these roles. Access control is then managed by controlling what roles are allowed to do what, instead of managing each user individually.
The "Core RBAC" model, as defined by Ferraiolo et. al. 2001, @ferraiolo2001proposal, consists of five basic elements: _users_, _roles_, _permissions_, _operations_ and _objects_.
A _user_ is some actor, typically a human user, but could also be an autonomous actor, who needs to be authorized for some set of actions.
A user is assigned one or more _roles_.
A role is simply some named collection of authorizations; for example, a job title.
A role is assigned one or more _permissions_, which are what give authorization to perform an _operation_ on a secured _object_.
[...]
In addition, Core RBAC also describes _sessions_.
A _session_ is a mapping of one user to a subset of the roles they are authorized for; i.e. a user "activates" one or more roles that have the necessary permissions, when they need to perform a specific operation on an object.
This allows for finer control of roles that are active in a given context, to prevent unnecessary access levels. 
Commonly, a hierarchy is introduced to allow for structuring roles which should inherit some base permissions; for example, a Doctor and Nurse role might inherit permissions from some base "Healthcare Worker" role.
This is referred to as "Hierarchical RBAC" #cite(<ferraiolo2001proposal>).
]

== OIDC

OpenID Connect (OIDC) is an identity authentication protocol based on the authorization OAuth 2.0 framework. @what-is-oidc It provides developers with a standardized, simple way to verify the identity of users trying to access web applications. It allows users to authenticate using their existing accounts previously registered with an OpenID Provider, such as Microsoft Entra ID @what-is-entra or PocketID @what-is-pocketid, which the web application can then contact to verify their identity. Thus, it eliminates the need to implement an authentication layer in the web application.

== KMS/KV
<sec:kv>

Key Management Service (KMS) and Key Vault (KV) are both services used to manage keys.@aws-kms@azure-kv
KMS is widely used within data storage, and is what AWS use to refer to their system, whereas Azure uses KV.
This paper will use the term KV, as OSWS has been set up against Azure KV but could have used KMS, see more in~@sec:osws-keymanager.
KV is a way to store cryptographic keys.
When the cryptographic keys are within the KV, they can no longer be retrieved, and thus if data has to be encrypted/decrypted, it either has to be sent to the KV or envelope encryption can be used, so the KV is responsible for unwrapping the DEK, see more in~@sec:kek:dek.

== Data Lake

In the previously written research paper, data lakes were defined as follows: 

#quote(block: true, attribution: [@own-paper])[
A "data lake" is a centralized repository of data, which could be structured, semi-structured or unstructured.@ibm-what-datalake
It differs from a traditional database in that a data lake separates compute and storage layers.
The data itself is stored in object stores like Amazon S3@amazon-s3, in file formats like CSV, Parquet#footnote[@sec:parquet defines Parquet], etc.
The compute nodes are simply any query engine, such as Apache Spark @apache-spark, that connects to the object store and uses the data. 
This could be a data scientist working on their own machine, who connects to a data lake and runs queries; or it could be a part of a managed all-in-one platform like Snowflake, see more in @sec:all-in-one.
As the object store just contains raw data, both structured and unstructured, this can make it more complicated to query, especially for large data lakes. One approach to querying is "schema on read", in which the query engine infers a schema at query time based on the files in the data lake.
This is in contrast to "schema-on-write" used in traditional relational databases, where the schema is strictly enforced when writing.
This doesn't work well for data lakes due to the nature of storing raw data in object stores. 
Typically, data lakes introduce a _catalogue_ on top of the object store that manages file schemas, metadata and snapshots, allowing for structured reads and more performant querying through techniques like partitioning, i.e. filtering unnecessary data.
This has also been referred to as a _data lakehouse_ .@Databricks2021Lakehouse
]

== Parquet
<sec:parquet>

In the previously written research paper, Parquet files were defined as follows:

#quote(block: true, attribution: [@own-paper])[
Parquet @parquet-file-format is a columnar file format supported by many data processing systems.

A Parquet file is structured using row groups, which contain columns, along with a footer which contains metadata.
The columns are structured as column chunks, which contain several _data pages_.
A data page contains a header, which describes information like the size of the page, and following that, the actual values as bytes. 
The file footer contains metadata that specifies what is stored in the file and where, that is, where a reader should look to find a specific column, or the statistics of a column (e.g. min/max).
@sec:encrypted-parquet shows a visual representation of a Parquet file that also uses encryption, which will be described later.
The left side of the figure shows row groups, columns and data pages, along with their headers.
The right side shows the footer of the file, with the file metadata containing metadata on each row group, which in turn contains metadata on the column chunks in that row group.
The arrows link information about where to read, such as offsets, to where they point the reader.
The objects that hold metadata, like statistics, and structural information, including physical offsets, such as the footer and page headers, are serialized using Apache Thrift@apache-thrift, a language-agnostic serialization framework, and referred to as "Thrift Structs".
Essentially, the object that contains the information, for example, a `PageHeader` object (on the left side of~@sec:encrypted-parquet) or a `ColumnMetaData` object (on the right side of @sec:encrypted-parquet), is serialized into bytes using Thrift, which can then later be restored to the same object.@parquet-modular-encryption-docs)
Then, to read a Parquet file, the reader de-serializes the Thrift structures to get the necessary metadata, and then reads the actual data values using the information from the metadata. 
]

== TTL

Time-to-live (TTL) is a way to define the lifetime of some item within a dataset.
When either the item's TTL expires or the dataset is full, the item closest to its TTL is removed.@ttl
In OSWS, it is a way to define how long the lifetime of the encrypted Parquet files and the unwrapped DEKs, see~@sec:kek:dek, can live in storage and memory.
When the TTL is reached, the data will be removed and has to be refetched from either S3 or the KV when needed.
OSWS defines two different TTLs as a way to follow general security guidelines, which can be read about in "NIST Special Publication 800-57 Revision 5 Recommendation for Key Management"@Barker_2016, where OSWS uses a TTL of five minutes for DEKs authorized to admins, and the rest have a TTL of 15 minutes.

== Envelope Encryption (KEK, DEK)
<sec:kek:dek>

As KV, see~@sec:kv, does not support retrieving keys, OSWS uses envelope encryption.
This means that during encryption of a column, cryptographic keys for each are generated, called a data-encryption-key (DEK), which is used to encrypt the columns.
Then, for the single Parquet file, a single key-encryption-key is generated, resulting in less data compared to if each DEK had its own separate KEK within KV.
This KEK then encrypts all the DEKs, also called wrapped DEKs, and gets stored in KV.
The wrapped DEKs are then stored in the metadata for the Parquet file together with a KEK id.\
When the columns are to be decrypted, the wrapped DEKs are sent to KV to get unwrapped, and the columns can be decrypted.@envelope-encryption

== Trust Boundary

A trust boundary is a boundary where the level of trust is checked.
So the place where information from one side of the boundary is validated, and if it is valid, it will permeate to the other side, based on the restrictions.
This can be both if users should be able to access the data on the other side or if data should be able to be stored on the other side.@Myagmar_Lee_Yurcik

== PME
<sec:pme>

Parquet Modular Encryption (PME) is a way to allow granular control of how the Parquet file data and metadata should be encrypted.
Singular columns can be encrypted, and the footer as well.
For OSWS, footer encryption is not enabled.
There are multiple reasons for this, but they are argued in #todo[ref sec].
When encryption is used, serialized Thrift structs are encrypted using the given cryptographic key, and the data pages themselves are encrypted as well.
In OSWS, it is saved as a tuple in the footer, containing a reference to the KEK in KV and the wrapped DEK.
This allows OSWS to get the DEK unwrapped to then decrypt the column #todo[ref sec].@parquet-modular-encryption-docs

== Fully managed all-in-one cloud platforms
<sec:all-in-one>

In this paper, "Fully managed all-in-one cloud platforms" will be used to define solutions such as Snowflake and Databricks.
Access control within those solutions is managed by the query engines together with the catalogue.
This means the query engine is trusted to filter out rows that are not permitted, and it then masks or removes those values, which is possible as the platforms themselves manage it.

== Vended Credentials

"Vended credentials" is a way to manage temporary access to files within S3, but the issue is that it can only gate access on the file level, based on limitations in S3.
This is the way Lakekeeper and Apache Polaris currently manage their access grants.@lakekeeper-vended@polaris-vended
