import 'package:flutter_test/flutter_test.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:model_viewer_plus/model_viewer_plus_platform_interface.dart';
import 'package:model_viewer_plus/model_viewer_plus_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockModelViewerPlusPlatform
    with MockPlatformInterfaceMixin
    implements ModelViewerPlusPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ModelViewerPlusPlatform initialPlatform = ModelViewerPlusPlatform.instance;

  test('$MethodChannelModelViewerPlus is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelModelViewerPlus>());
  });

  test('getPlatformVersion', () async {
    ModelViewerPlus modelViewerPlusPlugin = ModelViewerPlus();
    MockModelViewerPlusPlatform fakePlatform = MockModelViewerPlusPlatform();
    ModelViewerPlusPlatform.instance = fakePlatform;

    expect(await modelViewerPlusPlugin.getPlatformVersion(), '42');
  });
}
