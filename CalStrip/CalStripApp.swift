import SwiftUI
import AppKit
internal import UniformTypeIdentifiers

@main
struct CalStripApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Empty settings scene prevents a blank window from opening on launch
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            processICSFile(at: url)
        }
        // Quit cleanly after handing off to Apple Calendar
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If launched manually without a file (e.g., double-clicked in Applications), open a file picker
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if NSApp.windows.isEmpty {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.init(filenameExtension: "ics")!]
                panel.allowsMultipleSelection = true
                panel.message = "Select .ics files to clean and import into Calendar"
                
                if panel.runModal() == .OK {
                    for url in panel.urls {
                        self.processICSFile(at: url)
                    }
                }
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func processICSFile(at url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let rawContent = try? String(contentsOf: url, encoding: .utf8) else { return }

        // 1. Normalize CRLF and unfold multi-line iCal properties (lines starting with space/tab)
        let normalized = rawContent.replacingOccurrences(of: "\r\n", with: "\n")
        let unfolded = normalized.replacingOccurrences(of: "\n[ \\t]", with: "", options: .regularExpression)
        let lines = unfolded.components(separatedBy: "\n")

        let stripPrefixes = [
            "ORGANIZER",
            "ATTENDEE",
            "URL:",
            "UID:",
            "X-MICROSOFT-DISALLOW-COUNTER"
        ]

        var cleanedLines: [String] = []

        for line in lines {
            if stripPrefixes.contains(where: { line.hasPrefix($0) }) {
                continue
            } else if line.hasPrefix("METHOD:REQUEST") {
                cleanedLines.append("METHOD:PUBLISH")
            } else if line.hasPrefix("DTSTART") || line.hasPrefix("DTEND") {
                cleanedLines.append(convertDateTimeLine(line))
            } else {
                cleanedLines.append(line)
            }
        }

        // 2. Write to standard sandboxed temporary directory (always permitted)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanEvent_\(UUID().uuidString).ics")

        do {
            try cleanedLines.joined(separator: "\r\n").write(to: tempURL, atomically: true, encoding: .utf8)

            // 3. Hand off to Calendar via macOS /usr/bin/open (transfers sandbox file access cleanly)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", "Calendar", tempURL.path]
            try task.run()
            task.waitUntilExit()
        } catch {
            print("Failed to process cleaned ICS: \(error)")
        }
    }

    private func convertDateTimeLine(_ line: String) -> String {
        // Matches DTSTART or DTEND with optional TZID and timestamp
        let pattern = #"^(DTSTART|DTEND)(?:;TZID=([^:;]+))?(?:;[^:]+)?:(\d{8}T\d{6})(Z?)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return line
        }

        func group(_ idx: Int) -> String? {
            guard let range = Range(match.range(at: idx), in: line) else { return nil }
            return String(line[range])
        }

        guard let prop = group(1), let dtStr = group(3) else { return line }
        let tzid = group(2)?.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let isUTC = group(4) == "Z"

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyyMMdd'T'HHmmss"

        if isUTC {
            parser.timeZone = TimeZone(secondsFromGMT: 0)
        } else if let tzid = tzid, let sourceTZ = TimeZone(identifier: tzid) {
            parser.timeZone = sourceTZ
        } else {
            // Floating time (already local) or unrecognized TZID
            return line
        }

        guard let date = parser.date(from: dtStr) else { return line }

        // Format into the Mac's current local timezone
        let localFormatter = DateFormatter()
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        localFormatter.timeZone = TimeZone.current

        return "\(prop):\(localFormatter.string(from: date))"
    }
}
