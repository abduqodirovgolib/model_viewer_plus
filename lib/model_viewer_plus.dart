import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model_viewer_plus_method_channel.dart';
import 'model_viewer_plus_platform_interface.dart';

class ModelViewerPlus extends StatefulWidget {
  /// Path to the 3D model file (e.g., `.glb`) to be loaded from assets.
  final String modelPath;

  /// Path to the Image-Based Lighting (IBL) file used for rendering the 3D model from assets.
  final String? iblPath;

  /// Path to the skybox texture file of type .hdr/.exr used for the 3D environment from assets.
  final String? backgroundPath;

  /// Model o'z o'qi (Y) atrofida aylanish tezligi — gradus/sekund.
  /// Default: 30. 0 = avtomatik aylanish o'chirilgan (Yerning o'zi atrofida aylanishi kabi).
  final double? autoRotationSpeed;

  const ModelViewerPlus({
    super.key,
    required this.modelPath,
    this.iblPath,
    this.backgroundPath,
    this.autoRotationSpeed,
  });

  @override
  State<ModelViewerPlus> createState() => _ModelViewerPlusState();
}

class _ModelViewerPlusState extends State<ModelViewerPlus> {
  /// Platform-specific implementation for interacting with the 3D viewer.
  ModelViewerPlusPlatform? _platform;

  /// ID of the platform view.
  int _viewId = -1;

  /// Creates the parameters to be passed to the platform view.
  dynamic _creationParams() {
    return {
      'modelPath': widget.modelPath,
      'iblPath': widget.iblPath,
      'backgroundPath': widget.backgroundPath,
      'autoRotationSpeed': widget.autoRotationSpeed,
    };
  }

  /// Called when the platform view is created.
  /// Initializes the platform interface and loads the model and environment.
  Future<void> _onPlatformViewCreated(int id) async {
    _viewId = id;
    _platform = MethodChannelModelViewerPlus(_viewId);
    ModelViewerPlusPlatform.verify(_platform!);

    if(Platform.isAndroid) {
      // Load environment.
      await _platform!.loadEnvironment(widget.iblPath);
    } else if(Platform.isIOS) {
      // Load environment.
      await _platform!.loadHdrBackground(widget.backgroundPath);
    }

    // Load the model.
    await _platform!.loadModel(widget.modelPath);
  }

  @override
  Widget build(BuildContext context) {
    // Render the platform-specific view (iOS or Android).
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'model_viewer_plus',
        creationParams: _creationParams(),
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'model_viewer_plus',
        creationParams: _creationParams(),
        onPlatformViewCreated: _onPlatformViewCreated,
        creationParamsCodec: const StandardMessageCodec(),
      );
    } else {
      return SizedBox.shrink();
    }
  }
}
