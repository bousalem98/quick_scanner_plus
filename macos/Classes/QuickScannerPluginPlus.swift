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
    private var scanners: [(name: String, id: String)] = []
    private var scannerDevices: [ICScannerDevice] = []

    override public init() {
        super.init()
        deviceBrowser = ICDeviceBrowser()
        deviceBrowser.delegate = self
        deviceBrowser.browsedDeviceTypeMask = ICDeviceTypeMask(rawValue: (ICDeviceTypeMask.scanner.rawValue | ICDeviceLocationTypeMask.local.rawValue)) ?? ICDeviceTypeMask()
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
            let scannerList = scanners.map { ["id": $0.id, "name": $0.name] }
            result(scannerList)
        case "scanFile":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String,
                  let directory = args["directory"] as? String else {
                result(FlutterError(code: "InvalidArguments", message: "Invalid arguments provided", details: nil))
                return
            }
            scanFileResult = result
            scanFile(deviceId, directory: directory)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private var scanFileResult: FlutterResult? = nil

    private func scanFile(_ deviceId: String, directory: String) {
        guard let scannerDevice = scannerDevices.first(where: { $0.uuidString == deviceId }) else {
            scanFileResult?(FlutterError(code: "DeviceNotFound", message: "Scanner not found", details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Directly set the delegate and transfer mode
            scannerDevice.delegate = self
            scannerDevice.transferMode = .fileBased
            scannerDevice.downloadsDirectory = URL(fileURLWithPath: directory)

            // Open session without try, as it doesn't throw errors
            scannerDevice.requestOpenSession()

            // Switch to the main thread to handle available scan sources
            DispatchQueue.main.async {
                self.handleAvailableScanSources(scannerDevice)
            }
        }
    }

    private func handleAvailableScanSources(_ scanner: ICScannerDevice) {
        // No need to cast availableFunctionalUnitTypes, it's already of type [NSNumber]
        let functionalUnitTypes = scanner.availableFunctionalUnitTypes

        if functionalUnitTypes.contains(NSNumber(value: ICScannerFunctionalUnitType.documentFeeder.rawValue)) {
            scanner.requestSelect(.documentFeeder)
        } else if functionalUnitTypes.contains(NSNumber(value: ICScannerFunctionalUnitType.flatbed.rawValue)) {
            scanner.requestSelect(.flatbed)
        } else {
            scanFileResult?(FlutterError(code: "UnsupportedScanSource", message: "No supported scan source found", details: nil))
            scanFileResult = nil
        }
    }

    private func configureAndStartScan(for functionalUnit: ICScannerFunctionalUnit, scanner: ICScannerDevice) {
        let physicalSize = functionalUnit.physicalSize
        functionalUnit.scanArea = NSMakeRect(0, 0, physicalSize.width, physicalSize.height)

        if functionalUnit.supportedBitDepths.contains(Int(ICScannerBitDepth.depth8Bits.rawValue)) {
            functionalUnit.pixelDataType = .RGB
            functionalUnit.bitDepth = .depth8Bits
        } else {
            functionalUnit.pixelDataType = .BW
            functionalUnit.bitDepth = .depth1Bit
        }

        scanner.requestScan()
    }
}

extension QuickScannerPlusPlugin: ICDeviceBrowserDelegate {
    public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        if let scanner = device as? ICScannerDevice,
           !scannerDevices.contains(where: { $0.uuidString == scanner.uuidString }) {
            scannerDevices.append(scanner)
            scanners.append((name: scanner.name ?? "Unknown Scanner", id: scanner.uuidString ?? "Unknown ID"))
        }
    }

    public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        if let uuid = device.uuidString {
            scanners.removeAll { $0.id == uuid }
            scannerDevices.removeAll { $0.uuidString == uuid }
        }
    }
}

extension QuickScannerPlusPlugin: ICDeviceDelegate {
    public func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        print("Session opened for device: \(device.uuidString ?? "Unknown UUID")")
    }

    public func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        print("Session closed for device: \(device.uuidString ?? "Unknown UUID")")
    }

    public func didRemove(_ device: ICDevice) {
        print("Device removed: \(device.uuidString ?? "Unknown UUID")")
    }

    public func deviceDidBecomeReady(_ device: ICDevice) {
        print("Device is ready: \(device.uuidString ?? "Unknown UUID")")
    }
}

extension QuickScannerPlusPlugin: ICScannerDeviceDelegate {
    public func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        if let e = error {
            scanFileResult?(FlutterError(code: "SelectUnitError", message: e.localizedDescription, details: nil))
            scanFileResult = nil
        } else {
            configureAndStartScan(for: functionalUnit, scanner: scanner)
        }
    }

    public func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
        scanFileResult?(url.path)
        scanFileResult = nil
    }

    public func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
        if let e = error {
            scanFileResult?(FlutterError(code: "ScanError", message: e.localizedDescription, details: nil))
        }
        scanFileResult = nil
        scanner.requestCloseSession()
    }
}
