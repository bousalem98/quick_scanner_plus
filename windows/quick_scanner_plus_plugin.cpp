#include "include/quick_scanner_plus/quick_scanner_plus_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Devices.Enumeration.h>
#include <winrt/Windows.Devices.Scanners.h>
#include <winrt/Windows.Storage.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <sstream>
#include <tuple>   // Include for using std::tuple
#include <fstream> // For logging
#include <future>  // For std::async
using namespace winrt;
using namespace Windows::Foundation;
using namespace Windows::Foundation::Collections;
using namespace Windows::Devices::Enumeration;
using namespace Windows::Devices::Scanners;
using namespace Windows::Storage;

namespace
{

  class QuickScannerPlusPlugin : public flutter::Plugin
  {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    QuickScannerPlusPlugin();

    virtual ~QuickScannerPlusPlugin();

  private:
    // Called when a method is called on this plugin's channel from Dart.
    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

    DeviceWatcher deviceWatcher{nullptr};

    winrt::event_token deviceWatcherAddedToken;
    void DeviceWatcher_Added(DeviceWatcher sender, DeviceInformation info);

    winrt::event_token deviceWatcherRemovedToken;
    void DeviceWatcher_Removed(DeviceWatcher sender, DeviceInformationUpdate infoUpdate);

    std::vector<std::tuple<std::string, std::string>> scanners_{}; // Change to store pairs of name and ID

    winrt::fire_and_forget ScanFileAsync(std::string device_id, std::string directory,
                                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  };

  // static
  void QuickScannerPlusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "quick_scanner_plus",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<QuickScannerPlusPlugin>();

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result)
        {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  QuickScannerPlusPlugin::QuickScannerPlusPlugin()
  {
    deviceWatcher = DeviceInformation::CreateWatcher(DeviceClass::ImageScanner);
    deviceWatcherAddedToken = deviceWatcher.Added({this, &QuickScannerPlusPlugin::DeviceWatcher_Added});
    deviceWatcherRemovedToken = deviceWatcher.Removed({this, &QuickScannerPlusPlugin::DeviceWatcher_Removed});
  }

  QuickScannerPlusPlugin::~QuickScannerPlusPlugin()
  {
    deviceWatcher.Added(deviceWatcherAddedToken);
    deviceWatcher.Removed(deviceWatcherRemovedToken);
    deviceWatcher = nullptr;
  }

  void QuickScannerPlusPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    if (method_call.method_name().compare("getPlatformVersion") == 0)
    {
      std::ostringstream version_stream;
      version_stream << "Windows ";
      if (IsWindows10OrGreater())
      {
        version_stream << "10+";
      }
      else if (IsWindows8OrGreater())
      {
        version_stream << "8";
      }
      else if (IsWindows7OrGreater())
      {
        version_stream << "7";
      }
      result->Success(flutter::EncodableValue(version_stream.str()));
    }
    else if (method_call.method_name().compare("startWatch") == 0)
    {
      deviceWatcher.Start();
      result->Success(nullptr);
    }
    else if (method_call.method_name().compare("stopWatch") == 0)
    {
      deviceWatcher.Stop();
      result->Success(nullptr);
    }
    else if (method_call.method_name().compare("getScanners") == 0)
    {
      flutter::EncodableList list{};
      for (const auto &scanner : scanners_)
      {
        flutter::EncodableMap scannerInfo;
        scannerInfo[flutter::EncodableValue("id")] = flutter::EncodableValue(std::get<1>(scanner));   // ID
        scannerInfo[flutter::EncodableValue("name")] = flutter::EncodableValue(std::get<0>(scanner)); // Name
        list.push_back(flutter::EncodableValue(scannerInfo));
      }
      result->Success(list);
    }
    else if (method_call.method_name().compare("scanFile") == 0)
    {
      auto args = std::get<flutter::EncodableMap>(*method_call.arguments());
      auto device_id = std::get<std::string>(args[flutter::EncodableValue("deviceId")]);
      auto directory = std::get<std::string>(args[flutter::EncodableValue("directory")]);
      ScanFileAsync(device_id, directory, std::move(result));
      // result->Success(nullptr);
    }
    else
    {
      result->NotImplemented();
    }
  }

