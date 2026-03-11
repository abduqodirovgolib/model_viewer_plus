import Flutter
import UIKit

public class ModelViewerPlusPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = ModelViewerPlusViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "model_viewer_plus")
    }
}
