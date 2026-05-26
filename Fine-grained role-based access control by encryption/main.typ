#import "@preview/charged-ieee:0.1.4": ieee
// #import "@preview/ieee-monolith:0.1.0": ieee
#import "@preview/pintorita:0.1.4"
#import "@preview/cetz:0.4.2"
#import "@preview/codly:1.3.0"

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
    Data lakes supporting multiple query engines lack fine-grained access control; only "fully managed all-in-one cloud platforms" like Snowflake or Databricks offer it, within their own ecosystem.

    // Results
    We propose Object Store Wrapper Service (OSWS), a system enforcing column-level role-based access control at the Object Store layer using Parquet Modular Encryption with envelope encryption, and still supporting query engines that are already S3 compatible.

    // Contributions
    Our evaluation shows that OSWS adds an acceptable overhead for tiny to small Parquet files, when using a DEK cache, with warm _p95_ GET latency of _30ms_ for a _5MB_ Parquet file, but with larger files it becomes unusable, and design choice changes would allow for an efficient solution.

    // Implications
    OSWS demonstrates that encryption-based access control at the Object Store layer is a viable approach for data lakes, though limitations exist for query engines that cache Parquet metadata; however, those issues are addressable.
  ],
  // note: [Course code: KSXXXX1KU],
  // bibliography: bibliography("refs.bib"),
  figure-supplement: "Figure"
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
