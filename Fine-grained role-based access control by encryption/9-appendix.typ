#counter(heading).update(0)
#set heading(numbering: "1.a", supplement: [Appendix])
= Appendix

== Encrypted Parquet Footer
<app:encrypted-parquet>

#figure(
  placement: bottom,
  scope: "parent",
  caption: [
    Illustration of the Parquet file structure using an Encrypted Footer. From @parquet-modular-encryption-docs.
  ],
  image("9-appendix/PME.png", width: 100%)
)

#pagebreak()

== VM Specification
<app:vm-spec>

#include "9-appendix/vm.typ"

#pagebreak()

== Micro Benchmark Results
<app:micro>

#include "9-appendix/micro-text.typ"

#pagebreak()

== E2E Latency Benchmark Results
<app:e2e-res>

#include "9-appendix/e2e-text.typ"
