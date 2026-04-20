#import "@preview/charged-ieee:0.1.4": ieee
// #import "@preview/ieee-monolith:0.1.0": ieee
#import "@preview/pintorita:0.1.4"
#import "@preview/cetz:0.4.2"

#set page(
  footer: context [
    #set align(right)
    #set text(8pt)
    Page #counter(page).display("1 of 1", both: true)
  ]
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
      email: "atro@itu.dk"
    ),
    (
      name: "Lucas Frey Torres Hanson",
      department: [Computer Science],
      organization: [IT University of Copenhagen],
      email: "luha@itu.dk"
    )
  ),
  abstract: [
    // Motivation
    // Data lakes today have limitations in only allowing fine-grained access control on fully-managed cloud platforms like Snowflake or Databricks, where open data lakes with potentially many different query engines have to rely on limited catalogue-based access control.

    // Results
    // Theory and proposed solutions will be examined to see which options might be able to bridge this gap of ensuring fine-grained access control, and if encryption and role-based access control might be part of solving it.

    // Contributions
    // We propose a system for enforcing fine-grained role-based access control at the object store level as well as creating a wrapper around the object store to allow query engines to access the data without modifications.

    // Implications
    // Our findings show that the encryption to enforce access control might be a viable solution, as both modified and unmodified query engines are enforced to follow the column-level granularity using the role-based access control if they want to read the data, but will also have to be proven functional by a future MVP.
  ],
  bibliography: bibliography("refs.bib"),
  figure-supplement: "Figure"
)

#include "1-intro.typ"
#include "2-background.typ"
#include "3-system-design.typ"
#include "4-methodology.typ"
// #include "5-related-work.typ"
#include "3-rbac-in-dl.typ"
// #include "4-other-ideas.typ"
// #include "6-discussion.typ"
// #include "7-future-work.typ"
// #include "8-conclusion.typ"
#include "9-appendix.typ"
