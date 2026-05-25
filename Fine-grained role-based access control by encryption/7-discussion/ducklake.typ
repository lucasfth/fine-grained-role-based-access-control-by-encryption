
#figure(
  placement: top,
  scope: "parent",
  kind: "figure",
  supplement: "Figure",
  caption: [Sequence Diagram showing the DuckLake range request error case. File size and byte ranges are for illustrative purposes only. ],
  
  (```pintora
sequenceDiagram
  participant Client as "Client (DuckLake)"
  participant OSWS as OSWS
  participant S3 as "Storage Backend"

  == Write Phase — Client uploads a 1000 byte Parquet file ==

  Client->>OSWS: PUT plaintext Parquet (1000 bytes)
  OSWS->>OSWS: Re-write to new encrypted file (2000 bytes)
  OSWS->>S3: PUT encrypted Parquet
  S3-->>OSWS: 200 OK
  OSWS-->>Client: 200 OK

  == Read Phase — Client fetches same Parquet file assuming length is 1000 bytes ==

  Client->>OSWS: GET Parquet file — Range: bytes=500-1000 
  OSWS->>S3: GET Parquet file
  S3-->>OSWS: 200 OK, encrypted Parquet (2000 bytes)
  OSWS->>OSWS: Re-write to new decrypted file (1250 bytes)
  OSWS-->>Client: 206 Partial Content — Content-Range: bytes 500-1000/1250

  == Error state — Client assumed this was footer ==
  Client->>Client: Read fails
```)
)<fig:ducklake-case>
