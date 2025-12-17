import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.minSize = NSSize(width: 900, height: 700)
    self.setContentSize(NSSize(width: 1200, height: 800))

    super.awakeFromNib()
  }

  // Override to prevent system beep
  override func keyDown(with event: NSEvent) {
    // Don't call super to prevent beep
    self.contentViewController?.keyDown(with: event)
}
}