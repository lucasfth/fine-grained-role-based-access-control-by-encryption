#figure(
  caption: [S3-Compatible endpoints provided by OSWS],
  table(
    columns: 3,
    align: left + horizon,
    [*Method*], [*Path*], [*Description*],
    [Get],
      [`/s3/{bucket}/{*key}`],
      [Retrieve an object (with decryption and column filtering for Parquet)],
    [Put],
      [`/s3/{bucket}/{*key}`],
      [Store an object (with encryption for Parquet)],
    [Head],
      [`/s3/{bucket}/{key}`],
      [Retrieve object metadata],
    [Get],
      [`/s3/{bucket}`],
      [List objects in a bucket],
    [Get],
      [`/s3/`],
      [List buckets]
  ),
)<tab:s3-compatible-endpoints>
