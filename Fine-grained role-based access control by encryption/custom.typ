#let subfigures(main-caption, label: none, sub-figs) = {
  let sub-counter = counter("subfigure")
  sub-counter.update(1)

  let content = figure(
    caption: main-caption,
    kind: image,
    placement: top,
    scope: "parent", // either parent or column
    supplement: [Figure],
    {
      show figure.caption: set text(size: 0.8em)
      show figure.caption: set block(width: 100%)
      
      show figure: set figure(
        numbering: (..n) => {
          let main = counter(figure.where(kind: image)).at(here()).first()
          sub-counter.step()
          let sub = sub-counter.at(here()).first()
          [#main.#sub]
        },
      )

      grid(
        columns: (1fr, 1fr),
        gutter: 2em,
        ..sub-figs.map(sf => [
          #figure(
            sf.img, 
            caption: sf.cap, 
            kind: "sub-fig", 
            supplement: [Figure]
          ) #sf.at("lbl", default: none) 
        ])
      )
    }
  )

  if label != none { [#content #label] } else { content }
}

#let prosecite(key) = {
  // Indlejret show-rule fjerner kun initialer i dette specifikke kald
  show regex("\p{Lu}\.\s+"): none
  cite(key, form: "prose")
}