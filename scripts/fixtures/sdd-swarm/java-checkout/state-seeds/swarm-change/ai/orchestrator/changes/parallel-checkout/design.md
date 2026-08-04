# Design: Parallel checkout

Each independent policy owns one package and exposes a small immutable API. `CheckoutSummary` is the only integration point. `CheckoutRegistry` represents a shared hotspot and must never share a parallel wave.
