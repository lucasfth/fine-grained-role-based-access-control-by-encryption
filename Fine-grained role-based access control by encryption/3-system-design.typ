= System Design

== Architecture Overview

OSWS will be set up to be a wrapper for S3 and thereby provide S3-compatible API endpoints for clients.
The purpose of OSWS is to provide column-level access controls to S3, whilst not modifying the S3 API.
This will ensure that most S3-compatible query engines are able to use OSWS without modifications and that they will only be able to read what they are supposed to.

The system is built on ASP.NET Core 10, and uses: PME, minimal API, postgreSQL for RBAC, Azure Key Vault for key management, Cloudflare R2 as object store (R2 is S3 compatible).

#figure(
  placement: top,
  scope: "parent",
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
)

== Layered Architecture

The repo is structured into six main dotnet projects and one frontend project (written in React).

=== OSWS.WebAPI

WebAPI is the entry point that, from the query engine's perspective, is S3.
It is responsible for hosting the ASP.NET Core minimal API and registers all the services.

=== OSWS.ParquetSolver

ParquetSolver handles the cryptographic operations for the Parquet files.

=== OSWS.KeyManager

...