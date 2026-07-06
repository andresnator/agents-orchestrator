# Common Domain

Shared engineering, quality, service-boundary, native question UX, and output-refinement components used by other domains.

Agent and command entry: `boundary-inspector`.

Use common skills by reference from domain-specific agents instead of duplicating them into each domain.

```mermaid
graph TD
  boundary[boundary-inspector] --> service[service-boundary-analysis]
  quality[quality skills] --> refactor[refactor domain]
  practices[engineering practices] --> sdd[SDD domain]
  native[native-question-ux] --> meta[meta domain]
  output[cognitive-output-refiner] --> docs[docs domain]
```
