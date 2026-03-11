#include "include/model_viewer_plus/model_viewer_plus_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "model_viewer_plus_plugin.h"

void ModelViewerPlusPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  model_viewer_plus::ModelViewerPlusPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
