# Kimi3 bug review and engineering decisions

> Historical 0.1 review. The native 1.0 implementation is now built, installed and verified. See the [delivery record](../verification/README.md) and [final Kimi3 decisions](../verification/KIMI-DECISIONS.md). Statements below about pending work describe the earlier review date.

Completed 2026-09-30 (America/New_York). Reviewer: configured `kimi-coding/k3`, tools disabled. [Completed Kimi3 report](kimi3-raw.txt) · [Model metadata](kimi3-metadata.json) · [Reviewed file hashes](input-hashes.json).

Kimi3's output is advisory. The decisions below come from source inspection and independent reproductions. No production source or prototype behavior was changed. Fixes remain pending.

## Decisions on Kimi3's findings

| Kimi finding | Decision | Evidence and correction |
| --- | --- | --- |
| 1. Temperature limits treated as current readings | Accept, high priority | Mocked current 48°C / critical 100°C produces a critical 100°C finding. Parse temperature input fields separately from limits; do not use Kimi's vague text-regex fallback. |
| 2. Failed probes reported healthy | Accept, high priority | Reproduced for systemctl, journalctl, pacman and coredumpctl. Preserve exit status and represent unavailable evidence explicitly. Kimi's package-database-lock example is not established by these tests and is unnecessary to the finding. |
| 3. Unknown-only or interrupted scans report all clear | Accept; raise to high priority | Actual isolated Quickshell instance: an info-only row shows `ok`, `All systems healthy`, zero healthy checks. A fake collector emitting one healthy row and exiting 7 produces the same all-clear label. |
| 4. No deadlines; a blocked command prevents completion | Accept mechanism, medium priority | Collector has no probe deadlines; UI guards all refreshes while the process is running and buffers output until completion. Specific real hardware hangs were not induced. Bound each probe and mark incomplete results. |
| 5. First disk mislabeled as primary | Accept, medium priority | Source selects the first `lsblk` disk independently of `/`. Resolve physical backing devices or label every inspected drive. A single parent lookup is insufficient for all encrypted/RAID/Btrfs arrangements. |
| 6. Pause classes become permanently desynchronized | Reject | `classList.toggle('paused', document.hidden)` explicitly removes the HTML class when visible. Browser test confirmed hidden pause, visible resume, manual pause preservation and successful manual resume. Separate classes intentionally represent separate reasons to pause. |
| 7. Hardcoded keyboard scroll stride | Accept arithmetic concern; visual impact pending | Actual row height follows wrapped content while scrolling assumes a constant 76px. Use delegate geometry. Kimi's extra wording about never scrolling upward correctly is too broad; do not treat every navigation case as broken. |

## Additional findings and disagreements

- **High: Doctor exposes no preferred bar size.** The actual `qs.Ui.Panel` is an Item with no default sizing, and Doctor never binds its implicit dimensions to its `BarIconButton`. An isolated native load reported width, height and both implicit dimensions as zero. The installed bar allocates its slot from the active item's implicit dimensions (`nixfred.menubar-overload/Bar.qml:2363`); Pulse and stock panels explicitly forward the button dimensions. Add those bindings before relying on bar interaction.
- **Medium: benign QML messages count as shell warnings.** A mocked `quickshell: loaded Main.qml successfully` log line is classified as a warning because `check_shell` matches `qml` as an error term. Filter by meaningful severity/error information, not a file extension.
- **Unknown NVIDIA readings count as healthy.** A mocked N/A temperature/load/memory response emits `ok`. Driver responsiveness and missing sensor data should be separate facts.
- **Kimi's blanket numeric-fallback safety claim is incorrect.** A mocked nonnumeric memory value aborts the collector with `garbage: unbound variable`. This is a robustness finding, not a claim that normal Linux `/proc/meminfo` routinely contains invalid values. Battery numeric fields also lack explicit format validation in source.
- **User services remain a coverage gap worth addressing.** I accept Kimi's distinction that the code performs the system-unit query it implements. However, an Omarchy health dashboard should identify the scope checked and cover user services before implying overall desktop health.
- **Command quoting:** agree that the copy operation passes the command as data and `shellQuote` escapes embedded quotes. The terminal helper currently has no callers. No speculative command-injection finding is accepted.
- **Protocol wording:** Kimi's statement that command tabs survive the round trip is inaccurate: `emit` replaces them with spaces first. This is not an additional actionable bug for the current hardcoded commands.

## Verification

- [Seven collector reproductions](reproductions.json), run with [verify-findings.py](verify-findings.py). These use fake probe functions and do not run a full machine scan. Assertions document existing defects; they are not passing correctness tests.
- [Native QML results](native-check.txt): temporary copy loaded against the installed Omarchy Ui/Commons components in a separate Quickshell process, with IPC disabled and panel closed. It exits automatically. A temporary collector prints one sample row and exits 7. [Harness](native-harness.qml) records the state checks; its temporary Doctor copy redirects `scriptPath()` to that fixture.
- [Pause-motion verdict](motion-verdict.json), tested with [verify-motion.cjs](verify-motion.cjs). The test simulates visibility events and inspects effective CSS animation state; it does not claim to test every browser's background-tab scheduling.
- [Numeric fallback reproduction](numeric-fallback.json).
- Existing collector syntax and ShellCheck passed in the initial review. No full visual validation of the native popup or native performance test was performed.
- All reviewed file hashes matched at the end of validation. Only review artifacts were added in this follow-up; no installation, restart or repair was performed on the live plugin.

## Recommended order

1. Restore the bar's preferred dimensions and make unavailable/partial scan states honest.
2. Fix temperature parsing, probe error handling and timeouts.
3. Correct drive coverage and shell-log classification, then keyboard scrolling.
4. Proceed with the Pulse-inspired graphical redesign using trustworthy structured data.

Tracked as **OMW-DOCTOR** in `/home/pi/Omarchy-To-Do-Wish-List.md`. Fred's standing authorization for explicitly requested Kimi3 reviews is saved in `/home/pi/AGENTS.md`.
