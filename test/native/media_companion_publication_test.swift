import Foundation

@main
struct CompanionPublicationChecks {
  static func main() {
    let first: [String: Any] = ["id": "ask", "playing": true, "position": 10, "syncedAt": 100000]
    let advance = first.merging(["position": 13, "syncedAt": 103000]) { _, new in new }
    precondition(!CompanionPublicationPolicy.needsImmediateContext(advance, after: first))
    for change: [String: Any] in [["position": 90], ["position": 0], ["playing": false], ["id": "free"], ["locale": "zh-Hans"], ["reading": ["chapter": 2]]] {
      precondition(CompanionPublicationPolicy.needsImmediateContext(advance.merging(change) { _, new in new }, after: first))
    }
    print("Companion immediate seek/state publication checks passed")
  }
}
