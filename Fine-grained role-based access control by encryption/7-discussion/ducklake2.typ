#import "@preview/pintorita:0.1.4": render

#show raw.where(lang: "pintora"): it => render(it.text)

```pintora
sequenceDiagram
  participant Client as "Client (DuckDB + DuckLake)"
  participant OSWS as OSWS
  participant S3 as "Storage Backend"

  == Write phase  client uploads a Parquet file ==

  Client->>OSWS: PUT plaintext Parquet (n bytes)
  OSWS->>OSWS: Re-write file with PME encryption
  OSWS->>S3: PUT encrypted Parquet (n' bytes, n' != n)
  S3-->>OSWS: 200 OK
  OSWS-->>Client: 200 OK

  == DuckLake catalogs file_size_bytes = n footer_size = j ==

  == Read phase client fetches footer using cached size ==

  Client->>OSWS: GET Parquet file Range: bytes=(n-j-8)-(n-1)
  OSWS->>S3: GET Parquet file
  S3-->>OSWS: 200 OK, encrypted Parquet (n' bytes)
  OSWS->>OSWS: Decrypt, decode values, re-serialise to plaintext\nResult is n'' bytes, n'' != n
  OSWS-->>Client: 206 Partial Content\nContent-Range: bytes (n-j-8)-(n-1)/n''

  Client->>Client: Expects PAR1 magic at end of range.
```
