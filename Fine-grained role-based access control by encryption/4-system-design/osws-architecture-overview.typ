
#figure(
  placement: top,
  scope: "parent",
  kind: "figure",
  supplement: "Figure",
  caption: [Architecture of OSWS showing components, external services, and communication paths\
  1 referencing looking up cached DEKs and Parquet files | 2 referencing RBAC calls | 3 referencing DEK wrap or unwrap | 4 referencing S3 API calls],
  (```pintora
componentDiagram

  package "S3 Clients" {
    [DuckDB]
    [Apache Spark]
    [Python Script]
  }

  package "Frontend" {
    [Credentials UI]
    [Admin UI]
  }

  package "OSWS" {
    [Encryption Gateway]
    package "Caching" {
      [LRU Parquet Cache]
      [TTL DEK Cache]
    }
  }

  database "PostgreSQL" {
    [RBAC & Metadata]
  }

  cloud "Key Vault" {
    [Azure Key Vault]
  }

  database "Object Store" {
    [Cloudflare R2]
    [MinIO]
    [AWS S3]
  }
[Admin UI] -- [Encryption Gateway] : OIDC/JWT
[S3 Clients] -- [Encryption Gateway] : SigV4
[Encryption Gateway] -- [Caching] : 1
[Encryption Gateway] -- [RBAC & Metadata] : 2
[Encryption Gateway] -- [Azure Key Vault] : 3
[Encryption Gateway] -- [Object Store]    : 4
  ```)
)<fig:osws-architecture-overview>
