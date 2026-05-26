#import "@preview/cheq:0.3.1": checklist
#show: checklist

#heading(numbering: none, level: 1)[Todo List]

- [x] In *methodology*, add info about setup for testing DuckLake and what the issues were
- [ ] System Design has to be refactored to not mention code files
- [x] In *Discussion*, we have to add more info about why Parquet Sharp is not the way forward, as it does most work sequentially, and our other idea would allow for pre-fetching the keys and doing work asynchronously
- [x] Why is footer encryption not enabled.
- [x] Fix the not-defined times for how slow it is
- [x] Lucas uses p99 for micro stuff. Use p95 instead to match e2e
- [x] LRU has to be mentioned in system design
- [?] Seems like there is a lot of repetition in the beginning of @sec:discussion
- [x] Have to mention AES-CTR in the discussion as it is currently only referred to in the conclusion.
- [ ] Minor: Fix page numbering in appendix (prolly shouldnt include)
- [ ] Minor: Course code and shit on front page?