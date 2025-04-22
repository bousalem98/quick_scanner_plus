import Cocoa
import FlutterMacOS
import ImageCaptureCore

public class QuickScannerPlusPlugin: NSObject, FlutterPlugin, ICDeviceBrowserDelegate, ICDeviceDelegate, ICScannerDeviceDelegate {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "quick_scanner_plus", binaryMessenger: registrar.messenger)
        let instance = QuickScannerPlusPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var deviceBrowser: ICDeviceBrowser!
    private var scanners: [(name: String, id: String)] = []
    private var scannerDevices: [ICScannerDevice] = []
    private var scanFileResult: FlutterResult?
    private var activeScanner: ICScannerDevice?
    private var scanDirectory: URL?

    override public init() {
        super.init()
        deviceBrowser = ICDeviceBrowser()
        deviceBrowser.delegate = self
        deviceBrowser.browsedDeviceTypeMask = ICDeviceTypeMask(
            rawValue: ICDeviceTypeMask.scanner.rawValue | ICDeviceLocationTypeMask.local.rawValue
        )!
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
            let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory), isDirectory.boolValue {
                scanDirectory = directoryURL
                scanFile(deviceId: deviceId)
            } else {
                result(FlutterError(code: "InvalidDirectory", message: "Directory does not exist", details: nil))
                scanFileResult = nil
            }
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func scanFile(deviceId: String) {
        guard let scannerDevice = scannerDevices.first(where: { $0.uuidString == deviceId }) else {
            scanFileResult?(FlutterError(code: "DeviceNotFound", message: "Scanner not found", details: nil))
            scanFileResult = nil
            return
        }
        
        activeScanner = scannerDevice
        scannerDevice.delegate = self
        scannerDevice.transferMode = .fileBased
        
        if let directory = scanDirectory {
            scannerDevice.downloadsDirectory = directory
        }
        
        scannerDevice.requestOpenSession()
    }

    private func handleAvailableScanSources(_ scanner: ICScannerDevice) {
        let functionalUnitTypes = scanner.availableFunctionalUnitTypes/* else {
            scanFileResult?(FlutterError(code: "NoFunctionalUnits", message: "No available functional units", details: nil))
            scanFileResult = nil
            return
        }*/
        
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
        
        if functionalUnit.supportedBitDepths.contains(Int(ICScannerBitDepth.depth8Bits.rawValue))
       //  && functionalUnit.supportedPixelTypes.contains(.RGB)
          {
            functionalUnit.pixelDataType = ICScannerPixelDataType.RGB
            functionalUnit.bitDepth = .depth8Bits
        } else if functionalUnit.supportedBitDepths.contains(Int(ICScannerBitDepth.depth16Bits.rawValue)) 
      //  && functionalUnit.supportedPixelTypes.contains(.RGB) 
        {
            functionalUnit.pixelDataType = ICScannerPixelDataType.RGB
            functionalUnit.bitDepth = .depth16Bits
        } else {
            functionalUnit.pixelDataType = .BW
            functionalUnit.bitDepth = .depth1Bit
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let dateString = dateFormatter.string(from: Date())
        scanner.documentName = "Scan-\(dateString)"
        
        scanner.requestScan()
    }
    
    // MARK: - ICDeviceBrowserDelegate
    public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        if let scanner = device as? ICScannerDevice,
           !scannerDevices.contains(where: { $0.uuidString == scanner.uuidString }) {
            scannerDevices.append(scanner)
            scanners.append((name: scanner.name ?? "Unknown Scanner", id: scanner.uuidString ?? UUID().uuidString))
        }
    }

    public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        if let uuid = device.uuidString {
            scanners.removeAll { $0.id == uuid }
            scannerDevices.removeAll { $0.uuidString == uuid }
            
            if activeScanner?.uuidString == uuid {
                activeScanner = nil
                if scanFileResult != nil {
                    scanFileResult?(FlutterError(code: "DeviceRemoved", message: "Scanner was disconnected during operation", details: nil))
                    scanFileResult = nil
                }
            }
        }
    }
    
    // MARK: - ICDeviceDelegate
    // MARK: - ICDeviceDelegate (Required Methods)
    public func didRemove(_ device: ICDevice) {
        if let uuid = device.uuidString {
            scanners.removeAll { $0.id == uuid }
            scannerDevices.removeAll { $0.uuidString == uuid }
            
            if activeScanner?.uuidString == uuid {
                activeScanner = nil
                if scanFileResult != nil {
                    scanFileResult?(FlutterError(
                        code: "DeviceRemoved", 
                        message: "Scanner was disconnected during operation", 
                        details: nil
                    ))
                    scanFileResult = nil
                }
            }
        }
    }

    public func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        if let error = error {
            scanFileResult?(FlutterError(
                code: "SessionError", 
                message: error.localizedDescription, 
                details: nil
            ))
            scanFileResult = nil
            activeScanner = nil
        } else if let scanner = device as? ICScannerDevice {
            handleAvailableScanSources(scanner)
        }
    }

    public func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        if let error = error {
            print("Session closed with error: \(error.localizedDescription)")
        }
        activeScanner = nil
    }
    public func deviceDidBecomeReady(_ device: ICDevice) {
        print("Device ready: \(device.name ?? "Unknown device")")
    }
    
    
    public func device(_ device: ICDevice, didReceiveStatusInformation status: [ICDeviceStatus: Any]) {
        print("Device status: \(status)")
    }
    
    public func device(_ device: ICDevice, didEncounterError error: Error?) {
        if let error = error {
            print("Device error: \(error.localizedDescription)")
            if device == activeScanner {
                scanFileResult?(FlutterError(code: "DeviceError", message: error.localizedDescription, details: nil))
                scanFileResult = nil
            }
        }
    }
    
    public func deviceDidChangeName(_ device: ICDevice) {
        print("Device name changed to: \(device.name ?? "Unknown")")
        if let index = scanners.firstIndex(where: { $0.id == device.uuidString }) {
            scanners[index].name = device.name ?? "Unknown Scanner"
        }
    }
    
    public func deviceDidChangeSharingState(_ device: ICDevice) {
        print("Device sharing state changed")
    }
    
    // MARK: - ICScannerDeviceDelegate
    public func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        if let error = error {
            scanFileResult?(FlutterError(code: "UnitSelectionError", message: error.localizedDescription, details: nil))
            scanFileResult = nil
            scanner.requestCloseSession()
            activeScanner = nil
        } else {
            configureAndStartScan(for: functionalUnit, scanner: scanner)
        }
    }

    public func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
        scanFileResult?(url.path)
        scanFileResult = nil
        scanner.requestCloseSession()
        activeScanner = nil
    }

    public func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
        if let error = error {
            scanFileResult?(FlutterError(code: "ScanError", message: error.localizedDescription, details: nil))
            scanFileResult = nil
        }
        scanner.requestCloseSession()
        activeScanner = nil
    }
    
    public func scannerDeviceDidBecomeAvailable(_ scanner: ICScannerDevice) {
        print("Scanner became available: \(scanner.name ?? "Unknown")")
    }
    
    // MARK: - Optional ICDeviceDelegate methods
    public func device(_ device: ICDevice, didReceiveButtonPress buttonType: String) {
        print("Device button pressed: \(buttonType)")
    }
    
    public func deviceDidRemoveSharing(_ device: ICDevice) {
        print("Device stopped sharing")
    }
}