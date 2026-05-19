#import "@preview/cheq:0.3.1": checklist
#show: checklist

= Todo List

- [ ] In *methodology*, add info about setup for testing DuckLake and what the issues were
- [ ] System Design has to be refactored to not mention code files
- [ ] In *Discussion*, we have to add more info about why Parquet Sharp is not the way forward, as it does most work sequentially, and our other idea would allow for pre-fetching the keys and doing work asynchronously
- [x] Fix the not-defined times for how slow it is
- [ ] Lucas uses p99 for micro stuff. Use p95 instead to match e2e
