# Workspace Runtime Performance

## Goal

Make workspace switching and steady-state reconciliation approach AeroSpace's event-driven behavior
without sacrificing logical-window identity or recovery safety.

## Benchmark

```sh
cargo test --release benchmark_dual_display_steady_state_256_windows -- --ignored --nocapture
```

Primary metric: `steady_state_cycle_us`.

Structural metrics: system snapshot and observed-apply calls per dual-display cycle. These represent
expensive system-wide CG/AX scans in the production backend.

## Hypotheses

1. One system observation partitioned in memory will halve snapshot work.
2. Skipping empty apply batches will remove redundant CG window-list scans.
3. Cached per-application AX elements will replace per-window `AXWindows` scans.
4. AXObserver invalidation can replace steady 250 ms polling.

## Reference

AeroSpace uses per-application AX threads and element caches, cancellable refresh sessions, and
AX/NSWorkspace notifications rather than steady-state polling.

## Results

| Experiment | Median µs/cycle | Snapshots/cycle | Decision |
| --- | ---: | ---: | --- |
| Baseline | 107.788 | 2 | Baseline |
| One system observation, partitioned in memory | 104.556 | 1 | Keep |
| Skip empty apply batches | 104.285 | 1 | Keep: removes two production CG scans/cycle |
| Indexed window ownership | 96.899 | 1 | Keep |
| Shared observed-frame index | 86.919 | 1 | Keep |
| Partition world observation without cloning | 86.360 | 1 | Discard: inside noise, more code |
| Batch managed AX lookup by application | n/a | 1 AXWindows read/app vs. 1/window | Keep |
| AXObserver-driven invalidation | n/a | 12 fallback scans/min vs. 240 | Keep |
| Ephemeral parallel app observation | n/a | n/a | Discard: loses thread-local AX cache |
| Final corrected implementation | 87.906 | 1 | Keep: 18.4% faster than baseline |
| Config, rules, and dynamic displays | 88.408 | 1 | Keep: no material regression |

## Relayout Responsiveness

Primary metric: worst-case relayout latency when an AX notification is missed. The layout engine's
release benchmark remains below 0.1 ms, so multi-second latency comes from scheduling rather than
reconciliation.

| Experiment | Worst-case fallback | Safety scans/min | Decision |
| --- | ---: | ---: | --- |
| AXObserver fallback baseline | 5000 ms | 12 | Baseline |
| One-second missed-event fallback | 1000 ms | 60 | Keep: 80% lower tail latency and still 4x fewer scans than the original 250 ms polling loop |
