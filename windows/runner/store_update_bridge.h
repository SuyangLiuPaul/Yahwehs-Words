#pragma once
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Services.Store.h>
#include <shobjidl.h>
#include <atomic>
#include <memory>

class StoreUpdateBridge {
 public:
  StoreUpdateBridge(flutter::BinaryMessenger* messenger, HWND window)
      : alive_(std::make_shared<std::atomic_bool>(true)), window_(window),
        channel_(messenger, "yahweh/store_update", &flutter::StandardMethodCodec::GetInstance()) {
    channel_.SetMethodCallHandler([this](const auto& call, auto result) {
      if (call.method_name() != "check") { result->NotImplemented(); return; }
      Check(window_, alive_, std::move(result));
    });
  }
  ~StoreUpdateBridge() { alive_->store(false); channel_.SetMethodCallHandler(nullptr); }
 private:
  static winrt::fire_and_forget Check(HWND window, std::shared_ptr<std::atomic_bool> alive,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    try {
      auto context = winrt::Windows::Services::Store::StoreContext::GetDefault();
      context.as<IInitializeWithWindow>()->Initialize(window);
      auto updates = co_await context.GetAppAndOptionalStorePackageUpdatesAsync();
      if (alive->load()) result->Success(flutter::EncodableValue(updates.Size() > 0));
    } catch (...) {
      // Unpackaged EXE and unavailable Store access have no eligible update.
      if (alive->load()) result->Success(flutter::EncodableValue(false));
    }
  }
  std::shared_ptr<std::atomic_bool> alive_;
  HWND window_;
  flutter::MethodChannel<flutter::EncodableValue> channel_;
};
