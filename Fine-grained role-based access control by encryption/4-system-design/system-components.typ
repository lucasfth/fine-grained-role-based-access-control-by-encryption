#figure(
  caption: [OSWS system components and their responsibilities],
  table(
    columns: (auto, 1fr),
    align: left + horizon,
    [*Component*], [*Responsibility*],
    [Encryption Gateway],
      [S3-compatible API host. Handles incoming S3 requests, enforces AWS Signature V4 authentication, and orchestrates encryption, decryption, and column filtering.],
    [Parquet Solver],
      [Encrypts and decrypts Parquet files using PME with Parquet Sharp.
      Generates DEKs, wraps them via the Key Manager, and masks unauthorized columns.],
    [Key Manager],
      [Manages cryptographic keys through Azure KV (or an internal provider).
      Wraps/unwraps DEKs using RSA-2048 KEKs stored in the vault.],
    [RBAC Store],
      [PostgreSQL database storing users, roles, role assignments, role inheritance, column permissions, and S3 credentials.
      Evaluated per-request to determine authorized columns.],
    [Frontend],
      [React web UI for managing S3 credentials, and, for admins, managing roles, permissions, and users. Uses OIDC authentication and provides a SQL-like query editor for RBAC operations.],
  ),
)<tab:components>
