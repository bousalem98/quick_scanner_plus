#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint quick_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'quick_scanner_plus'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for scanning documents on macOS'
  s.description      = <<-DESC
A Flutter plugin that provides document scanning capabilities for macOS using ImageCaptureCore framework.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.15'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end