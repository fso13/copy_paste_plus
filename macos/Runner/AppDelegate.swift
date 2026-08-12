import Cocoa
import FlutterMacOS
import ServiceManagement
import ApplicationServices

@main
class AppDelegate: FlutterAppDelegate {
    var clipboardTimer: Timer?
    var lastChangeCount: Int = 0
    var eventSink: FlutterEventSink?
    /// Frontmost app captured before our panel becomes active (for auto-paste).
    var previousFrontApp: NSRunningApplication?
    
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
        case "getFrontmostApp":
            result(frontmostAppInfo())
        case "captureFrontmostApp":
            captureFrontmostApp()
            result(nil)
        case "isAccessibilityTrusted":
            result(AXIsProcessTrusted())
        case "requestAccessibility":
            result(requestAccessibilityAccess())
        case "openAccessibilitySettings":
            openAccessibilitySettings()
            result(nil)
        case "pasteToPreviousApp":
            pasteToPreviousApp(result: result)
        case "getLaunchAtLogin":
            result(getLaunchAtLoginStatus())
        case "setLaunchAtLogin":
            if let enabled = call.arguments as? Bool {
                result(setLaunchAtLogin(enabled))
            } else if let args = call.arguments as? [String: Any],
                      let enabled = args["enabled"] as? Bool {
                result(setLaunchAtLogin(enabled))
            } else {
                result(["ok": false, "error": "Invalid arguments"])
            }
        case "listRunningApps":
            result(listRunningApps())
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Frontmost app / accessibility / paste
    
    private func ownBundleId() -> String {
        Bundle.main.bundleIdentifier ?? ""
    }
    
    private func frontmostAppInfo() -> [String: Any] {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return [:]
        }
        return appInfoDict(app)
    }
    
    private func appInfoDict(_ app: NSRunningApplication) -> [String: Any] {
        var info: [String: Any] = [:]
        if let bid = app.bundleIdentifier {
            info["bundleId"] = bid
        }
        if let name = app.localizedName {
            info["name"] = name
        }
        return info
    }
    
    private func captureFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        if app.bundleIdentifier != ownBundleId() {
            previousFrontApp = app
        }
    }
    
    private func requestAccessibilityAccess() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func openAccessibilitySettings() {
        let urlStrings = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.Settings.PrivacySecurity.extension?Privacy_Accessibility",
        ]
        for s in urlStrings {
            if let url = URL(string: s), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
    
    private func pasteToPreviousApp(result: @escaping FlutterResult) {
        guard AXIsProcessTrusted() else {
            result(["ok": false, "error": "accessibility_required"])
            return
        }
        
        let target = previousFrontApp
        DispatchQueue.main.async {
            if let target = target, target.bundleIdentifier != self.ownBundleId() {
                if #available(macOS 14.0, *) {
                    target.activate()
                } else {
                    target.activate(options: [.activateIgnoringOtherApps])
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                let posted = self.simulateCommandV()
                result(["ok": posted])
            }
        }
    }
    
    private func simulateCommandV() -> Bool {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyV: CGKeyCode = 0x09 // kVK_ANSI_V
        
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false) else {
            return false
        }
        
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
    
    private func listRunningApps() -> [[String: Any]] {
        var seen = Set<String>()
        var apps: [[String: Any]] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bid = app.bundleIdentifier,
                  bid != ownBundleId(),
                  !seen.contains(bid) else { continue }
            seen.insert(bid)
            apps.append(appInfoDict(app))
        }
        apps.sort {
            (($0["name"] as? String) ?? "").localizedCaseInsensitiveCompare(
                ($1["name"] as? String) ?? ""
            ) == .orderedAscending
        }
        return apps
    }
    
    // MARK: - Launch at login
    
    private func getLaunchAtLoginStatus() -> [String: Any] {
        if #available(macOS 13.0, *) {
            let status = SMAppService.mainApp.status
            return [
                "ok": true,
                "enabled": status == .enabled,
                "supported": true,
            ]
        }
        return [
            "ok": true,
            "enabled": false,
            "supported": false,
            "error": "Требуется macOS 13 или новее",
        ]
    }
    
    private func setLaunchAtLogin(_ enabled: Bool) -> [String: Any] {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status == .enabled {
                        return ["ok": true, "enabled": true, "supported": true]
                    }
                    try SMAppService.mainApp.register()
                } else {
                    if SMAppService.mainApp.status == .notRegistered {
                        return ["ok": true, "enabled": false, "supported": true]
                    }
                    try SMAppService.mainApp.unregister()
                }
                let nowEnabled = SMAppService.mainApp.status == .enabled
                return ["ok": true, "enabled": nowEnabled, "supported": true]
            } catch {
                return [
                    "ok": false,
                    "enabled": SMAppService.mainApp.status == .enabled,
                    "supported": true,
                    "error": error.localizedDescription,
                ]
            }
        }
        return [
            "ok": false,
            "enabled": false,
            "supported": false,
            "error": "Требуется macOS 13 или новее",
        ]
    }
    
    // MARK: - Clipboard
    
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
        
        // Source app ≈ frontmost at change time (skip ourselves).
        if let app = NSWorkspace.shared.frontmostApplication,
           let bid = app.bundleIdentifier,
           bid != ownBundleId() {
            payload["sourceBundleId"] = bid
            if let name = app.localizedName {
                payload["sourceAppName"] = name
            }
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
