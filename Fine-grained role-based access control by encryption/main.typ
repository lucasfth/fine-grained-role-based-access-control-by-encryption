#import "@preview/charged-ieee:0.1.4": ieee
// #import "@preview/ieee-monolith:0.1.0": ieee
#import "@preview/pintorita:0.1.4"
#import "@preview/cetz:0.4.2"
#import "@preview/codly:1.3.0"

#import "cmds.typ": new, todo

#let body-end = state("body-end", 0)
#let show-footer = state("show-footer", true)

#set page(
  footer: context {
    if show-footer.get() [
      #set align(right)
      #set text(8pt)
      // Page #counter(page).display("1 of 1", both: true)
      Page #counter(page).display() of #body-end.final()
    ]
  }
)


#show raw.where(lang: "pintora"): it => pintorita.render(it.text)
#show link: underline
#show: ieee.with(
  title: [Fine-grained role-based access control by encryption],
  authors: (
    (
      name: "Andreas Severin Hauch Trøstrup",
      department: [Computer Science],
      organization: [IT University of Copenhagen],
      location: [Copenhagen, Denmark],
      email: "atro@itu.dk"
    ),
    (
      name: "Lucas Frey Torres Hanson",
      department: [Computer Science],
      organization: [IT University of Copenhagen],
      location: [Copenhagen, Denmark],
      email: "luha@itu.dk"
    )
  ),
  abstract: [
    // Motivation
    True separation of compute and data in data lakes comes at the cost of coarse access control.
    Authorization services like Lakekeeper introduce access control for any query engine, but limit authorization to the file level. 
    On the other hand, "fully managed all-in-one cloud platforms" like Snowflake offer fine-grained access control only within their own platform -- defeating the purpose of separating compute and data.

    // Results
    We propose Object Store Wrapper Service (OSWS), a system that enforces column-level role-based access control at the Object Store layer using Parquet Modular Encryption with envelope encryption, and still supports query engines that are already S3 compatible -- with no modifications.

    // Contributions
    Our evaluation, based on e2e test benchmarks, shows that OSWS adds negligible overhead for reading small Parquet files.
    Benchmarks on a warm DEK cache show a _p95_ GET latency of $30$ms for a $5$MB Parquet file, but with larger Parquet files it becomes unusably slow.
    We reflect on how these issues could be addressed through different fundamental design changes in OSWS.

    // Implications
    OSWS demonstrates that encryption-based fine-grained access control at the Object Store layer is a viable approach for data lakes, though limitations exist for query engines that cache Parquet metadata; however, those issues are addressable.
  ],
  // bibliography: bibliography("refs.bib"),
  figure-supplement: "Figure"
)

#place(
  top + right,
  float: false,
  dx: 3.5em,
  dy: -2em,
  text(9pt, style: "normal", weight: "medium")[STADS: KISPECI1SE]
)

#include "todo.typ"
#include "1-intro.typ"
#include "2-related-work.typ"
#include "3-background.typ"
#include "4-system-design.typ"
#include "5-methodology.typ"
#include "6-results.typ"
#include "7-discussion.typ"
#include "8-conclusion.typ"

#show-footer.update(false)
#context body-end.update(counter(page).get().first())

#bibliography("refs.bib", style: "ieee")

#pagebreak()
#include "9-appendix.typ"
