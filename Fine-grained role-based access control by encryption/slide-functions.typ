// ── Spacing constants ─────────────────────────────
#let mainWidth = 1.5em
#let bigWidth = 3em
#let normalWidth = 1em
#let smallWidth = 0.5em
#let gutterWidth = 2em
#let titleText = 32pt

// ── State ─────────────────────────────────────────
#let body-end = state("body-end", 0)
#let show-footer = state("show-footer", true)

// ── Components ────────────────────────────────────
#let exampleBlock(text) = block(
  width: 90%, fill: luma(240), inset: 1em, radius: 4pt
)[#text]

#let oHighlight = rgb(255, 165, 0, 20%)

// #let p(n) = [#box(width: 1fr)[#repeat[.]] #n]
#let p(n) = [#box(width: 1fr)[#repeat[#text(2pt)[OSWS~]]] #n]
