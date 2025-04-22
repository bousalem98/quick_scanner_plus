## 0.2.1

fix macos issue missing argument for parameter when try to run package for macos

## 0.2.0

Added
macOS Support: Introduced support for scanning devices on macOS using the ImageCaptureCore framework.

Devices are now discoverable via startWatch and getScanners methods.
Added support for all available functional units (e.g., Flatbed, Document Feeder) for macOS scanners.
Scanning operations are now performed asynchronously to maintain app responsiveness.
Includes handling of various bit depths and pixel data types for macOS.
Windows Enhancements: Improved scanner functionality on Windows.

Added support for detecting and using all scanner types (e.g., Flatbed, Document Feeder) available on the system.
Expanded compatibility with more device configurations.
Fixed
Resolved issues with device session management to prevent potential crashes during scanning on both macOS and Windows.
Enhanced error handling for scenarios where devices are disconnected or unavailable.
Other
Updated internal methods for better cross-platform compatibility and performance.
Improved logging for debugging and device lifecycle management.

## 0.1.3

- Modified MacOs scan code to execute operations in a separate thread for improved responsiveness and to prevent blocking the main thread.
- Enhanced error handling by implementing comprehensive try-catch blocks to capture and handle all potential exceptions, ensuring greater robustness and stability.

## 0.1.1

- fix MacOs scan

## 0.1.0

- Add `startWatch`/`stopWatch` and `getScanners`
- Add `scanFile`
