import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    var statusBarItem: NSStatusItem?
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
        // Создание иконки в трее
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem?.button {
            // Создаем простую иконку
            let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
                NSColor.systemBlue.setFill()
                rect.fill()
                return true
            }
            button.image = image
            button.action = #selector(showWindow(_:))
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Показать", action: #selector(showWindow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(quitApp(_:)), keyEquivalent: "q"))
        
        statusBarItem?.menu = menu
        
        // Настройка каналов
        let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
        let clipboardChannel = FlutterMethodChannel(name: "clipboard_manager", binaryMessenger: controller.engine.binaryMessenger)
        let eventChannel = FlutterEventChannel(name: "clipboard_manager/changes", binaryMessenger: controller.engine.binaryMessenger)
        
        clipboardChannel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handleClipboardMethodCall(call: call, result: result)
        }
        
        eventChannel.setStreamHandler(self)
        
        // Запускаем мониторинг буфера обмена
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
        
        // Мониторим буфер обмена каждые 0.5 секунд
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
                // Отправляем изменения через EventChannel
                eventSink?(content)
                print("Native: Clipboard changed: '\(content)'")
            }
        }
    }
    
    @objc func showWindow(_ sender: Any?) {
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc func quitApp(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
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