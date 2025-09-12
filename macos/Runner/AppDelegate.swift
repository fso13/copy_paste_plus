import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    var statusBarItem: NSStatusItem?
    
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
            button.image = NSImage(named: "AppIcon")
            button.action = #selector(showWindow(_:))
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Показать", action: #selector(showWindow(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Выход", action: #selector(quitApp(_:)), keyEquivalent: "q"))
        
        statusBarItem?.menu = menu
        
        super.applicationDidFinishLaunching(notification)
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