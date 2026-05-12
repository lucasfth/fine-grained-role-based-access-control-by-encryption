// Auto-generated microbenchmark boxplots
#import "@preview/lilaq:0.6.0" as lq
#import "@preview/subpar:0.2.2"


= Decryption

#let decryption() = figure(
  lq.diagram(
    width: 100%, height: 7.5cm,
    xlabel: "Corpus size", ylabel: "Duration (ms, log scale)",
    xaxis: (ticks: ((1, [tiny]), (2, [small]), (3, [medium]), (4, [large]), (5, [xlarge]))),
    ylim: (9.632, 17879.728),
    yscale: "log",

  lq.boxplot(
    (median: 13.370, q1: 12.770, q3: 14.180,
     whisker-low: 12.040, whisker-high: 14.610,
     mean: 13.562, outliers: (17.050,)),
    x: 1, mean: "+",
  ),
  lq.boxplot(
    (median: 64.250, q1: 62.035, q3: 70.095,
     whisker-low: 58.690, whisker-high: 75.030,
     mean: 65.667, outliers: ()),
    x: 2, mean: "+",
  ),
  lq.boxplot(
    (median: 1669.090, q1: 1652.250, q3: 1718.620,
     whisker-low: 1581.340, whisker-high: 1796.400,
     mean: 1681.803, outliers: ()),
    x: 3, mean: "+",
  ),
  lq.boxplot(
    (median: 7425.450, q1: 7204.895, q3: 7644.540,
     whisker-low: 7116.390, whisker-high: 8172.260,
     mean: 7478.837, outliers: ()),
    x: 4, mean: "+",
  ),
  lq.boxplot(
    (median: 14630.040, q1: 14445.005, q3: 14969.715,
     whisker-low: 14123.850, whisker-high: 15547.590,
     mean: 14744.849, outliers: ()),
    x: 5, mean: "+",
  ),
  ),
  caption: [Decryption boxplot distribution per parameter (logarithmic y axis)],
)

= Decryption // NOT USED

#figure(
  lq.diagram(
    width: 100%, height: 7.5cm,
    xlabel: "Corpus size", ylabel: "Duration (ms)",
    xaxis: (ticks: ((1, [tiny]), (2, [small]))),
    ylim: (7.001, 80.069),

  lq.boxplot(
    (median: 13.370, q1: 12.770, q3: 14.180,
     whisker-low: 12.040, whisker-high: 14.610,
     mean: 13.562, outliers: (17.050,)),
    x: 1, mean: "+",
  ),
  lq.boxplot(
    (median: 64.250, q1: 62.035, q3: 70.095,
     whisker-low: 58.690, whisker-high: 75.030,
     mean: 65.667, outliers: ()),
    x: 2, mean: "+",
  ),
  ),
  caption: [Decryption - box-plot distribution per parameter set (zoomed tiny/small view for detail)],
)

= KeyUnwrap

#let unwrap() = figure(
  lq.diagram(
    width: 100%, height: 7.5cm,
    xlabel: "DEK size (bits)", ylabel: "Duration (ms)",
    xaxis: (ticks: ((1, [128]), (2, [192]), (3, [256]))),
    ylim: (2764.055, 4205.425),

  lq.boxplot(
    (median: 3118.650, q1: 3059.845, q3: 3278.980,
     whisker-low: 2863.460, whisker-high: 3438.820,
     mean: 3153.800, outliers: ()),
    x: 1, mean: "+",
  ),
  lq.boxplot(
    (median: 3222.340, q1: 3102.350, q3: 3261.225,
     whisker-low: 2958.110, whisker-high: 3481.000,
     mean: 3238.229, outliers: (3591.210, 3755.110)),
    x: 2, mean: "+",
  ),
  lq.boxplot(
    (median: 3972.680, q1: 3851.605, q3: 3987.690,
     whisker-low: 3666.950, whisker-high: 4106.020,
     mean: 3919.253, outliers: ()),
    x: 3, mean: "+",
  ),
  ),
  caption: [KeyUnwrap box-plot distribution per parameter set (tiny corpus only; linear y axis)],
)

= PermissionHierarchy

#let permissionhier() = figure(
  lq.diagram(
    width: 100%, height: 7.5cm,
    xlabel: "Hierarchy depth", ylabel: "Duration (ms, log scale)",
    xaxis: (ticks: ((1, [0]), (2, [4]), (3, [16]), (4, [64]))),
    ylim: (2.768, 27.151),
    yscale: "log",

  lq.boxplot(
    (median: 4.180, q1: 3.720, q3: 4.605,
     whisker-low: 3.460, whisker-high: 5.770,
     mean: 4.265, outliers: ()),
    x: 1, mean: "+",
  ),
  lq.boxplot(
    (median: 4.370, q1: 3.895, q3: 4.820,
     whisker-low: 3.600, whisker-high: 5.240,
     mean: 4.545, outliers: (6.970,)),
    x: 2, mean: "+",
  ),
  lq.boxplot(
    (median: 6.200, q1: 5.610, q3: 6.795,
     whisker-low: 5.140, whisker-high: 7.650,
     mean: 6.829, outliers: (8.620, 14.760)),
    x: 3, mean: "+",
  ),
  lq.boxplot(
    (median: 18.760, q1: 17.630, q3: 19.285,
     whisker-low: 15.410, whisker-high: 19.790,
     mean: 18.513, outliers: (14.710, 23.610)),
    x: 4, mean: "+",
  ),
  ),
  caption: [PermissionHierarchy box-plot distribution per parameter set (logarithmic y axis)],
)

= PermissionService


#let permissionser() = figure(
  lq.diagram(
    width: 100%, height: 7.5cm,
    xlabel: "Direct role count", ylabel: "Duration (ms, log scale)",
    xaxis: (ticks: ((1, [4]), (2, [64]), (3, [256]))),
    ylim: (3.480, 32.361),
    yscale: "log",

  lq.boxplot(
    (median: 5.300, q1: 4.910, q3: 6.010,
     whisker-low: 4.350, whisker-high: 6.800,
     mean: 6.694, outliers: (24.640,)),
    x: 1, mean: "+",
  ),
  lq.boxplot(
    (median: 12.200, q1: 10.835, q3: 12.660,
     whisker-low: 9.550, whisker-high: 14.810,
     mean: 11.992, outliers: ()),
    x: 2, mean: "+",
  ),
  lq.boxplot(
    (median: 24.340, q1: 22.085, q3: 27.410,
     whisker-low: 21.200, whisker-high: 28.140,
     mean: 24.744, outliers: ()),
    x: 3, mean: "+",
  ),
  ),
  caption: [PermissionService box-plot distribution per parameter set (logarithmic y axis)],
)

#let microboxplot = subpar.grid(
  kind: "figure",
  supplement: "Figure",
  placement: top,
  scope: "parent", // either parent or column
  columns: (1fr, 1fr),
  decryption(),<fig:decryption-boxplot>,
  unwrap(),<fig:unwrap-boxplot>,
  permissionhier(),<fig:permission-hier-boxplot>,
  permissionser(),<fig:permission-service-boxplot>,
  caption: [Box-plots for micro-benchmarks. Note that the y axes are not the same and some of the plots are logarithmic],
  label: <fig:micro-boxplot>,
)
