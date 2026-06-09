#import "@preview/polylux:0.4.0": *
#import "@preview/pintorita:0.1.4"
#import "slide-functions.typ": * // All functions
#import "4-system-design/crypto-flow.typ": encryptionFlow, decryptionFlow
#import "cmds.typ": todo

#show raw.where(lang: "pintora"): it => pintorita.render(it.text)

#set page(paper: "presentation-16-9")
#set page(footer: context {
  if show-footer.get() [
    #set align(right)
    #set text(8pt)
    Slide #counter(page).display() of #body-end.final()
  ]
})
#set text(size: 16pt)
#show heading.where(level: 1): set text(size: 24pt)
#show heading.where(level: 2): set text(size: 18pt)
#show link: underline

// Trølle: Frontpage + Agenda
// Lucas: Intro + Related
// Trølle: Sys Design
// Lucas: Methodology + Results
// Trølle: Discussion
// Lucas: Conclussion

// FRONTPAGE / ABSTRACT (TRØLLE)

#slide[
  #align(center + horizon)[
    #text(size: titleText, weight: "bold")[Fine-grained Role-Based Access Control in Data Lakes by Encryption]
    
    == Object Store Wrapper Service (OSWS)
    #v(bigWidth)
    #let centered-on(symbol, lhs, rhs) = context {
      let side = calc.max(measure(lhs).width, measure(rhs).width); box(width: side, align(right, lhs)); h(0.5em); symbol; h(0.5em); box(width: side, align(left, rhs))
    }

    #centered-on(sym.circle.stroked, [Andreas Severin Hauch Trøstrup], [Lucas Frey Torres Hanson])
    #align(center)[IT University of Copenhagen]
    #align(center)[Supervisor: Martin Hentschel]
    #align(center)[June 11th 2026]
  ]
]

#slide[
  = Agenda
  #v(mainWidth)
  - Introduction #p(3)
  - Related Work #p(4)
  - System Design #p(5)
    - Architecture Overview #p(6)
    - Design Choices #p(7)
    - Examples #p(11)
  - Methodology #p(13)
    - Micro-benchmarks #p(14)
    - E2E-benchmarks #p(15)
  - Results #p(16)
  - Discussion #p(17)
    - Limitations and future work considerations #p(18)
  - Conclusion #p(19)
]

// INTRODUCTION (LUCAS)

#slide[
  = Introduction
  #v(mainWidth)
  - Compute and storage are separate in data lakes.
  - Object Store only understands _files_ #sym.arrow.r.double coarse access control
  #v(normalWidth)
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      == Option 1: Cloud Platform
      - Fine-grained access control
      - Vendor lock-in
        - "fully managed all-in-one cloud platform"
    ],
    [
      == Option 2: Vended Credentials
      - File-level access control
        - Coarse access control
      - Use preferred query engine
    ]
  )
  #v(normalWidth)
  == Solution

  - OSWS
    - It decrypts columns based on authorization
]

// RELATED WORK (LUCAS)

#slide[
  = Related Work
  #v(mainWidth)
  - "Membrane: A Cryptographic Access Control System for Data Lakes"
    - Cell-level access control
    - Pull the whole file, but operate only on the view
    - Client is responsible for providing keys/views
  - "One Stone, Three Birds: Finer-Grained Encryption with Apache Parquet @ Large Scale" (Uber paper)
    - Uses standard Parquet files and PME
    - Uses a standard KMS for cryptographic keys
    - Client uses Parquet library extension to read and write

  == Them vs OSWS
  - Them: Reader/writer needs to be modified
  - OSWS: Want to ensure no reader/writer modifications
    - Previously: Wanted option for local decryption
]

// SYSTEM DESIGN

#slide[
  = System Design
  #v(mainWidth)
  - Wrap S3-compatible Object Store // er de to her ikke lidt det samme?
  - Provide S3-compatible API
  - Enforce column-level Role-Based Access Control with Parquet Modular Encryption// de her to er meget det samme
  //- Enforces column-level RBAC via Parquet Modular Encryption
  - DuckDB, Spark, Python -- should be able to use OSWS with no modifications
]

// SYSTEM DESIGN: Architecture Overview

#slide[
  = System Design: Architecture Overview
  #align(center)[
    #box(height: 90%)[#include "4-system-design/osws-architecture-overview.typ"]
  ]
]

// SYSTEM DESIGN: DESIGN CHOICES: Database Design + RBAC

