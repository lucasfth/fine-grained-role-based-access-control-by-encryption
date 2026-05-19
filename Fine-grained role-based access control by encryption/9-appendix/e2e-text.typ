
#figure(
  kind: "listing",
  supplement: "Listing",
  scope: "parent",
  placement: bottom,
  {
  set text(size: 8.7pt)
  block(
    height: 40%,
    align(left,
    ```bash
------------------------------------------------------------------------------------------
  PUT  cache=n/a
──────────────────────────────────────────────────────────────────────────────────────────
  config                        metric      tiny     small    medium     large    xlarge
------------------------------------------------------------------------------------------
  s3-direct                     mean         27ms       69ms      575ms     2031ms     4093ms
                                stddev       11ms       24ms      112ms       39ms      114ms
                                p50          24ms       60ms      535ms     2046ms     4049ms
                                p95          57ms      140ms      846ms     2076ms     4317ms
                                n             10        10        10        10        10

  osws-encrypt-cache            mean       2208ms     2024ms     5024ms    14.2s     26.5s 
                                stddev      660ms       94ms      161ms      354ms      466ms
                                p50        1994ms     2034ms     5046ms    14.3s     26.5s 
                                p95        4168ms     2236ms     5234ms    14.7s     27.2s 
                                n             10        10        10        10        10

  osws-encrypt-no-file-cache    mean       2150ms     2090ms     5228ms    14.4s     26.1s 
                                stddev      584ms       81ms      139ms      353ms      557ms
                                p50        1965ms     2081ms     5236ms    14.2s     26.2s 
                                p95        3884ms     2222ms     5495ms    15.2s     27.2s 
                                n             10        10        10        10        10

  osws-encrypt-no-dek-cache     mean       2558ms     2327ms     5152ms    14.2s     25.3s 
                                stddev      567ms      264ms      207ms      197ms      772ms
                                p50        2383ms     2263ms     5054ms    14.2s     25.4s 
                                p95        4246ms     2845ms     5554ms    14.6s     26.7s 
                                n             10        10        10        10        10

  osws-no-encrypt               mean        172ms      153ms     1940ms     7456ms    14.4s 
                                stddev      339ms        9ms      104ms      291ms      244ms
                                p50          48ms      151ms     1928ms     7476ms    14.4s 
                                p95        1186ms      172ms     2165ms     7868ms    14.9s 
                                n             10        10        10        10        10


------------------------------------------------------------------------------------------
    ```)
  )},
  caption: [Textual representation of E2E Latency Benchmark results for PUT],
)<lst:micro>



#pagebreak()

#figure(
  kind: "listing",
  supplement: "Listing",
  scope: "parent",
  placement: bottom,
  {
  set text(size: 8.7pt)
  block(
    height: 40%,
    align(left,
    ```bash
  GET  cache=cold
──────────────────────────────────────────────────────────────────────────────────────────
  config                        metric      tiny     small    medium     large    xlarge
------------------------------------------------------------------------------------------
  osws-encrypt-cache            mean       3592ms     3708ms     6018ms    13.1s     29.4s 
                                stddev      193ms       94ms      131ms      391ms    11.0s 
                                p50        3558ms     3703ms     6024ms    13.2s     22.6s 
                                p95        3997ms     3893ms     6239ms    13.8s     46.9s 
                                n             10        10        10        10        10

  osws-encrypt-no-file-cache    mean       3662ms     3819ms     6436ms    13.6s     29.8s 
                                stddev      116ms      160ms      283ms      248ms    11.3s 
                                p50        3648ms     3819ms     6362ms    13.6s     22.7s 
                                p95        3863ms     4166ms     7007ms    14.1s     47.2s 
                                n             10        10        10        10        10

  osws-encrypt-no-dek-cache     mean      20.1s     16.2s     79.6s    600.6s    600.7s 
                                stddev      797ms      811ms     3156ms      369ms      387ms
                                p50       20.1s     15.9s     79.0s    600.5s    600.9s 
                                p95       21.8s     18.3s     85.6s    601.2s    601.1s 
                                n             10        10        10        10        10

  osws-no-encrypt               mean         45ms      151ms     1303ms     5017ms    10.5s 
                                stddev       17ms       17ms       50ms      107ms      491ms
                                p50          38ms      153ms     1300ms     5016ms    10.2s 
                                p95          92ms      177ms     1390ms     5220ms    11.6s 
                                n             10        10        10        10        10


------------------------------------------------------------------------------------------
  GET  cache=warm
──────────────────────────────────────────────────────────────────────────────────────────
  config                        metric      tiny     small    medium     large    xlarge
------------------------------------------------------------------------------------------
  s3-direct                     mean         12ms       33ms      477ms     1884ms     3715ms
                                stddev        2ms        3ms       44ms      104ms      162ms
                                p50          11ms       33ms      490ms     1915ms     3737ms
                                p95          16ms       41ms      555ms     2015ms     3987ms
                                n             10        10        10        10        10

  osws-encrypt-cache            mean         30ms       82ms     1600ms     6040ms    65.6s 
                                stddev        3ms        6ms      101ms      248ms     5962ms
                                p50          29ms       82ms     1617ms     6097ms    62.9s 
                                p95          37ms       92ms     1769ms     6362ms    75.0s 
                                n             10        10        10        10        10

  osws-encrypt-no-file-cache    mean         35ms      130ms     2298ms     9090ms    82.2s 
                                stddev        3ms        9ms       57ms      274ms     2451ms
                                p50          34ms      129ms     2282ms     9025ms    81.9s 
                                p95          42ms      151ms     2419ms     9610ms    87.8s 
                                n             10        10        10        10        10

  osws-encrypt-no-dek-cache     mean      16.0s     15.4s     78.1s    508.5s    600.4s 
                                stddev     2087ms      531ms     4794ms   140.2s       291ms
                                p50       14.6s     15.4s     76.5s    600.3s    600.4s 
                                p95       20.3s     16.3s     91.6s    600.8s    601.0s 
                                n             10        10        10        10        10

  osws-no-encrypt               mean         38ms      138ms     1303ms     5214ms     9953ms
                                stddev        5ms       16ms       43ms      297ms      434ms
                                p50          36ms      133ms     1302ms     5103ms    10.0s 
                                p95          51ms      167ms     1378ms     5742ms    10.6s 
                                n             10        10        10        10        10

══════════════════════════════════════════════════════════════════════════════════════════

    ```
    )
  )},
  caption: [Textual representation of E2E Latency Benchmark results for GET with warm and cold cache],
)<lst:micro>