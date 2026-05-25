#import "@preview/lilaq:0.6.0" as lq
#figure(
  placement: top,
  kind: "figure",
  supplement: "Figure",
  lq.diagram(
    width: 100%,
    xaxis: (ticks: ((1, [tiny]), (2, [small]), (3, [medium]), (4, [large]), (5, [x-large]))),
    yaxis: (ticks: ((4, [4]),(20, [20]), (40, [40]), (80, [80]), (600, [600 ]))),
    ylabel: [Latency (seconds, log scale)],
    legend: (position: left + top),
    yscale: "log",
    lq.plot(
      (1.00, 2.00, 3.00, 4.00, 5.00),
      (3.55846, 3.70297, 6.02401, 13.2, 22.6),
      mark: "o",
      label: [DEK cache enabled],
    ),
    lq.plot(
      (1.00, 2.00, 3.00, 4.00, 5.00),
      (20.09396, 15.85788, 78.96621, 600, 600.9),
      mark: "s",
      label: [DEK cache disabled],
    ),
  ),
  caption: [DEK cache impact on median cold GET latency. (logarithmic scale $y$ axis)],
)<fig:dekcachelatency>
