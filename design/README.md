# Doctor design review — 2026-09-30

> Historical 0.1 review. The native 1.0 implementation is now built, installed and verified. See the [delivery record](../verification/README.md) and [final Kimi3 decisions](../verification/KIMI-DECISIONS.md). Statements below about pending work describe the earlier review date.

Open [doctor-concept.html](doctor-concept.html) in a browser. It is a standalone interactive design study, with sample data, not an installed plugin or a live diagnostic dashboard. It has no external assets or dependencies. [Desktop preview](doctor-concept.png) · [Mobile preview](doctor-concept-mobile.png).

The existing `Doctor.qml`, collector, manifest and root README were reviewed and left unchanged. The source files arrived in the workspace during the review; the folder was initially empty.

## Direction

Make Doctor the diagnostic companion to Pulse: a visual answer to “what is wrong, what proves it, and what should I inspect next?”

The installed reference is `/home/pi/.config/omarchy/plugins/nixfred.pulse`, version 1.3.2. Its strongest reusable patterns are domain-specific drawn hardware, concern-driven emphasis, real history traces, theme roles and detailed domain pages. Its `sections/CpuChip.qml` specifically documents replacing costly Canvas shadow blurs with layered strokes and a visible-only 10 Hz repaint timer. Preserve that discipline in a native Doctor implementation.

The concept includes:

- An animated system diagram with a breathing host core, counter-rotating arcs and moving connection traces.
- Distinct CPU, RAM, storage and GPU illustrations with sample history graphs.
- A health verdict with separate healthy, attention and unavailable counts; no invented health percentage.
- Overview → findings → evidence navigation. Clicking a vital card opens its explanation and inspection command.
- A sample scan sequence showing progress through the existing 15 checks.
- Healthy, attention and unavailable scenarios; pause motion, reduced-motion support and responsive layout.

For the production QML panel, use Omarchy theme colors, size to the available screen, retain keyboard navigation, and stage the overview into view over roughly 200–350 ms. Keep ambient motion slow and pause it when hidden. Reserve urgent motion for new findings; never blink continuously. Graphs must be based on timestamped retained observations or an explicit Pulse integration. Doctor currently has no historical data source.

## Findings to fix before polishing

1. **High: false thermal alarms.** `doctor-checks.sh:100` extracts every temperature in `sensors` text, including `high` and `crit` limits. A fixture reporting current `48°C`, high `85°C`, critical `100°C` produces a red `100°C` finding. Parse `sensors -j` temperature input fields and keep thresholds separate.
2. **High: failed checks can claim health.** `doctor-checks.sh:25` and `:40` discard command failure and treat empty output as success. Mocked failing `systemctl` and `journalctl` commands both produced `ok`. Capture command exit status and distinguish healthy, warning, critical, unavailable, skipped and stale results. `Doctor.qml:21` also declares health when there are results but no warning/error counts, including all-info results. Its exit handler at `:110` ignores a nonzero collector exit when partial rows exist.
3. **Medium: one slow command can stall the whole scan.** Checks run sequentially without deadlines, and `Doctor.qml:108` buffers output until completion. Put limits on individual probes, stream structured results, preserve partial findings and report timed-out checks. Keep expensive package integrity scans on a separate deep-scan path.
4. **Medium: service coverage misses the desktop's user services.** `check_failed_services` checks system units only. Collect both system and `--user` units and label their scope.
5. **Medium: drive health may inspect the wrong disk.** `doctor-checks.sh:225` selects the first physical disk and later calls it “primary.” Resolve the root filesystem's physical backing devices, including encryption/RAID, or list all drives with explicit identities and coverage.
6. **Medium: fixed popup sizing and row navigation need layout verification.** `Doctor.qml:154` targets a 470-wide panel; the control row at `:240` contains a long, unwrapped hint. Keyboard scrolling at `:163` assumes 76-pixel rows although row heights depend on wrapped content. Measure actual delegate geometry and scroll the selected row into view. These layout risks were identified in source, not verified in a running native panel.

## Implementation sequence

1. Correct diagnostic status handling and add regression fixtures for sensor limits, permission errors, missing tools, timeouts and partial scans.
2. Replace the four-field TSV with a versioned JSON-lines event format carrying check ID, domain, state, timestamp, duration, numeric measurements with units, evidence and suggested inspection command. Never derive charts by parsing prose summaries.
3. Split the QML into a scan model, overview, hardware drawings, history chart and finding/evidence components. Give the bar a compact animated Doctor glyph and a clear attention count, using Pulse's inexpensive drawing patterns.
4. Add scan history and comparison: new, persistent and resolved findings, with retention limits. Reuse Pulse telemetry only through a documented optional adapter; keep Doctor usable without Pulse.
5. Validate in the native shell on laptop and large displays, with long evidence, missing tools, dark/light themes and motion disabled. Measure idle and visible overhead before enabling persistent animation.

## Verification

- `bash -n doctor-checks.sh` and ShellCheck pass; these do not catch the semantic diagnostic bugs above.
- Isolated mocked function calls reproduced the thermal-limit and false-healthy failures. No full machine scan or repair was run.
- Chromium interaction checks passed for the three sample scenarios, domain and finding navigation, scan completion, motion pause and reduced motion. All three pages fit widths of 1440, 1024, 768 and 390 px without document-level horizontal overflow. No JavaScript errors were observed.
- The local GPU summarized Pulse's feature descriptions; design decisions and findings were checked against source.
- Native QML changes, deployment and native performance validation remain future work. This review does not claim that the browser concept is a finished Omarchy plugin.

Tracked in the canonical Omarchy wish list as **OMW-DOCTOR**.