  void QuickScannerPlusPlugin::DeviceWatcher_Added(DeviceWatcher sender, DeviceInformation info)
  {
    std::cout << "DeviceWatcher_Added " << winrt::to_string(info.Name()) << std::endl;

    auto device_id = winrt::to_string(info.Id());
    auto scanner_name = winrt::to_string(info.Name()); // Get the scanner name
    auto it = std::find_if(scanners_.begin(), scanners_.end(), [&](const auto &scanner)
                           { return std::get<1>(scanner) == device_id; });

    if (it == scanners_.end())
    {
      scanners_.emplace_back(scanner_name, device_id); // Store name and ID
    }
  }

  void QuickScannerPlusPlugin::DeviceWatcher_Removed(DeviceWatcher sender, DeviceInformationUpdate infoUpdate)
  {
    std::cout << "DeviceWatcher_Removed " << winrt::to_string(infoUpdate.Id()) << std::endl;

    auto device_id = winrt::to_string(infoUpdate.Id());
    auto it = std::find_if(scanners_.begin(), scanners_.end(), [&](const auto &scanner)
                           { return std::get<1>(scanner) == device_id; });

    if (it != scanners_.end())
    {
      scanners_.erase(it);
    }
  }
  winrt::fire_and_forget QuickScannerPlusPlugin::ScanFileAsync(std::string device_id, std::string directory,
                                                               std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    try
    {
      // Initialize the scanner from the device ID
      auto scanner = co_await ImageScanner::FromIdAsync(winrt::to_hstring(device_id));
      if (!scanner)
      {
        result->Error("ScannerInitializationFailed", "Scanner could not be initialized.");
        co_return;
      }

      // Check if the scanner supports flatbed scanning
      if (!scanner.IsScanSourceSupported(ImageScannerScanSource::Flatbed))
      {
        result->Error("ScanSourceNotSupported", "Flatbed scanning is not supported on this scanner.");
        co_return;
      }

      // Configure scanner settings
      auto flatbedConfiguration = scanner.FlatbedConfiguration();
      if (flatbedConfiguration.IsColorModeSupported(ImageScannerColorMode::Color))
      {
        flatbedConfiguration.ColorMode(ImageScannerColorMode::Color);
      }
      else if (flatbedConfiguration.IsColorModeSupported(ImageScannerColorMode::Grayscale))
      {
        flatbedConfiguration.ColorMode(ImageScannerColorMode::Grayscale);
      }
      else
      {
        result->Error("UnsupportedScanModes", "Scanner does not support required color modes.");
        co_return;
      }

      // Validate and access the target directory
      auto storageFolder = co_await StorageFolder::GetFolderFromPathAsync(winrt::to_hstring(directory));
      if (!storageFolder)
      {
        result->Error("InvalidDirectory", "Specified directory does not exist or is inaccessible.");
        co_return;
      }

      // Perform the scan and handle the results
      auto scanResult = co_await scanner.ScanFilesToFolderAsync(ImageScannerScanSource::Flatbed, storageFolder);
      if (!scanResult.ScannedFiles().Size())
      {
        result->Error("ScanFailed", "No files were scanned.");
        co_return;
      }

      // Return the path of the first scanned file
      auto path = scanResult.ScannedFiles().First().Current().Path();
      result->Success(flutter::EncodableValue(winrt::to_string(path)));
    }
    catch (winrt::hresult_error const &ex)
    {
      // Handle WinRT-specific exceptions
      std::string message = "WinRT error occurred: " + winrt::to_string(ex.message());
      OutputDebugStringA(message.c_str()); // Log the error
      result->Error(std::to_string(ex.code()), winrt::to_string(ex.message()));
    }
    catch (std::exception const &e)
    {
      // Handle standard C++ exceptions
      std::string message = "Standard exception occurred: " + std::string(e.what());
      OutputDebugStringA(message.c_str()); // Log the error
      result->Error("UnexpectedError", e.what());
    }
    catch (...)
    {
      // Handle any other type of exception
      std::string message = "An unknown error occurred.";
      OutputDebugStringA(message.c_str()); // Log the error
      result->Error("UnknownError", "An unknown error occurred.");
    }
  }

} // namespace

void QuickScannerPlusPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  QuickScannerPlusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
