# Audio mix and companion repair — October 2, 2026

## Report and cause

The owner selected a recording mix while listening to Ask 祈求 and was moved to A Free Man. The phone enabled the mix using any matching song in the entire queue; the handler rebuilt and filtered that queue. Ask had no such recording. This was a confirmed application defect.

The physical Watch report showed a transparent blue SAIL cover against a dark surface and stale phone state. Background application context is not immediate delivery. The old transfer identity also excluded seek discontinuities, and the Watch did not request a new snapshot on each foreground entry.

## Implemented repair

- Current-song mix availability; unsupported mixes are disabled and rejected by the handler. A supported change replaces only the current recording, retains neighbours/order/repeat/shuffle and restores position and paused state. Whole-playlist instrumental filtering stays in playlist and car catalogue selection.
- Bright cover backing, higher-contrast secondary labels and a compact Watch header keep title, transport and progress together. WatchOS uses its own interface appearance; this is not the phone Dark Mode toggle.
- Phone→Watch live messages when reachable plus background application context, immediate pause/track/reading/seek changes, activation/reachability resend, and foreground snapshot refresh. Timestamp guards still reject late replies. Audio continues on the phone.
- Wear publication now detects seeks, retains separate previous/next availability and uses the same bright artwork backing.
- Selecting the already-current recording in a car/watch catalogue resumes without rebuilding the queue or resetting position. CarPlay and Android Auto still use the existing single OS media session.

## Verification and release gates

Focused Dart regressions, native pure logic checks, watch SDK type-check, full suite, real paired simulator UI and signed/native builds are separate checks. Physical Watch and vehicle results must be verified rather than inferred from a green build. This preparation record does not claim a new store delivery. Pending reviews and immutable v1.7.3 packages/tags remain intact.

References: [Watch application context](https://developer.apple.com/documentation/watchconnectivity/wcsession/updateapplicationcontext(_:)), [Reachable session](https://developer.apple.com/documentation/watchconnectivity/wcsession/isreachable), [Apple interface appearance](https://developer.apple.com/design/human-interface-guidelines/dark-mode).
