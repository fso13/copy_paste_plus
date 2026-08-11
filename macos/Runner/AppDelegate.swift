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
            result(getClipboardContent())
        case "setClipboardContent":
            if let arguments = call.arguments as? [String: Any],
               let content = arguments["content"] as? String {
                result(setClipboardContent(content))
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
    
    private func getClipboardContent() -> String {
        let pasteboard = NSPasteboard.general
        let content = pasteboard.string(forType: .string) ?? ""
        print("Native: Clipboard content: '\(content)'")
        return content
    }
    
    private func setClipboardContent(_ content: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(content, forType: .string)
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
            
            let content = getClipboardContent()
            if !content.isEmpty {
                eventSink?(content)
                print("Native: Clipboard changed: '\(content)'")
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
