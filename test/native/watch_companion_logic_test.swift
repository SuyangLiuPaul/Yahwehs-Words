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

    // The theme follows the phone: no accent keeps the original blue, a colour
    // moves the whole palette, and a deep colour is lifted to stay legible.
    precondition(WatchThemePalette.from([:]) == WatchThemePalette.original)
    let red = WatchThemePalette.from(["accent": NSNumber(value: 0xFFF44336 as UInt32)])
    precondition(red.accent.r > red.accent.b && red.accent.r > 0.9, "red stays red")
    precondition(red != WatchThemePalette.original)
    let navy = WatchThemePalette.from(["accent": NSNumber(value: 0xFF0D1B4F as UInt32)])
    let navyLuminance = 0.2126 * navy.accent.r + 0.7152 * navy.accent.g + 0.0722 * navy.accent.b
    precondition(navyLuminance >= 0.44, "a dark theme colour is lifted for a dark screen")
    precondition(navy.accent.b > navy.accent.r, "…and keeps its hue")
    precondition(red.surface.r < 0.35 && red.page.r < 0.2, "surfaces stay dark")
    precondition(WatchThemePalette.logoName(["logo": "Red"]) == "LogoRed")
    precondition(WatchThemePalette.logoName([:]) == "LogoDefault")
    precondition(WatchThemePalette.logoName(["logo": "../../etc"]) == "LogoDefault", "an unknown variant never names an asset")
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
