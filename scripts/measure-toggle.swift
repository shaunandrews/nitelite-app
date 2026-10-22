// Records what the screen actually does during a NiteLite toggle.
//
// Presses ⌘⇧D (so NiteLite must be running), then samples the display's average
// brightness every frame with ScreenCaptureKit and prints a compact timeline of
// `ms:brightness` pairs. Use it to tune timing in OverlayAnimationWindow.swift:
// a good toggle goes old value → 0.00 (black) → straight to the new value.
//
//   swiftc -o /tmp/measure-toggle scripts/measure-toggle.swift
//   /tmp/measure-toggle 4      # number of toggles; even ends where you started
//
// Needs Screen Recording and Accessibility permission for your terminal app.

import AppKit
import ScreenCaptureKit
import CoreMedia

func now() -> Double { CFAbsoluteTimeGetCurrent() }
func isDark() -> Bool { UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" }

final class Probe: NSObject, SCStreamOutput {
    var frames: [(Double, Double)] = []
    let lock = NSLock()
    func stream(_ stream: SCStream, didOutputSampleBuffer sb: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pb = sb.imageBuffer else { return }
        let t = now()
        CVPixelBufferLockBaseAddress(pb, .readOnly); defer { CVPixelBufferUnlockBaseAddress(pb, .readOnly) }
        let w = CVPixelBufferGetWidth(pb), h = CVPixelBufferGetHeight(pb), bpr = CVPixelBufferGetBytesPerRow(pb)
        let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: UInt8.self)
        var sum = 0.0, n = 0.0
        for y in stride(from: 0, to: h, by: 2) { for x in stride(from: 0, to: w, by: 2) {
            let p = base + y * bpr + x * 4; sum += (Double(p[0]) + Double(p[1]) + Double(p[2])) / 765; n += 1 } }
        lock.withLock { frames.append((t, sum / n)) }
    }
}
func pressHotkey() {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: src, virtualKey: 2 /* D */, keyDown: down)!
        e.flags = [.maskCommand, .maskShift]
        e.post(tap: .cghidEventTap)
    }
}

let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
let cfg = SCStreamConfiguration()
cfg.width = 160; cfg.height = 100; cfg.pixelFormat = kCVPixelFormatType_32BGRA
cfg.minimumFrameInterval = CMTime(value: 1, timescale: 120); cfg.queueDepth = 8
let stream = SCStream(filter: SCContentFilter(display: content.displays[0], excludingWindows: []), configuration: cfg, delegate: nil)
let probe = Probe()
try stream.addStreamOutput(probe, type: .screen, sampleHandlerQueue: DispatchQueue(label: "p"))
try await stream.startCapture()
try await Task.sleep(nanoseconds: 500_000_000)

let runs = Int(CommandLine.arguments.dropFirst().first ?? "2") ?? 2
for _ in 0..<runs {
    let toDark = !isDark()
    probe.lock.withLock { probe.frames.removeAll() }
    let t0 = now()
    pressHotkey()
    try await Task.sleep(nanoseconds: 2_000_000_000)
    let f = probe.lock.withLock { probe.frames }
    // Collapse into segments of similar luminance so the timeline is readable
    var out: [String] = []; var last = -1.0
    for (t, l) in f where abs(l - last) > 0.02 { out.append("\(Int((t - t0) * 1000)):\(String(format: "%.2f", l))"); last = l }
    print("→ \(toDark ? "dark " : "light"): " + out.joined(separator: " "))
    try await Task.sleep(nanoseconds: 500_000_000)
}
try await stream.stopCapture()