#slide[
  = System Design: Design Choices - Database Design + RBAC
  #v(mainWidth)
  #scale(80%)[#include "4-system-design/er-diagram.typ"]
  // [*Users* #sym.arrow.r *Roles* #sym.arrow.r *Permissions* #sym.arrow.r *Columns*]
  - S3 API Credentials, Identity- & RBAC-metadata
  = System Design: RBAC Example
  #v(smallWidth)
  - Many-to-many: User #sym.arrow.l.r RoleAssignment #sym.arrow.l.r Role
  - Many-to-many: Role #sym.arrow.l.r Permission #sym.arrow.l.r Column
  - Role hierarchy via recursive SQL (self-referential `RoleInheritance` table)
  #v(normalWidth)
  #exampleBlock[
    *Example:* \
    Role _Analyst_ #sym.arrow.r direct access to columns: name, age \
    Role _Admin_ #sym.arrow.r direct access to column: ssn \
    _Admin_ inherits _Analyst_ #sym.arrow.r Admin sees all columns.
  ]
  #v(smallWidth)
]

// SYSTEM DESIGN: DESIGN CHOICES: DEK Cache

#slide[
  = System Design: Design Choices - DEK Cache
  #v(mainWidth)
  - Store unwrapped DEKs in in-memory cache
    - Results in less KV calls and less latency
  - The unwrapped DEK gets stored with a unique identifier which also references the KEK identifier
  - Uses predefined TTL
]

// SYSTEM DESIGN: DESIGN CHOICES: Envelope Encryption

#slide[
  = System Design: Design Choices - Envelope Encryption
  #v(mainWidth)
  - Original idea did not include envelope encryption
  - KV does not allow for fetching cryptographic keys
  - Decrypting columns inside KV is extremely slow
  - Allows for caching unwrapped DEKs
]

// SYSTEM DESIGN: EXAMPLES: Encryption Flow

#slide[
  = System Design: Walkthrough Examples - Encryption Flow
  #box(height: 90%)[#encryptionFlow]
]

// SYSTEM DESING: Decryption Flow

#slide[
  = System Design: Walkthrough Examples - Decryption Flow
  #box(height: 90%)[#decryptionFlow]
]

// METHODOLOGY (LUCAS)

#slide[
  = Methodology
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      - All benchmarks run on Digital Ocean VM\
        (8 Core AMD, 16GB DRAM)\
        Digital Ocean Space
      - Micro-benchmarks
        + Permission Service
        + Permission Hierarchy
        + Unwrapping
        + Decryption
      - E2E-benchmarks
       + S3
       + OSWS +encryption +cache
       + OSWS +encryption -file cache
       + OSWS +encryption -DEK cache
       + OSWS -encryption
    ],
    [
      #set text(10pt)
      #box(height: 80%, width: 100%)[#include "5-methodology/benchmark-config.typ"]
    ]
  )
  #let down(init, inc) = (init + (1.83 * inc)) * 1em
  #place(top + right, dx: -10.9em, dy: 5.7em,
    rect(width: 2.5em, height: 0.7em, fill: oHighlight)
  )
  #place(top + right, dx: -7.1em, dy: 5.7em,
    text(fill: red, 20pt)[\*]
  )
  #place(top + right, dx: -10.9em, dy: down(5.7, 1),
    rect(width: 2.5em, height: 0.7em, fill: oHighlight)
  )
  #place(top + right, dx: -7.1em, dy: down(5.7, 1),
    text(fill: red, 20pt)[\*]
  )
  #place(top + right, dx: -10.9em, dy: down(5.7, 2),
    rect(width: 2.5em, height: 0.7em, fill: oHighlight)
  )
  #place(top + right, dx: -7.1em, dy: down(5.7, 2),
    text(fill: red, 20pt)[\*]
  )
  #place(top + right, dx: -10.9em, dy: down(5.7, 3),
    rect(width: 2.5em, height: 0.7em, fill: oHighlight)
  )
  #place(top + right, dx: -7.1em, dy: down(5.7, 3),
    text(fill: red, 20pt)[\*]
  )
]

// RESULTS: Micro-Benchmarks (LUCAS)

#slide[
  #import "6-results/micro-boxplot.typ": decryption, unwrap
  = Results: Micro-Benchmarks
  #v(-0.6*mainWidth)
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      #set text(12pt)
      #scale(85%)[#decryption()]
    ],
    [
      #set text(12pt)
      #scale(85%)[#unwrap()]
    ]
  )
  #v(-1.7*mainWidth)
  - Roles had minor contribution to latency ($\~3-30$ms)
  - Main Bottleneck
    - DEK unwrap (fixed KV cost)
    - Decryption (scales with file size).
]

// RESULTS: E2E Latency (LUCAS)

#slide[
  #import "6-results/e2e-bar-plots.typ": getwarm, getcold
  = Results: E2E Latency

  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      #set text(9pt)
      #scale(108%)[#getwarm()]
    ],
    [
      #set text(9pt)
      #scale(108%)[#getcold()]
    ],
    [
      - Tiny: overhead high, but absolute latency low (30 ms = practical)
      - Large (~500 MB+): timeouts without DEK cache → needs redesign
    ],
    [
      #box(height: 40%, width: 100%)[
        #set text(8pt);
        #include "6-results/dekcachelatency.typ";
      ]
    ]
  )
]

