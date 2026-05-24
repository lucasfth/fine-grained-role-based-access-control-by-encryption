#import "@preview/cheq:0.3.1": checklist
#show: checklist

#heading(numbering: none, level: 1)[Todo List]

- [ ] In *methodology*, add info about setup for testing DuckLake and what the issues were
- [ ] System Design has to be refactored to not mention code files
- [ ] In *Discussion*, we have to add more info about why Parquet Sharp is not the way forward, as it does most work sequentially, and our other idea would allow for pre-fetching the keys and doing work asynchronously
- [x] Why is footer encryption not enabled.
- [x] Fix the not-defined times for how slow it is
- [x] Lucas uses p99 for micro stuff. Use p95 instead to match e2e
- [ ] Include figure for parquet with unencrypted footer in appendix
- [ ] LRU has to be mentioned in system design
- [ ] Seems like there is a lot of repetition in the beginning of @sec:discussion
- [ ] Have to mention AES-CTR in the discussion as it is currently only referred to in the conclusion.