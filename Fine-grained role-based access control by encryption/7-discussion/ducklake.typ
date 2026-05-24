
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

  Client->>OSWS: PUT plaintext Parquet, 1000 bytes
  OSWS->>S3: PUT encrypted Parquet (2000 bytes)
  S3-->>OSWS: 200 OK
  OSWS-->>Client: 200 OK

  == Read Phase — Client fetches same Parquet file assuming length is 1000 bytes ==

  Client->>OSWS: GET Parquet file — Range: bytes=500-1000 
  OSWS->>S3: GET Parquet file
  S3-->>OSWS: 200 OK, encrypted Parquet (2000 bytes)
  OSWS-->>Client: 206 Partial Content — Content-Range: bytes 500-1000/2000

  == Error state — Client assumed this was footer ==
  Client->>Client: "No magic bytes found at end of file" Read fails
```)
)<fig:ducklake-case>
