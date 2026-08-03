import Foundation
import Cocoa
import WebKit

func fail(_ message: String) -> Never {
    fputs("MARKDOWN PREVIEW TEST FAIL: \(message)\n", stderr)
    exit(1)
}

guard let resourceDir = ProcessInfo.processInfo.environment["DROPSHELF_MARKDOWN_DIR"] else {
    fail("DROPSHELF_MARKDOWN_DIR is missing")
}

let requiredFiles = [
    "markdown.html",
    "markdown-it/markdown-it.min.js",
    "dompurify/purify.min.js",
    "katex/katex.min.js",
    "katex/auto-render.min.js",
    "katex/katex.min.css",
    "katex/fonts/KaTeX_Main-Regular.woff2"
]

for relative in requiredFiles {
    let path = resourceDir + "/" + relative
    guard FileManager.default.fileExists(atPath: path) else {
        fail("missing resource \(relative)")
    }
}

let htmlURL = URL(fileURLWithPath: resourceDir + "/markdown.html")
let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())

final class Delegate: NSObject, WKNavigationDelegate {
    var didFinish = false
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didFinish = true
    }
}

let delegate = Delegate()
webView.navigationDelegate = delegate
webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())

let deadline = Date().addingTimeInterval(10)
while !delegate.didFinish && Date() < deadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}
guard delegate.didFinish else {
    fail("markdown.html did not finish loading")
}

let sampleMarkdown = """
# Title One
## Subtitle Two
### Subsubtitle Three

$$x = \\frac{-b \\pm \\sqrt{b^2 - 4ac}}{2a}$$

Inline \\( e^{i\\pi} + 1 = 0 \\)

- item one
- item two

Use `dropShelf()` inline.
"""

guard let bodyData = try? JSONSerialization.data(withJSONObject: [sampleMarkdown]),
      let bodyJson = String(data: bodyData, encoding: .utf8) else {
    fail("could not encode markdown")
}
let escapedBody = bodyJson.dropFirst().dropLast()

var renderDone = false
webView.evaluateJavaScript("renderMarkdown(\(escapedBody), true);") { _, _ in
    renderDone = true
}
while !renderDone && Date() < deadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}
guard renderDone else {
    fail("renderMarkdown did not complete")
}

RunLoop.current.run(until: Date().addingTimeInterval(0.3))

var checkDone = false
var result: String?
webView.evaluateJavaScript("""
    (document.querySelectorAll('h1, h2, h3').length)
    + '|' + document.querySelectorAll('.katex').length
    + '|' + (document.querySelector('h1') ? document.querySelector('h1').textContent : '')
    + '|' + (document.querySelector('h2') ? document.querySelector('h2').textContent : '')
    + '|' + (document.querySelector('h3') ? document.querySelector('h3').textContent : '')
    + '|' + document.querySelectorAll('.katex-display').length
    + '|' + document.querySelectorAll('ul li').length
    + '|' + document.querySelectorAll('code').length
    + '|' + (typeof window.markdownit === 'function' ? '1' : '0')
    + '|' + (typeof DOMPurify !== 'undefined' ? '1' : '0')
    + '|' + parseFloat(getComputedStyle(document.querySelector('h1')).fontSize)
    + '|' + parseFloat(getComputedStyle(document.querySelector('h2')).fontSize)
    + '|' + parseFloat(getComputedStyle(document.querySelector('h3')).fontSize)
    + '|' + (document.body.innerText.includes('$$') ? '0' : '1')
""") { value, _ in
    result = value as? String
    checkDone = true
}
while !checkDone && Date() < deadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}
guard let result else {
    fail("DOM check did not complete")
}

let parts = result.components(separatedBy: "|")
guard parts.count == 14,
      parts[0] == "3",
      parts[1] == "2",
      parts[2] == "Title One",
      parts[3] == "Subtitle Two",
      parts[4] == "Subsubtitle Three",
      parts[5] == "1",
      parts[6] == "2",
      parts[7] == "1",
      parts[8] == "1",
      parts[9] == "1",
      let h1Size = Double(parts[10]),
      let h2Size = Double(parts[11]),
      let h3Size = Double(parts[12]),
      h1Size > h2Size,
      h2Size > h3Size,
      parts[13] == "1" else {
    fail("unexpected DOM result: \(result)")
}

let secondMarkdown = "## Updated\n\nInline \\(x^2\\)"
guard let secondData = try? JSONSerialization.data(withJSONObject: [secondMarkdown]),
      let secondJson = String(data: secondData, encoding: .utf8) else {
    fail("could not encode second markdown")
}
let escapedSecond = secondJson.dropFirst().dropLast()

var render2Done = false
webView.evaluateJavaScript("renderMarkdown(\(escapedSecond), true);") { _, _ in
    render2Done = true
}
while !render2Done && Date() < deadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}
guard render2Done else {
    fail("second renderMarkdown did not complete")
}

RunLoop.current.run(until: Date().addingTimeInterval(0.3))

var check2Done = false
var result2: String?
webView.evaluateJavaScript("""
    (document.querySelectorAll('h1').length)
    + '|' + (document.querySelectorAll('h2').length)
    + '|' + document.querySelectorAll('.katex').length
    + '|' + (document.querySelector('h2') ? document.querySelector('h2').textContent : '')
""") { value, _ in
    result2 = value as? String
    check2Done = true
}
while !check2Done && Date() < deadline {
    RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
}
guard let result2 else {
    fail("second DOM check did not complete")
}
guard result2 == "0|1|1|Updated" else {
    fail("markdown preview did not update: \(result2)")
}

print("Markdown preview test passed: \(result)")
