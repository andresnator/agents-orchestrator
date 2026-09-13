# Synthetic test inputs

These are test scripts, not evidence of a human learning outcome. Submit each answer as an ordinary user message in the assigned host session; capture its actual IDs. Never insert fabricated IDs into a new event.

## Cache

- Class: `Age 90 exceeds max-age 60, so the response is stale and cannot be reused as fresh.`
- Partial: `It is stale; I do not yet know what request to send.`
- Practice: `A stale response with an ETag can be conditionally revalidated. A 304 lets the cache reuse the body; a changed representation requires the new body.`
- Consolidation: `Freshness permits reuse without validation. Once stale, I send If-None-Match with the ETag. A 304 preserves the cached body; a 200 replaces it. For an image with Age 120 and max-age 30, I also validate before reuse.`
- Review 1: `Age exceeds max-age, so the response is stale.`
- Review 2: `A 304 lets the cache reuse its stored body after validation.`

## Plugin theory

`A plugin registers capabilities with the host. I check the contract and permissions before activation, inspect failures, and disable it if unsafe. I can explain these decisions but have not implemented a plugin.`

## Language

Source: `I would like to check in for flight 1.`
Spanish: `Quisiera facturar para el vuelo 1.`
Gist: `Someone wants to check in.`
Meaning-changing: `I would like to cancel flight 1.`
Equivalent: `I'd like to check in for flight 1, please.`
Input-only: `Solo quiero comprender esta unidad, sin producirla ahora.`
Retry: `I have worked here for three years.`
Dialogue: `Agent: May I see your passport? / Agente: ¿Me permite su pasaporte?
Traveller: Here it is. / Viajero: Aquí lo tiene.`

## Vocabulary rows (five semicolon fields)

`check in;facturar;I need to check in.;Necesito facturar.;airport`
`boarding pass;tarjeta de embarque;Here is my boarding pass.;Aquí está mi tarjeta de embarque.;airport`

## Standalone material

Teacher notes: HTTP requests contain the information needed to interpret them. Cookies can carry application state without changing HTTP's stateless semantics.
Cue/answer pairs: When is a cache entry stale? / When freshness lifetime is exceeded. What does a 304 allow? / Reuse of the stored body after validation.
No verified learner notes are supplied: Cornell must mark learner evidence pending.

## Delayed retrieval (human only)

Day 0: Explain freshness versus validation; apply it to Age 90, max-age 60, ETag present.
Day 7: Without hints, when can a cached response be reused? Apply it to a CSS file with Age 80, max-age 20 and Last-Modified.
Day 30: Without hints, explain conditional validation. Apply it to a cached image with Age 200, max-age 100 and a changed ETag.
