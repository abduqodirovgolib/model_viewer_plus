#ifndef FLUTTER_PLUGIN_MODEL_VIEWER_PLUS_PLUGIN_H_
#define FLUTTER_PLUGIN_MODEL_VIEWER_PLUS_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace model_viewer_plus {

class ModelViewerPlusPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  ModelViewerPlusPlugin();

  virtual ~ModelViewerPlusPlugin();

  // Disallow copy and assign.
  ModelViewerPlusPlugin(const ModelViewerPlusPlugin&) = delete;
  ModelViewerPlusPlugin& operator=(const ModelViewerPlusPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace model_viewer_plus

#endif  // FLUTTER_PLUGIN_MODEL_VIEWER_PLUS_PLUGIN_H_
