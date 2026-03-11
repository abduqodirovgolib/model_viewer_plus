import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class ModelViewerPlusPlatform extends PlatformInterface {
  /// Constructs a ModelViewerPlusPlatform.
  ModelViewerPlusPlatform() : super(token: _token);

  static final Object _token = Object();

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ModelViewerPlusPlatform] when
  /// they register themselves.
  static void verify(ModelViewerPlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
  }

  /// Method to load the model from assets.
  /// [resources] is empty for .glb models.
  Future<void> loadModel(String modelPath);

  /// Method to load the environment from assets.
  Future<void> loadEnvironment(String? iblPath);

  /// Load HDR or EXR background for iOS
  Future<void> loadHdrBackground(String? backgroundPath);
}
