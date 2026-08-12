import Cocoa
import FlutterMacOS
import ServiceManagement
import ApplicationServices
import CryptoKit
import Security

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
        case "encryptString":
            if let args = call.arguments as? [String: Any],
               let plain = args["text"] as? String {
                result(encryptString(plain))
            } else {
                result(["ok": false, "error": "Invalid arguments"])
            }
        case "decryptString":
            if let args = call.arguments as? [String: Any],
               let cipher = args["text"] as? String {
                result(decryptString(cipher))
            } else {
                result(["ok": false, "error": "Invalid arguments"])
            }
        case "setClipboardImage":
            if let args = call.arguments as? [String: Any],
               let path = args["path"] as? String {
                result(setClipboardImage(path: path))
            } else {
                result(false)
            }
        case "imagesDirectory":
            result(imagesDirectoryPath())
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
        
        // Image (PNG) — store under Application Support and pass path.
        if let imagePath = persistPasteboardImageIfNeeded() {
            payload["imagePath"] = imagePath
            if (payload["content"] as? String ?? "").isEmpty {
                payload["content"] = "[image]"
            }
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
        
        print("Native: Clipboard payload plain=\((payload["content"] as? String)?.count ?? 0) html=\((payload["html"] as? String)?.count ?? 0) rtf=\((payload["rtf"] as? String)?.count ?? 0) image=\(payload["imagePath"] != nil)")
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
            let hasImage = (payload["imagePath"] as? String)?.isEmpty == false
            if !content.isEmpty || hasImage {
                eventSink?(payload)
                print("Native: Clipboard changed: '\(content.prefix(80))' image=\(hasImage)")
            }
        }
    }
    
    // MARK: - Images
    
    private func imagesDirectoryPath() -> String {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("CopyPastePlus/images", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }
    
    private func persistPasteboardImageIfNeeded() -> String? {
        let pasteboard = NSPasteboard.general
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        
        let dir = URL(fileURLWithPath: imagesDirectoryPath(), isDirectory: true)
        let filename = "img_\(Int(Date().timeIntervalSince1970 * 1000))_\(UUID().uuidString.prefix(8)).png"
        let fileURL = dir.appendingPathComponent(filename)
        do {
            try png.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Native: failed to save image: \(error)")
            return nil
        }
    }
    
    private func setClipboardImage(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let image = NSImage(contentsOf: url) else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }
    
    // MARK: - Encryption (AES-GCM + Keychain key)
    
    private let keychainService = "com.fso13.copyPastePlus"
    private let keychainAccount = "history_aes_key"
    
    private func encryptString(_ plain: String) -> [String: Any] {
        do {
            let key = try loadOrCreateSymmetricKey()
            let data = Data(plain.utf8)
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else {
                return ["ok": false, "error": "seal failed"]
            }
            return ["ok": true, "text": combined.base64EncodedString()]
        } catch {
            return ["ok": false, "error": error.localizedDescription]
        }
    }
    
    private func decryptString(_ cipher: String) -> [String: Any] {
        do {
            let key = try loadOrCreateSymmetricKey()
            guard let data = Data(base64Encoded: cipher) else {
                return ["ok": false, "error": "invalid base64"]
            }
            let box = try AES.GCM.SealedBox(combined: data)
            let plain = try AES.GCM.open(box, using: key)
            guard let text = String(data: plain, encoding: .utf8) else {
                return ["ok": false, "error": "utf8 decode failed"]
            }
            return ["ok": true, "text": text]
        } catch {
            return ["ok": false, "error": error.localizedDescription]
        }
    }
    
    private func loadOrCreateSymmetricKey() throws -> SymmetricKey {
        if let existing = readKeychainKey() {
            return SymmetricKey(data: existing)
        }
        let key = SymmetricKey(size: .bits256)
        let raw = key.withUnsafeBytes { Data($0) }
        try saveKeychainKey(raw)
        return key
    }
    
    private func readKeychainKey() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }
    
    private func saveKeychainKey(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
        
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
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
