#import "../custom.typ": subfigures

#subfigures(
  [Micro benchmarks with auto-layout y-axis],
  label: <fig:micro-auto-main>,
  (
    (
      img: image("perm-hier-auto.png"), cap: [Hierarchical permission benchmark], lbl: <fig:micro-auto-hier>),
    (
      img: image("perm-service-auto.png"), cap: [Service permission benchmark], lbl: <fig:micro-auto-service>),
    (
      img: image("unwrap-auto.png"), cap: [Key unwrap benchmark], lbl:
      <fig:micro-auto-unwrap>
  ),
    (
      img: image("decryption-auto.png"), cap: [Decryption benchmark], lbl: 
      <fig:micro-auto-decryp>
    ),
  )
)
