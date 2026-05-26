#counter(heading).update(0)
#set heading(numbering: "1.a", supplement: [Appendix])
= Appendix

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
