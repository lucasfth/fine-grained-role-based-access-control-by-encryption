#import "@preview/charged-ieee:0.1.4": ieee
// #import "@preview/ieee-monolith:0.1.0": ieee
#import "@preview/pintorita:0.1.4"
#import "@preview/cetz:0.4.2"
#import "@preview/codly:1.3.0"
#import "cmds.typ": todo

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
    Data lakes supporting multiple query engines lack fine-grained access control; only "fully managed all-in-one cloud platforms" like Snowflake or Databricks offer it, within their own ecosystem.
    // Data lakes today have limitations in only allowing fine-grained access control on fully-managed cloud platforms like Snowflake or Databricks, where open data lakes with potentially many different query engines have to rely on limited catalogue-based access control.

    // Results
    We propose Object Store Wrapper Service (OSWS), a system enforcing column-level role-based access control at the Object Store layer using Parquet Modular Encryption with envelope encryption, and still supports query engines that are S3 compatible.
    // Theory and proposed solutions will be examined to see which options might be able to bridge this gap of ensuring fine-grained access control, and if encryption and role-based access control might be part of solving it.

    // Contributions
    Our evaluation shows that OSWS adds an acceptable overhead for tiny to small Parquet files, when using a DEK cache, with cold `GET` latency of #todo[XXX]s for a _5MB_ Parquet file, but with other design choices are more efficient solution is possible.
    // We propose a system for enforcing fine-grained role-based access control at the object store level as well as creating a wrapper around the object store to allow query engines to access the data without modifications.

    // Implications
    OSWS demonstrates that encryption-based access control at the Object Store layer is a viable approach for data lakes, though limitations exist for query engines that cache Parquet metadata.
    // Our findings show that the encryption to enforce access control might be a viable solution, as both modified and unmodified query engines are enforced to follow the column-level granularity using the role-based access control if they want to read the data, but will also have to be proven functional by a future MVP.
  ],
  bibliography: bibliography("refs.bib"),
  // bibliography: bibliography("refs.bib", style: "harvard-cite-them-right"),
  figure-supplement: "Figure"
)

#figure(
  scope: "parent",
  placement: top,
  (```txt
      ___           ___           ___           ___
     /\  \         /\__\         /\  \         /\__\
    /::\  \       /:/ _/_       _\:\  \       /:/ _/_
   /:/\:\  \     /:/ /\  \     /\ \:\  \     /:/ /\  \
  /:/  \:\  \   /:/ /::\  \   _\:\ \:\  \   /:/ /::\  \
 /:/__/ \:\__\ /:/_/:/\:\__\ /\ \:\ \:\__\ /:/_/:/\:\__\
 \:\  \ /:/  / \:\/:/ /:/  / \:\ \:\/:/  / \:\/:/ /:/  /
  \:\  /:/  /   \::/ /:/  /   \:\ \::/  /   \::/ /:/  /
   \:\/:/  /     \/_/:/  /     \:\/:/  /     \/_/:/  /
    \::/  /        /:/  /       \::/  /        /:/  /
     \/__/         \/__/         \/__/         \/__/

```) // HÆHÆ `figlet -f isometric2 OSWS`
)

#include "1-intro.typ"
#include "2-related-work.typ"
#include "3-background.typ"
#include "4-system-design.typ"
#include "5-methodology.typ"
#include "6-results.typ"
#include "7-discussion.typ"
#include "8-conclusion.typ"
#pagebreak()
#include "9-appendix.typ"
#pagebreak()

