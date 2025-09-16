import Cocoa
import FlutterMacOS

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Запускаем приложение
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)