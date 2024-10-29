import Cocoa
import FlutterMacOS
import ImageCaptureCore

public class QuickScannerPlusPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "quick_scanner_plus", binaryMessenger: registrar.messenger)
    let instance = QuickScannerPlusPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  private var deviceBrowser: ICDeviceBrowser!
  private var scanners: [(name: String, id: String)] = [] // Change to store tuples of name and ID

  override public init() {
    super.init()
    deviceBrowser = ICDeviceBrowser()
    deviceBrowser.delegate = self
    let mask = ICDeviceTypeMask(rawValue: ICDeviceTypeMask.scanner.rawValue | ICDeviceLocationTypeMask.local.rawValue)
    deviceBrowser.browsedDeviceTypeMask = mask!
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "startWatch":
      deviceBrowser.start()
      result(nil)
    case "stopWatch":
      deviceBrowser.stop()
      result(nil)
    case "getScanners":
      // Return an array of dictionaries with scanner names and IDs
      let scannerList = scanners.map { ["id": $0.id, "name": $0.name] }
      result(scannerList)
    case "scanFile":
      let args = call.arguments as! [String: Any]
      let deviceId = args["deviceId"] as! String
      let directory = args["directory"] as! String
      scanFileResult = result
      scanFile(deviceId, directory: directory)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var scanFileResult: FlutterResult? = nil

  private func scanFile(_ deviceId: String, directory: String) {
    guard let scanner = scanners.first(where: { $0.id == deviceId }) else { return }
    let scannerDevice = scanners.first { $0.id == deviceId }! // Get the scanner object
    scannerDevice.requestOpenSession()
  }

  private func scanFileFlatbed(_ scanner: ICScannerDevice) {
    let functionalUnit = scanner.selectedFunctionalUnit
    let physicalSize = functionalUnit.physicalSize
    functionalUnit.scanArea = NSMakeRect(0, 0, physicalSize.width, physicalSize.height)

    let support1Bit = functionalUnit.supportedBitDepths.contains(Int(ICScannerBitDepth.depth1Bit.rawValue))
    if support1Bit && functionalUnit.supportedBitDepths.count == 1 {
      functionalUnit.pixelDataType = .BW
      functionalUnit.bitDepth = .depth1Bit
    } else {
      // TODO other mode
      functionalUnit.pixelDataType = .RGB
      functionalUnit.bitDepth = .depth8Bits
    }

    scanner.requestScan()
  }
}

extension QuickScannerPlusPlugin: ICDeviceBrowserDelegate {
  public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
    print("deviceBrowser:\(browser) didAdd:\(device.uuidString) moreComing:\(moreComing)")
    if let scanner = device as? ICScannerDevice, !scanners.contains(where: { $0.id == scanner.uuidString }) {
      let scannerName = scanner.name // Get the scanner name
      scanners.append((name: scannerName, id: scanner.uuidString))
    }
  }

  public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
    print("deviceBrowser:\(browser) didRemove:\(device.uuidString) moreGoing:\(moreGoing)")
    scanners.removeAll { $0.id == device.uuidString }
  }
}

extension QuickScannerPlusPlugin: ICDeviceDelegate {
  public func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
    print("device:\(device.uuidString) didOpenSessionWithError:\(error)")
  }

  public func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
    print("device:\(device.uuidString) didCloseSessionWithError:\(error)")
  }

  public func didRemove(_ device: ICDevice) {
    print("didRemove:\(device.uuidString)")
  }

  public func deviceDidBecomeReady(_ device: ICDevice) {
    print("deviceDidBecomeReady:\(device.uuidString)")
    let scanner = device as! ICScannerDevice
    let supportDocumentFeeder = scanner.availableFunctionalUnitTypes.contains(ICScannerFunctionalUnitType.documentFeeder.rawValue as NSNumber)
    if supportDocumentFeeder {
      // TODO
    }
    scanner.requestSelect(.flatbed)
  }
}

extension QuickScannerPlusPlugin: ICScannerDeviceDelegate {
  public func scannerDeviceDidBecomeAvailable(_ scanner: ICScannerDevice) {
    print("scannerDeviceDidBecomeAvailable:\(scanner.uuidString)")
  }

  public func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
    print("scannerDevice:\(scanner.uuidString) didSelectFunctionalUnit:\(functionalUnit) error:\(error)")
    if functionalUnit.type == .flatbed {
      scanFileFlatbed(scanner)
    }
  }

  public func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
    print("scannerDevice:\(scanner.uuidString) didScanTo:\(url)")
    scanFileResult?(url.path)
    scanFileResult = nil
  }

  public func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
    print("scannerDevice:\(scanner.uuidString) didCompleteScanWithError:\(error)")
    if let e = error {
      scanFileResult?(FlutterError(code: "ScanError", message: e.localizedDescription, details: nil))
      scanFileResult = nil
    }
    scanner.requestCloseSession()
  }
}
