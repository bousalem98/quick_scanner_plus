import 'dart:async';
import 'package:flutter/services.dart';

/// A class representing a scanner device with its ID and name.
class ScannerInfo {
  final String id; // Unique identifier for the scanner
  final String name; // Name of the scanner

  ScannerInfo({required this.id, required this.name});
}

/// A class to interact with the QuickScanner plugin for scanning documents.
class QuickScannerPlus {
  static const MethodChannel _channel = const MethodChannel('quick_scanner_plus');

  /// Gets the platform version of the app.
  ///
  /// Returns a [String] representing the platform version,
  /// or `null` if the version could not be retrieved.
  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  /// Starts watching for available scanner devices.
  ///
  /// This method sets up a listener to monitor the availability
  /// of scanners. Call this method before trying to access any scanners.
  static Future<void> startWatch() => _channel.invokeMethod('startWatch');

  /// Stops watching for scanner devices.
  ///
  /// This method should be called when you no longer need to monitor
  /// scanner devices to clean up resources.
  static Future<void> stopWatch() => _channel.invokeMethod('stopWatch');

  /// Retrieves a list of available scanners.
  ///
  /// This method calls the native side to get a list of scanners and
  /// maps the data to a list of [ScannerInfo].
  ///
  /// Returns a [List<ScannerInfo>] containing the available scanners.
  static Future<List<ScannerInfo>> getScanners() async {
    // Get the list of scanners from the native side
    List<dynamic> list = await _channel.invokeMethod('getScanners');

    // Map the list of maps to List<ScannerInfo>
    return list.map((scanner) {
      return ScannerInfo(
        id: scanner['id'] as String,
        name: scanner['name'] as String,
      );
    }).toList();
  }

  /// Scans a file using the specified scanner.
  ///
  /// This method initiates a scan on the given device and saves the 
  /// scanned file in the specified directory.
  ///
  /// Parameters:
  /// - [deviceId]: The ID of the scanner device to use.
  /// - [directory]: The directory where the scanned file should be saved.
  ///
  /// Returns the path of the scanned file as a [String].
  static Future<String> scanFile(String deviceId, String directory) async {
    String path = await _channel.invokeMethod('scanFile', {
      'deviceId': deviceId,
      'directory': directory,
    });
    return path;
  }
}
