import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import 'package:quick_scanner_plus/quick_scanner_plus.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<ScannerInfo> _scanners = [];
  ScannerInfo? _selectedScanner;
  String? _scannedFilePath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Scanner Example App'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    child: Text('Start Watch'),
                    onPressed: () async {
                      QuickScannerPlus.startWatch();
                    },
                  ),
                  ElevatedButton(
                    child: Text('Stop Watch'),
                    onPressed: () async {
                      QuickScannerPlus.stopWatch();
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    child: Text('Get Scanners'),
                    onPressed: () async {
                      var list = await QuickScannerPlus.getScanners();
                      setState(() {
                        _scanners = list;
                        if (_scanners.isNotEmpty) {
                          _selectedScanner = _scanners.first;
                        }
                      });
                    },
                  ),
                  DropdownButton<ScannerInfo>(
                    hint: Text('Select Scanner'),
                    value: _selectedScanner,
                    items: _scanners.map((scanner) {
                      return DropdownMenuItem(
                        value: scanner,
                        child:
                            Text(scanner.name), // Use scanner name for display
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedScanner = value;
                      });
                    },
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                child: Text('Scan'),
                onPressed: _selectedScanner == null
                    ? null
                    : () async {
                        var directory =
                            await getApplicationDocumentsDirectory();
                        var scannedFile = await QuickScannerPlus.scanFile(
                            _selectedScanner!.id,
                            directory.path); // Use scanner ID
                        setState(() {
                          _scannedFilePath = scannedFile;
                        });
                      },
              ),
              SizedBox(height: 20),
              if (_scannedFilePath != null) ...[
                Text('Scanned Image:'),
                SizedBox(height: 10),
                Image.file(
                  File(_scannedFilePath!),
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
