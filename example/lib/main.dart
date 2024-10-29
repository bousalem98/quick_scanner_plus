import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:quick_scanner_plus/quick_scanner_plus.dart';

void main() {
  // Entry point of the Flutter application
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // List to hold available scanners
  List<ScannerInfo> _scanners = [];
  // Currently selected scanner
  ScannerInfo? _selectedScanner;
  // Path of the scanned file
  String? _scannedFilePath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Scanner Example App'), // App title
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0), // Padding around the body
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    child: Text(
                        'Start Watch'), // Button to start watching for scanners
                    onPressed: () async {
                      await QuickScannerPlus.startWatch();
                    },
                  ),
                  ElevatedButton(
                    child: Text(
                        'Stop Watch'), // Button to stop watching for scanners
                    onPressed: () async {
                      await QuickScannerPlus.stopWatch();
                    },
                  ),
                ],
              ),
              SizedBox(height: 20), // Space between rows
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    child: Text(
                        'Get Scanners'), // Button to fetch available scanners
                    onPressed: () async {
                      // Fetch the list of scanners and update state
                      var list = await QuickScannerPlus.getScanners();
                      setState(() {
                        _scanners = list;
                        if (_scanners.isNotEmpty) {
                          _selectedScanner = _scanners
                              .first; // Set the first scanner as default
                        }
                      });
                    },
                  ),
                  DropdownButton<ScannerInfo>(
                    hint: Text('Select Scanner'), // Hint for dropdown
                    value: _selectedScanner, // Currently selected scanner
                    items: _scanners.map((scanner) {
                      return DropdownMenuItem(
                        value: scanner,
                        child: Text(scanner.name), // Display the scanner name
                      );
                    }).toList(),
                    onChanged: (value) {
                      // Update the selected scanner when changed
                      setState(() {
                        _selectedScanner = value;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 20), // Space between rows
              ElevatedButton(
                child: Text('Scan'), // Button to initiate scanning
                onPressed: _selectedScanner == null
                    ? null // Disable button if no scanner is selected
                    : () async {
                        // Get the application's document directory
                        var directory =
                            await getApplicationDocumentsDirectory();
                        // Scan a file using the selected scanner's ID
                        var scannedFile = await QuickScannerPlus.scanFile(
                            _selectedScanner!.id,
                            directory.path); // Use the selected scanner ID
                        setState(() {
                          _scannedFilePath =
                              scannedFile; // Update scanned file path
                        });
                      },
              ),
              SizedBox(height: 20), // Space between rows
              if (_scannedFilePath != null) ...[
                Text('Scanned Image:'),
                SizedBox(height: 10),
                Image.file(
                  File(_scannedFilePath!), // Display the scanned image
                  height: 200,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
