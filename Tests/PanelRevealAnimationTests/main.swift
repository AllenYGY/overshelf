import Foundation
import CoreGraphics

func assertClose(_ actual: CGFloat, _ expected: CGFloat, message: String) {
    guard abs(actual - expected) < 0.0001 else {
        fatalError("\(message): expected \(expected), got \(actual)")
    }
}

let opening = PanelRevealAnimation(from: 0, to: 1, reduceMotion: false)
assertClose(opening.duration, 0.24, message: "full opening duration")
assertClose(opening.progress(elapsed: -1), 0, message: "opening progress clamps before start")
assertClose(opening.progress(elapsed: 1), 1, message: "opening progress clamps after completion")

let closing = PanelRevealAnimation(from: 1, to: 0, reduceMotion: false)
assertClose(closing.duration, 0.18, message: "full closing duration")
assertClose(closing.progress(elapsed: 0), 1, message: "closing starts at current progress")
assertClose(closing.progress(elapsed: closing.duration), 0, message: "closing reaches zero")

let reversed = PanelRevealAnimation(from: 0.4, to: 0, reduceMotion: false)
assertClose(reversed.duration, 0.18 * 0.4, message: "reversal duration scales to remaining distance")
assertClose(reversed.progress(elapsed: reversed.duration), 0, message: "reversal reaches its target")

let reduced = PanelRevealAnimation(from: 0, to: 1, reduceMotion: true)
assertClose(reduced.duration, 0.10, message: "reduced-motion duration")
guard reduced.usesReveal == false else {
    fatalError("reduced motion should disable geometric reveal")
}

var lifecycle = PanelRevealState()
lifecycle.startOpening()
lifecycle.update(progress: 0.4)
lifecycle.startClosing()
lifecycle.update(progress: 0.2)
lifecycle.startOpening()
lifecycle.update(progress: 1)
guard lifecycle.isOrderedIn, lifecycle.acceptsMouseEvents else {
    fatalError("show-hide-show reversal should finish visible and interactive")
}
lifecycle.startClosing()
lifecycle.update(progress: 0)
guard lifecycle.isOrderedIn == false, lifecycle.acceptsMouseEvents == false else {
    fatalError("closing should order out only after progress reaches zero")
}

print("Panel reveal animation tests passed")
