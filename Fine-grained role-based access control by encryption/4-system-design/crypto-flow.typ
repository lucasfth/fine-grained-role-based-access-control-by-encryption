== Encryption Flow

#let encryptionFlow = [
  #figure(
    placement: top,
    scope: "parent",
    kind: "figure",
    supplement: "Figure",
    caption: [Encryption flow of OSWS],
    ```pintora
sequenceDiagram
  participant Client as "Client"
  participant Gateway as "Encryption Gateway"
  participant Solver as "Parquet Solver"
  participant KV as "KV"
  participant S3 as "Object Store"

  Client->>Gateway: PUT plaintext Parquet
  Gateway->>Gateway: Auth (SigV4), resolve role

  Gateway->>Solver: Encrypt file for role

  Solver->>KV: Create file KEK
  KV-->>Solver: KEK ID

  Solver->>Solver: Generate DEKs

  Solver->>KV: Wrap DEKs

  KV-->>Solver: Wrapped DEKs

  Solver->>Solver: Rewrite file with PME

  Solver-->>Gateway: Encrypted stream + key metadata

  Gateway->>Gateway: Persist RBAC metadata

  Gateway->>S3: PUT encrypted Parquet

  S3-->>Gateway: 200 OK

  Gateway-->>Client: 200 OK
    ```
  )<fig:encryptionflow>
]

== Decryption Flow

#let decryptionFlow = [
  #figure(
    placement: top,
    scope: "parent",
    kind: "figure",
    supplement: "Figure",
    caption: [Decryption flow of OSWS],
    ```pintora
sequenceDiagram
  participant Client as "Client"
  participant Gateway as "Encryption Gateway"
  participant Solver as "Parquet Solver"
  participant S3 as "Object Store"
  participant KV as "KV"

  Client->>Gateway: GET Parquet
  Gateway->>Gateway: Auth (SigV4), resolve user\n+ allowed columns (RBAC)

  Gateway->>S3: Fetch encrypted file (or disk cache)
  S3-->>Gateway: Encrypted Parquet

  Gateway->>Solver: Decrypt file (allowed columns)

  Solver->>KV: Unwrap DEKs (cached)
  KV-->>Solver: Unwrapped DEKs

  Solver->>Solver: Decrypt permitted, dummy for unauthorized

  Solver-->>Gateway: Decrypted Parquet

  Gateway->>Gateway: Apply range slicing (if any)

  Gateway-->>Client: 200 OK (or 206 Partial)
    ```
  )<fig:decryptionflow>
]
