#import "@preview/lilaq:0.6.0" as lq
#figure(
  placement: top,
  kind: "figure",
  supplement: "Figure",
  lq.diagram(
    width: 100%,
    xaxis: (ticks: ((1, [tiny]), (2, [small]), (3, [medium]))),
    ylabel: [Latency (ms)],
  lq.plot(
    (1.00, 2.00, 3.00),
    (3558.46, 3702.97, 6024.01),
    mark: "o",
    label: [DEK cache enabled],
  ),
  lq.plot(
    (1.00, 2.00, 3.00),
    (20093.96, 15857.88, 78966.21),
    mark: "s",
    label: [DEK cache disabled],
  ),
  ),
  caption: [DEK cache impact on cold GET latency],
)<fig:dekcachelatency>
