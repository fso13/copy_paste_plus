import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    var clipboardTimer: Timer?
    var lastChangeCount: Int = 0
    var eventSink: FlutterEventSink?
    
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
    
    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        // Tray icon is owned by Flutter `system_tray` — do not create a second NSStatusItem here.

        // Настройка каналов буфера обмена
        if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
            let clipboardChannel = FlutterMethodChannel(
                name: "clipboard_manager",
                binaryMessenger: controller.engine.binaryMessenger
            )
            let eventChannel = FlutterEventChannel(
                name: "clipboard_manager/changes",
                binaryMessenger: controller.engine.binaryMessenger
            )
            
            clipboardChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                self?.handleClipboardMethodCall(call: call, result: result)
            }
            
            eventChannel.setStreamHandler(self)
        }
        
        startClipboardMonitoring()
        
        super.applicationDidFinishLaunching(notification)
    }
    
    private func handleClipboardMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getClipboardContent":
            result(getClipboardPayload())
        case "setClipboardContent":
            if let arguments = call.arguments as? [String: Any],
               let content = arguments["content"] as? String {
                let html = arguments["html"] as? String
                let rtf = arguments["rtf"] as? String
                result(setClipboardContent(plain: content, html: html, rtf: rtf))
            } else {
                result(false)
            }
        case "getChangeCount":
            result(getChangeCount())
        case "startMonitoring":
            startClipboardMonitoring()
            result(nil)
        case "stopMonitoring":
            stopClipboardMonitoring()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    /// Reads plain text plus optional rich formats (HTML / RTF).
    /// Destination apps pick what they support: Word uses RTF/HTML, plain fields use text.
    private func getClipboardPayload() -> [String: Any] {
        let pasteboard = NSPasteboard.general
        var payload: [String: Any] = [:]
        
        let plain = pasteboard.string(forType: .string) ?? ""
        payload["content"] = plain
        
        var html = readHtml(from: pasteboard)
        var rtf = readRtf(from: pasteboard)
        
        // Fallback: derive HTML/RTF from attributed string (IDE / Cocoa sources)
        if (html == nil || rtf == nil),
           let attributed = readAttributedString(from: pasteboard) {
            if html == nil {
                html = htmlString(from: attributed)
            }
            if rtf == nil {
                rtf = rtfString(from: attributed)
            }
            if plain.isEmpty {
                payload["content"] = attributed.string
            }
        }
        
        if let html = html, !html.isEmpty {
            payload["html"] = html
        }
        if let rtf = rtf, !rtf.isEmpty {
            payload["rtf"] = rtf
        }
        
        print("Native: Clipboard payload plain=\((payload["content"] as? String)?.count ?? 0) html=\((payload["html"] as? String)?.count ?? 0) rtf=\((payload["rtf"] as? String)?.count ?? 0)")
        return payload
    }
    
    private func readHtml(from pasteboard: NSPasteboard) -> String? {
        if let html = pasteboard.string(forType: .html), !html.isEmpty {
            return html
        }
        // Some apps provide HTML only as raw data
        if let data = pasteboard.data(forType: .html),
           let html = String(data: data, encoding: .utf8), !html.isEmpty {
            return html
        }
        return nil
    }
    
    private func readRtf(from pasteboard: NSPasteboard) -> String? {
        if let data = pasteboard.data(forType: .rtf),
           let rtf = String(data: data, encoding: .utf8), !rtf.isEmpty {
            return rtf
        }
        if let rtf = pasteboard.string(forType: .rtf), !rtf.isEmpty {
            return rtf
        }
        return nil
    }
    
    private func readAttributedString(from pasteboard: NSPasteboard) -> NSAttributedString? {
        guard let objects = pasteboard.readObjects(
            forClasses: [NSAttributedString.self],
            options: nil
        ),
              let attributed = objects.first as? NSAttributedString,
              attributed.length > 0 else {
            return nil
        }
        return attributed
    }
    
    private func htmlString(from attributed: NSAttributedString) -> String? {
        let range = NSRange(location: 0, length: attributed.length)
        guard let data = try? attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]
        ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    private func rtfString(from attributed: NSAttributedString) -> String? {
        let range = NSRange(location: 0, length: attributed.length)
        guard let data = try? attributed.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    private func setClipboardContent(plain: String, html: String?, rtf: String?) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        var wrote = pasteboard.setString(plain, forType: .string)
        
        if let html = html, !html.isEmpty {
            // Write both string and data forms for broader app compatibility
            if pasteboard.setString(html, forType: .html) {
                wrote = true
            }
            if let data = html.data(using: .utf8) {
                pasteboard.setData(data, forType: .html)
            }
        }
        
        if let rtf = rtf, !rtf.isEmpty, let data = rtf.data(using: .utf8) {
            if pasteboard.setData(data, forType: .rtf) {
                wrote = true
            }
        }
        
        return wrote
    }
    
    private func getChangeCount() -> Int {
        return NSPasteboard.general.changeCount
    }
    
    private func startClipboardMonitoring() {
        stopClipboardMonitoring()
        lastChangeCount = NSPasteboard.general.changeCount
        
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardChanges()
        }
        
        print("Native: Clipboard monitoring started")
    }
    
    private func stopClipboardMonitoring() {
        clipboardTimer?.invalidate()
        clipboardTimer = nil
    }
    
    private func checkClipboardChanges() {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            
            let payload = getClipboardPayload()
            let content = payload["content"] as? String ?? ""
            if !content.isEmpty {
                eventSink?(payload)
                print("Native: Clipboard changed: '\(content.prefix(80))'")
            }
        }
    }
}

// MARK: - FlutterStreamHandler
extension AppDelegate: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
