# Kimi3 advisory review — final implementation

Reviewed with `kimi-coding/k3`; completed model metadata and the unmodified advisory report are in [metadata](kimi-final-metadata.json) and [report](kimi-final-review.txt). Source was shared under Fred's explicit authorization. Findings were checked independently.

| Finding | Decision and delivered response |
| --- | --- |
| Cancel leaves the deadline armed | Rejected: `abortScan()` already calls `deadline.stop()`. |
| Quick/deep skipped checks produce misleading changes | Accepted: transitions involving `skipped` are labeled “not measured”/“measured” and excluded from the change list. Regression test passes. |
| Cancelled scans are saved and restored complete | Claimed save path rejected: cancellation returns before saving. Hardened restore anyway: archive completeness is derived from the exact expected check IDs and count, and the UI honors it. Backend and native tests verify partial archives remain incomplete. |
| Activation failure loses install receipt | Accepted: installation writes a recovery receipt before activation, records activation failures, and returns a failure status. Regression test passes. |
| Live readings are emitted before persistence and lost on reload | Claimed ordering rejected: persistence precedes emission. A delayed history response can nevertheless miss newer observations, so the UI now merges newer samples, ignores obsolete range responses, and queues another history request when needed. Native merge/range tests pass. |

The original 0.1 review is retained under `review/`; its baseline defects are addressed by the replacement collector and native UI. No machine findings were automatically repaired.
