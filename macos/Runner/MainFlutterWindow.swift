import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    // Open at the final size, centered, so Dart's later size/center calls
    // don't visibly resize the window.
    var windowFrame = self.frame
    let target = NSSize(width: 1240, height: 820)
    if let screen = self.screen ?? NSScreen.main {
      let area = screen.visibleFrame
      let size = NSSize(
        width: min(target.width, area.width), height: min(target.height, area.height))
      windowFrame = NSRect(
        x: area.midX - size.width / 2, y: area.midY - size.height / 2,
        width: size.width, height: size.height)
    }
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // Keep the window invisible until window_manager's show() runs from Dart,
  // so the empty (black) Flutter view is never on screen.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
