import Foundation

// Run with:
// swiftc -D WATCH_COMPANION_LOGIC_TEST ios/WordsWatch/WordsWatchApp.swift
//   test/native/watch_companion_logic_test.swift -o /tmp/words-watch-logic
@main
struct WatchCompanionLogicChecks {
  static func main() {
    let now = Date(timeIntervalSince1970: 1000)
    let sample: [String: Any] = ["syncedAt": 997000, "id": "hymn-b", "playing": true,
      "position": 17, "duration": 120]
    precondition(WatchPlaybackSnapshot.elapsed(sample, now: now, connected: true) == 20)
    precondition(WatchPlaybackSnapshot.elapsed(sample, now: now, connected: false) == 17)
    precondition(WatchPlaybackSnapshot.canControl(sample, now: now, connected: true, error: ""))
    precondition(!WatchPlaybackSnapshot.accepts(["syncedAt": 996000, "id": "hymn-a"], after: sample))
    precondition(!WatchPlaybackSnapshot.accepts(["id": "legacy"], after: sample))
    precondition(WatchPlaybackSnapshot.accepts(sample, after: ["syncedAt": 996000]))
    for change: [String: Any] in [["playing": false], ["loading": true], ["error": "Failed"]] {
      let value = sample.merging(change) { _, new in new }
      precondition(WatchPlaybackSnapshot.elapsed(value, now: now, connected: true) == 17)
    }
    for change: [String: Any] in [["loading": true], ["error": "Failed"], ["id": ""], ["syncedAt": 900000]] {
      let value = sample.merging(change) { _, new in new }
      precondition(!WatchPlaybackSnapshot.canControl(value, now: now, connected: true, error: ""))
    }
    precondition(!WatchPlaybackSnapshot.canControl(sample, now: now, connected: true, error: "Phone unavailable"))
    precondition(!WatchPlaybackSnapshot.isFresh(["syncedAt": 1006000], now: now))
    precondition(WatchPlaybackSnapshot.elapsed(sample.merging(["position": 119]) { _, new in new }, now: now, connected: true) == 120)
    precondition(WatchPlaybackSnapshot.clock(3601) == "1:00:01")
    precondition(WatchPlaybackSnapshot.clock(17) == "0:17")
    var proof = WatchConnectionProof()
    let olderRequest = proof.generation
    precondition(proof.canFail(requestGeneration: olderRequest))
    proof.received()
    precondition(!proof.canFail(requestGeneration: olderRequest))
    precondition(proof.canFail(requestGeneration: proof.generation))
    print("Watch snapshot/order checks passed")
  }
}
