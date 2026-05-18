
#figure(
  placement: top,
  scope: "parent",
  kind: "figure",
  supplement: "Figure",
  caption: [Architecture of OSWS showing components, external services, and communication paths],
  (```pintora
componentDiagram

  package "S3 Clients" {
    [DuckDB]
    [Apache Spark]
    [Python Script]
  }

  package "RBAC Frontend" {
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
[Encryption Gateway] -- [Caching]
[Encryption Gateway] -- [RBAC & Metadata] : RBAC
[Encryption Gateway] -- [Azure Key Vault] : DEK wrap/unwrap
[Encryption Gateway] -- [Object Store]    : S3 API
  ```)
)<fig:osws-architecture-overview>
