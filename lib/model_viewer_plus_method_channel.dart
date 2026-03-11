import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'model_viewer_plus_platform_interface.dart';

/// An implementation of [ModelViewerPlusPlatform] that uses method channels.
class MethodChannelModelViewerPlus extends ModelViewerPlusPlatform {
  final MethodChannel _methodChannel;

  MethodChannelModelViewerPlus(int viewId)
      : _methodChannel = MethodChannel('model_viewer_plus_$viewId');

  @override
  Future<void> loadModel(modelPath) async {
    ByteData modelData = await rootBundle.load(modelPath);
    Uint8List modelBytes = modelData.buffer.asUint8List();
    String? modelName = modelPath.split('/').last;

    debugPrint("SUCCESS MODEL");
    final args = { "modelBytes": modelBytes, "modelName": modelName };
    await _methodChannel.invokeMethod("loadModel", args);
  }

  @override
  Future<void> loadEnvironment(String? iblPath) async {
    if(iblPath == null) return;

    ByteData iblData = await rootBundle.load(iblPath);
    Uint8List iblBytes = iblData.buffer.asUint8List();
    String? iblName = iblPath.split('/').last;

    debugPrint("SUCCESS ENVIRONMENT");
    final args = { "iblBytes": iblBytes, "iblName": iblName };
    await _methodChannel.invokeMethod('loadEnvironment', args);
  }

  @override
  Future<void> loadHdrBackground(String? backgroundPath) async {
    if(backgroundPath == null) return;

    ByteData backgroundData = await rootBundle.load(backgroundPath);
    Uint8List backgroundBytes = backgroundData.buffer.asUint8List();

    debugPrint("SUCCESS HDR BACKGROUND");
    final args = { "backgroundBytes": backgroundBytes };
    await _methodChannel.invokeMethod("loadHdrBackground", args);
  }
}