// DISCUSSION: Limitations of the Current Design

// #todo[flet impact on query engines ind]
#slide[
  = Discussion: Limitations of the Current Design
  #v(mainWidth)
  *The parquet file is copied instead of modified*
  - Parquet Sharp adds its own metadata
    - Client: written file #sym.eq.not read file
  
  - Modified metadata due to PME and Parquet Sharp
  - Full rewrite of the Parquet File
  - Parquet Sharp + PME results in full rewrite on decryption
  Parquet Sharp + PME = full-file rewrite
  #v(smallWidth)
  OSWS must COPY the *entire* Parquet file, then encrypt/decrypt every column sequentially.
  #v(smallWidth)
  - New file #sym.eq.not original (different writer)
  - Metadata changes #sym.arrow.r file size changes
  - Range requests: must fetch the entire file first
  - Even unauthorized columns copied as dummy data
  #v(normalWidth)
  PME trust model: *client* handles crypto, doesn't trust storage. \
  OSWS needs: *server-side* crypto, client trusts the proxy.
  #v(smallWidth)
  *PME was the wrong tool for this job.*
]

// DISCUSSION: Proposed Redesign

#slide[
  = Discussion: Proposed Redesign
  #v(mainWidth)
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      *1. Internal Metadata Store*
      In PostgreSQL — not inside the Parquet file.
      - Store wrapped DEKs, KEK ref, column offsets
      - Enables range requests without full-file fetch
    ],
    [
      *2. Custom AES-CTR Modifier*
      Replace Parquet Sharp entirely.
      - Length-preserving → file size never changes
      - In-place decryption, no file copy
      - Embarrassingly parallel row-groups
    ],
  )
  #v(normalWidth)
  - Files unchanged → DuckLake/Snowflake support \
  - Range requests work (fetch + decrypt only needed) \
  - Async key pre-fetch → KV off critical path \
  - Production-viable performance
]

// // SLIDE 16 - What to Keep for V2 ═══════════════════

// #slide[
//   = Keep for V2
//   #v(mainWidth)
//   *Envelope encryption with DEK cache* \
//   — mitigates KV latency, essential
  
//   *RBAC store in PostgreSQL* \
//   — negligible overhead (2-10 ms)
  
//   *KV-provider agnostic* \
//   — Azure → AWS → self-hosted = config change
  
//   *OIDC-provider agnostic* \
//   — Pocket ID, Entra ID, any OpenID provider
  
//   *Role hierarchy via recursive SQL* \
//   — simple, fast, correct
//   #v(normalWidth)
//   *Security issues to fix:*
//   - S3 secrets stored in plaintext → encrypt at rest via KV
//   - RBAC admin flag from OIDC claims → restrict claim sources
// ]

// CONCLUSSION (LUCAS)

#slide[
  = Conclusion
  #v(mainWidth)
  OSWS demonstrates feasibility of FGRBAC in data lakes by encryption
  == Objectives
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      + ✅ Create a POC of OSWS using an underlying S3-compatible Object Store.
      + ✅ Ensure OSWS enforces access control using RBAC and encryption.
      + ❌ Make it compatible with "fully managed all-in-one cloud platforms".
    ],
    [
      4. ⚠️ Make it compatible with "external query engines".
      + ✅ Benchmark OSWS to measure the latency it adds.
      + ✅ Reflect on design decisions and which alternatives would have been better.
    ],
    [
      *Correct Design Decisions*
      - DEK cache
        - Small: $\~5.6#sym.times$ improvement from none to cold
        - Small: $\~120#sym.times$ improvement from cold to warm
    ],
    [
      *Impractical in Current State*
      - System timeout on $1$GB files
      - $125$MB Parquet file retrieval took $1.6$ seconds in best case 
    ]
  )
]

#context body-end.update(counter(page).get().first())

// ══════════════════════════════════════════════════
// SLIDE 18 - Thank You
// ══════════════════════════════════════════════════

#slide[
  #align(center + horizon)[
    #text(size: 32pt, weight: "bold")[Questions?]
  ]
]

#show-footer.update(false)

#slide[
  #import "6-results/micro-boxplot.typ": permissionhier, permissionser
  = Results: Micro-Benchmarks - Roles
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      #set text(12pt)
      #scale(80%)[#permissionhier()]
    ],
    [
      #set text(12pt)
      #scale(80%)[#permissionser()]
    ]
  )
]

// Let this slide the bottom one as it overflows into new slides
// Cannot find a fix and do not want to spend more time on it
#slide[
  #import "6-results/e2e-bar-plots.typ": put
  = Results: E2E Latency - PUT
  #block(height: 60em)[
    #put()
  ]
]
