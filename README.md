# quick_scanner_plus

A cross-platform (Windows/macOS) scanner plugin for Flutter. This plugin allows you to easily integrate scanning functionality into your Flutter applications, enabling users to utilize connected scanners for various tasks.

## Features

- Start and stop watching for available scanners.
- Fetch a list of connected scanners.
- Scan files and retrieve their paths.

## Usage

```dart
import 'package:quick_scanner_plus/quick_scanner_plus.dart';
import 'package:path_provider/path_provider.dart';

// Start watching for available scanners
QuickScannerPlus.startWatch();

// Get the list of available scanners
var _scanners = await QuickScannerPlus.getScanners();

// Get the application's documents directory
var directory = await getApplicationDocumentsDirectory();

// Scan a file using the first available scanner
var scannedFile = await QuickScannerPlus.scanFile(_scanners.first.id, directory.path);

// Stop watching for scanners
QuickScannerPlus.stopWatch();

```

Also, for whole example, check out the **example** app in the [example](https://github.com/bousalem98/quick_scanner_plus/tree/main/example) directory or the 'Example' tab on pub.dartlang.org for a more complete example.

## Main Contributors

<table>
  <tr>
    <td align="center"><a href="https://github.com/bousalem98"><img src="https://avatars.githubusercontent.com/u/61710794?v=4" width="100px;" alt=""/><br /><sub><b>Mohamed Salem</b></sub></a></td>
    <td align="center"><a href="https://github.com/woodemi"><img src="https://avatars.githubusercontent.com/u/41625567?s=200&v=4" width="100px;" alt=""/><br /><sub><b>Woodemi Co., Ltd</b></sub></a></td>
  </tr>
</table>
<br/>

## License

BSD 3-Clause License

Copyright (c) 2021, Woodemi Co,Ltd.
All rights reserved.
Copyright (c) 2025, Mohamed Salem Bousalem.
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
