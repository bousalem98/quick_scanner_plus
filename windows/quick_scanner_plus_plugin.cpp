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
    void LogError(const std::string &message); // Logging function
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

  winrt::fire_and_forget QuickScannerPlusPlugin::ScanFileAsync(std::string device_id, std::string directory, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    auto asyncTask = std::async(std::launch::async, [this, device_id, directory, result = std::move(result)]() mutable
                                {
    try
    {
      auto scanner = ImageScanner::FromIdAsync(winrt::to_hstring(device_id)).get();
      if (!scanner)
      {
        result->Error("InvalidScanner", "Could not retrieve scanner.");
        return;
      }

      auto storageFolder = StorageFolder::GetFolderFromPathAsync(winrt::to_hstring(directory)).get();
      auto scanResult = scanner.ScanFilesToFolderAsync(ImageScannerScanSource::Flatbed, storageFolder).get();
      auto scannedFiles = scanResult.ScannedFiles();
      if (scannedFiles.Size() > 0)
      {
        auto path = scannedFiles.GetAt(0).Path();
        result->Success(flutter::EncodableValue(winrt::to_string(path)));
      }
      else
      {
        result->Error("ScanFailed", "No files were scanned.");
      }
    }
    catch (const winrt::hresult_error &ex)
    {
      LogError("WinRT Error: " + winrt::to_string(ex.message()));
      result->Error(std::to_string(ex.code()), winrt::to_string(ex.message()));
    }
    catch (const std::exception &ex)
    {
      LogError("Standard Exception: " + std::string(ex.what()));
      result->Error("StandardException", ex.what());
    }
    catch (...)
    {
      LogError("Unknown error occurred during scanning.");
      result->Error("UnknownError", "An unknown error occurred.");
    } });

    co_return;
  }
  void QuickScannerPlusPlugin::LogError(const std::string &message)
  {
    std::ofstream log_file("plugin_debug.log", std::ios::app);
    log_file << "Error: " << message << std::endl;
  }
} // namespace

void QuickScannerPlusPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  QuickScannerPlusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
