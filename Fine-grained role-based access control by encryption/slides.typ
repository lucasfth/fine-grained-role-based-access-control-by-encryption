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

#slide[ // TIME  20sec with frontpage
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

#slide[ // TIME 1:00
  = Introduction
  #v(mainWidth)
  - In data lakes, compute and storage are separate.
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

#slide[ // TIME 1:20
  = Related Work
  #v(mainWidth)
  - "Membrane: A Cryptographic Access Control System for Data Lakes"
    - Cell-level access control
    - Pull the whole file, but operate only on the view
    - Client is responsible for providing keys/views
  - "One Stone, Three Birds: Finer-Grained Encryption with Apache Parquet @ Large Scale" (Uber paper)
    - Uses standard Parquet files and Parquet Modular Encryption (PME)
    - Uses a standard KMS for cryptographic keys
    - Client uses Parquet library extension to read and write

  == Them vs OSWS
  - Them: Reader/writer needs to be modified
  - OSWS: Want to ensure no reader/writer modifications
    - Previously: Wanted option for local decryption
]

// SYSTEM DESIGN

#slide[ // TIME 40 sec
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

#slide[ // TIME 1 min
  = System Design: Design Choices - Database Design + RBAC
  #v(mainWidth)
  #scale(100%)[#include "4-system-design/er-diagram.typ"]
  #place(bottom + right, dy: -10em, dx: -1em,
    text(fill: red, 30pt)[\*]
  )
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

// consider

#slide[ // TIME 20 sec
  = System Design: Design Choices - Frontend
  #v(mainWidth)
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
  - Credentials and RBAC managed through frontend
    - Interacts with API
  - Users log in via OIDC
  - Admins manage RBAC with SQL-like grammar
    ],
    [
      #scale(100%)[#include "4-system-design/peggy.typ"]
    ]
  )

]

// SYSTEM DESIGN: DESIGN CHOICES: Envelope Encryption

#slide[ // TIME 40 sec
  = System Design: Design Choices - Envelope Encryption
  #v(mainWidth)
  - Original idea did not include envelope encryption
  - KV does not allow for fetching cryptographic keys
  - Decrypting columns inside KV is extremely slow
  - Allows for caching unwrapped DEKs
]

// SYSTEM DESIGN: DESIGN CHOICES: DEK Cache

#slide[ // TIME 30 sec
  = System Design: Design Choices - Caching
  #v(mainWidth)
  *DEK Cache*
  - Store unwrapped DEKs in in-memory cache
    - Results in less KV calls and less latency
  - The unwrapped DEK gets stored with a unique identifier which also references the KEK identifier
  - Uses predefined TTL
  #v(mainWidth)
  *Encrypted File Cache*
  - Cache full encrypted files to skip Object Store
  - LRU Policy
]

// SYSTEM DESIGN: EXAMPLES: Encryption Flow

#slide[ // TIME 1:08
  = System Design: Walkthrough Examples - Encryption Flow
  #align(center)[
    #box(height: 90%)[#encryptionFlow]
  ]
]

// SYSTEM DESING: Decryption Flow

#slide[ // TIME 1 min
  = System Design: Walkthrough Examples - Decryption Flow
  #align(center)[ 
    #box(height: 90%)[#decryptionFlow]
  ]
]

// METHODOLOGY (LUCAS)

#slide[ // TIME 1:50
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

#slide[ // TIME 1:30
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

#slide[ // TIME 1.40
  #import "6-results/e2e-bar-plots.typ": getwarm, getcold
  = Results: E2E Latency

  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      - DEK cache is essential (500MB + timeout)
      - GET warm:
        - Tiny: $30$ ms
        - Medium: $~1.6$ vs $~0.5$ seconds
    ],
    [
      #box(height: 40%, width: 100%)[
        #set text(8pt);
        #include "6-results/dekcachelatency.typ";
      ]
    ],
    [
      #set text(9pt)
      #scale(108%)[#getwarm()]
    ],
    [
      #set text(9pt)
      #scale(108%)[#getcold()]
    ]
  )
]

// DISCUSSION: Limitations of the Current Design

// #todo[flet impact on query engines ind]
#slide[ // TIME 2:20
  = Discussion: Limitations of the Current Design
  #v(mainWidth)
  *Core issue: The Parquet files are copied instead of modified*
  - OSWS does full rewrite of the Parquet file to encrypt and decrypt
  - But: different writers produce different files
    - Different metadata, encoding
    - For the client: written file #sym.eq.not read file
  - Result: Inconsistencies in file size
    - Breaks writers that store original size (like DuckLake)
  
  #v(smallWidth)
  This must be done on *every fetch*
  - Range requests: must fetch the entire file first
  - Even unauthorized columns copied as dummy data
  #v(normalWidth)
  Ultimately, *PME was not the right fit* \
  - PME trust model: *client* handles crypto, doesn't trust storage. \
  - OSWS: *server-side* crypto, client trusts the proxy.
  #v(smallWidth)
]

// DISCUSSION: Proposed Redesign

#slide[ // TIME 2 min
  = Discussion: Proposed Redesign
  #v(mainWidth)
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      *1. Internal Metadata Store*
      in the *database*
      - No need to store inside Parquet for OSWS
      - Store wrapped DEKs, KEK ref
    ],
    [
      *2. Custom AES-CTR Modifier*
      - Replace Parquet Sharp entirely with modifier
      - Length-preserving → file size never changes
      - In-place decryption, no file copy
    ],
  )
  #v(normalWidth)
  *Question: How to know what key covers a range?*
  - Idea: Store metadata about what columns cover what range
  - Lookup DEKs based on range
  
  *Key improvements:*
  - Files unchanged → addresses DuckLake issue \
  - Range requests work (fetch + decrypt only needed) \
  - Async DEK unwrap from pre-fetched wrapped keys \
]

// CONCLUSSION (LUCAS)

#slide[  // TIME 1:50
  = Conclusion
  #v(mainWidth)
  OSWS demonstrates feasibility of FGRBAC in data lakes by encryption
  == Objectives
  #grid(
    columns: 2,
    gutter: gutterWidth,
    [
      + ✅ Create a PoC of OSWS using an underlying S3-compatible Object Store.
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
      - $125$MB Parquet file retrieval took $1.6$ seconds in best case
      - Larger files are even slower
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
  = Background
  #block(height: 40em)[
      #image("3-background/pem_plainfooter.png")
  ]
]

#slide[
  = System Design: API
  #let textSize = 8.4pt
  #let scaling = 100%
  #grid(
    columns: 3,
    gutter: 0.4*gutterWidth,
    [
      #set text(textSize)
      #scale(scaling)[#include "4-system-design/s3-compatible-endpoints.typ"]
    ],
    [
      #set text(textSize)
      #scale(scaling)[#include "4-system-design/application-endpoints.typ"]
    ],
    [
      #set text(textSize)
      #scale(scaling)[#include "4-system-design/administrative-endpoints.typ"]
    ]
  )
]

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

#slide[
  = Discussion: DuckLake error case
  #box(height: 90%)[#include "7-discussion/ducklake.typ"]
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
