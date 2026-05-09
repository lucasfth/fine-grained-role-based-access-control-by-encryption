#import "../custom.typ": subfigures

#subfigures(
  [Micro benchmarks with shared y-axis],
  label: <fig:micro-shared-main>,
  (
    (
      img: image("perm-hier-shared.png"), cap: [Hierarchical permission benchmark], lbl: <fig:micro-shared-hier>),
    (
      img: image("perm-service-shared.png"), cap: [Service permission benchmark], lbl: <fig:micro-shared-service>),
    (
      img: image("unwrap-shared.png"), cap: [Key unwrap benchmark], lbl:
      <fig:micro-shared-unwrap>
  ),
    (
      img: image("decryption-shared.png"), cap: [Decryption benchmark], lbl: 
      <fig:micro-shared-decryp>
    ),
  )
)
