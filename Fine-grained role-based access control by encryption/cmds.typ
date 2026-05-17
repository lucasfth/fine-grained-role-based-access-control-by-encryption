// Something which has to be addressed
#let todo(val) = text(fill: orange, weight: "bold")[#val]
// Something which probably has to be deleted
#let delete(val) = highlight(fill: rgb("#FFC5CB"))[#val]
// Something which might not be important and thus deleted in future
#let maybeDelete(val) = highlight(fill: rgb("#FCE1E3"))[#val]
// Update text
#let update(val) = text(fill: gray)[#val]
// Speculation text
#let speculation(val) = highlight(fill: gray)[#val]
// Text updated based on Martin's feedback, where the outcommented below is what it is supposed to replace.
#let martinFeedback(val) = highlight(fill: yellow)[#val]