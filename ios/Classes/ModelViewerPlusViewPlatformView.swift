import Flutter
import UIKit
import SceneKit
import GLTFSceneKit

class ModelViewerPlusViewPlatformView: NSObject, FlutterPlatformView {
    private let scnView: SCNView
    private let methodChannel: FlutterMethodChannel
    /// Model o'z o'qi atrofida aylanish tezligi — gradus/sekund. 0 = o'chirilgan.
    private var autoRotationSpeed: Float = 30
    /// Model wrapper node — aylanish uchun
    private var modelWrapperNode: SCNNode?

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        args: Any?
    ) {
        scnView = SCNView(frame: frame.isEmpty ? UIScreen.main.bounds : frame)
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.autoenablesDefaultLighting = false
        scnView.allowsCameraControl = true
        scnView.showsStatistics = false
        scnView.backgroundColor = .clear
        scnView.isOpaque = false
        scnView.cameraControlConfiguration.allowsTranslation = false

        methodChannel = FlutterMethodChannel(
            name: "model_viewer_plus_\(viewId)",
            binaryMessenger: messenger
        )

        super.init()

        if let params = args as? [String: Any],
           let speed = params["autoRotationSpeed"] as? NSNumber {
            autoRotationSpeed = speed.floatValue
        }

        methodChannel.setMethodCallHandler(handleMethodCall)

        let scene = SCNScene()
        scnView.scene = scene

        NSLog("SCNView initialized with frame: \(scnView.frame)")
    }

    func view() -> UIView {
        return scnView
    }

    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "loadModel":
            guard let args = call.arguments as? [String: Any],
                  let modelBytes = (args["modelBytes"] as? FlutterStandardTypedData)?.data else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "modelBytes is required or invalid",
                    details: nil
                ))
                return
            }
            let modelName = args["modelName"] as? String

            DispatchQueue.main.async { [weak self] in
                do {
                    try self?.loadModel(modelBytes: modelBytes, modelName: modelName)
                    result(nil)
                } catch {
                    result(FlutterError(
                        code: "LOAD_ERROR",
                        message: "Failed to load model: \(error.localizedDescription)",
                        details: error
                    ))
                }
            }

        case "loadHdrBackground":
            guard let args = call.arguments as? [String: Any],
                  let backgroundBytes = (args["backgroundBytes"] as? FlutterStandardTypedData)?.data else {
                result(FlutterError(
                    code: "INVALID_ARGUMENT",
                    message: "backgroundBytes is required or invalid",
                    details: nil
                ))
                return
            }

            DispatchQueue.main.async { [weak self] in
                do {
                    try self?.loadHdrBackgroundFromBytes(backgroundBytes)
                    result(nil)
                } catch {
                    result(FlutterError(
                        code: "LOAD_ERROR",
                        message: "Failed to load HDR/EXR background: \(error.localizedDescription)",
                        details: error
                    ))
                }
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func loadModel(modelBytes: Data, modelName: String? = nil) throws {
        let safeModelName = (modelName ?? "model.glb") as NSString
        let fileName = safeModelName.lastPathComponent
        NSLog("Received modelBytes with size: \(modelBytes.count) bytes, modelName: \(fileName)")

        let scene: SCNScene
        do {
            let gltfSource = GLTFSceneSource(data: modelBytes)
            scene = try gltfSource.scene()
            NSLog("Successfully loaded GLB with GLTFSceneSource (data)")
        } catch {
            NSLog("GLTFSceneSource(data) failed: \(error.localizedDescription). Trying file URL.")
            let tempDir = NSTemporaryDirectory()
            let tempFilePath = tempDir.appending(fileName)
            try modelBytes.write(to: URL(fileURLWithPath: tempFilePath))
            defer { try? FileManager.default.removeItem(atPath: tempFilePath) }
            do {
                let gltfSource = try GLTFSceneSource(url: URL(fileURLWithPath: tempFilePath))
                scene = try gltfSource.scene()
                NSLog("Successfully loaded GLB with GLTFSceneSource (url)")
            } catch {
                NSLog("GLTFSceneSource(url) failed: \(error.localizedDescription). Trying SCNSceneSource.")
                let sceneSource = SCNSceneSource(data: modelBytes, options: [
                    SCNSceneSource.LoadingOption.createNormalsIfAbsent: true,
                    SCNSceneSource.LoadingOption.checkConsistency: true
                ])
                guard let loadedScene = sceneSource?.scene(options: nil) else {
                    throw NSError(domain: "ModelViewerPlusPlugin", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to load GLB: \(error.localizedDescription)"])
                }
                scene = loadedScene
                NSLog("Successfully loaded GLB with SCNSceneSource")
            }
        }

        var geometryCount = 0
        scene.rootNode.enumerateChildNodes { (node, _) in
            if let geometry = node.geometry {
                geometryCount += 1
                if geometry.materials.isEmpty || geometry.firstMaterial?.diffuse.contents == nil {
                    let fallbackMaterial = SCNMaterial()
                    fallbackMaterial.diffuse.contents = UIColor.green
                    fallbackMaterial.isDoubleSided = true
                    geometry.materials = [fallbackMaterial]
                    NSLog("Applied fallback green material to node: \(node.name ?? "Unnamed")")
                } else {
                    NSLog("Node: \(node.name ?? "Unnamed") has material with diffuse: \(String(describing: geometry.firstMaterial?.diffuse.contents))")
                }
            }
        }
        NSLog("Total geometry nodes: \(geometryCount)")

        if geometryCount == 0 {
            NSLog("Warning: Model has no geometry, adding blue test cube")
            let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.blue
            material.isDoubleSided = true
            box.materials = [material]
            let boxNode = SCNNode(geometry: box)
            boxNode.position = SCNVector3(0, 0, 0)
            material.diffuse.contentsTransform = SCNMatrix4MakeScale(1, 1, 1)
            material.normal.mipFilter = .linear
            material.normal.intensity = 1.0
            
            
            scene.rootNode.addChildNode(boxNode)
        }

        if !hasLightNodes(in: scene.rootNode) {
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light!.type = .ambient
            ambientLight.light!.color = UIColor.white
            ambientLight.light!.intensity = 1000
            scene.rootNode.addChildNode(ambientLight)

            let directionalLight = SCNNode()
            directionalLight.light = SCNLight()
            directionalLight.light!.type = .directional
            directionalLight.light!.color = UIColor.white
            directionalLight.light!.intensity = 2000
            directionalLight.position = SCNVector3(x: 10, y: 10, z: 10)
            directionalLight.look(at: SCNVector3Zero)
            scene.rootNode.addChildNode(directionalLight)
            NSLog("Added default lighting")
        }

        scene.background.contents = UIColor.clear
        scnView.scene = scene
        fitCameraToModel(scene: scene)

        printSceneHierarchy(scene.rootNode, level: 0)
        NSLog("Camera point of view: \(scnView.pointOfView?.name ?? "None")")
        NSLog("Scene node count: \(scene.rootNode.childNodes.count)")
        NSLog("SCNView bounds: \(scnView.bounds)")
    }

    private func fitCameraToModel(scene: SCNScene) {
        let (minPt, maxPt) = scene.rootNode.boundingBox
        let center = SCNVector3(
            (minPt.x + maxPt.x) / 2,
            (minPt.y + maxPt.y) / 2,
            (minPt.z + maxPt.z) / 2
        )
        let size = SCNVector3(maxPt.x - minPt.x, maxPt.y - minPt.y, maxPt.z - minPt.z)
        let maxExtent = Swift.max(size.x, Swift.max(size.y, size.z))

        let modelWrapper = SCNNode()
        for child in scene.rootNode.childNodes {
            child.removeFromParentNode()
            modelWrapper.addChildNode(child)
        }

        // Parent node markazda (0,0,0) — model centerda qoladi, pivot ishlatmaymiz
        let rotationParent = SCNNode()
        rotationParent.position = SCNVector3Zero
        scene.rootNode.addChildNode(rotationParent)
        rotationParent.addChildNode(modelWrapper)

        if maxExtent > 0.001 {
            let scale = Float(2.0) / maxExtent
            modelWrapper.scale = SCNVector3(scale, scale, scale)
            modelWrapper.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)
        }

        // Model o'z o'qi (Y) atrofida aylanish — parent markazda, model centerda
        modelWrapperNode = rotationParent
        if autoRotationSpeed > 0 {
            let duration = Double(360) / Double(autoRotationSpeed)
            let rotateAction = SCNAction.rotateBy(x: 0, y: CGFloat(2 * Float.pi), z: 0, duration: duration)
            rotationParent.runAction(SCNAction.repeatForever(rotateAction), forKey: "autoRotate")
        }

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 1000
        cameraNode.position = SCNVector3(0, 0, 4)
        cameraNode.name = "ModelViewerCamera"
        scene.rootNode.addChildNode(cameraNode)
        scnView.pointOfView = cameraNode
        NSLog("Fitted camera to model, center: \(center), maxExtent: \(maxExtent)")
    }

    private func hasLightNodes(in node: SCNNode) -> Bool {
        if node.light != nil {
            return true
        }
        for child in node.childNodes {
            if hasLightNodes(in: child) {
                return true
            }
        }
        return false
    }

    private func printSceneHierarchy(_ node: SCNNode, level: Int) {
        let indent = String(repeating: "  ", count: level)
        let nodeInfo = "\(indent)Node: \(node.name ?? "Unnamed") | Geometry: \(node.geometry?.name ?? "None") | Position: \(node.position) | Bounding Box: \(node.boundingBox)"
        NSLog(nodeInfo)
        for child in node.childNodes {
            printSceneHierarchy(child, level: level + 1)
        }
    }
    
    private func loadHdrBackgroundFromBytes(_ backgroundBytes: Data) throws {
        // Write the bytes to a temporary file
        let tempDir = NSTemporaryDirectory()
        let tempFilePath = tempDir.appending("background.hdr") // Use .hdr or .exr based on input
        try backgroundBytes.write(to: URL(fileURLWithPath: tempFilePath))
        defer { try? FileManager.default.removeItem(atPath: tempFilePath) }

        // Load the HDR/EXR image
        guard let image = UIImage(contentsOfFile: tempFilePath) else {
            throw NSError(
                domain: "ModelViewerPlusPlugin",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Failed to load HDR/EXR image"]
            )
        }

        // Maximum texture size supported by most iOS devices (Metal)
        let maxTextureSize: CGFloat = 8192

        // Check if the image exceeds the maximum texture size
        let imageSize = image.size
        var targetSize = imageSize
        if imageSize.width > maxTextureSize || imageSize.height > maxTextureSize {
            let aspectRatio = imageSize.width / imageSize.height
            if imageSize.width > imageSize.height {
                targetSize = CGSize(width: maxTextureSize, height: maxTextureSize / aspectRatio)
            } else {
                targetSize = CGSize(width: maxTextureSize * aspectRatio, height: maxTextureSize)
            }
            NSLog("Resizing HDR/EXR image from \(imageSize) to \(targetSize)")
        }

        // Resize the image if necessary
        let resizedImage: UIImage
        if targetSize != imageSize {
            UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
            defer { UIGraphicsEndImageContext() }
            image.draw(in: CGRect(origin: .zero, size: targetSize))
            guard let scaledImage = UIGraphicsGetImageFromCurrentImageContext() else {
                throw NSError(
                    domain: "ModelViewerPlusPlugin",
                    code: -4,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to resize HDR/EXR image"]
                )
            }
            resizedImage = scaledImage
        } else {
            resizedImage = image
        }

        // Log the final image size for debugging
        let finalSize = resizedImage.size
        NSLog("Final HDR/EXR image size: \(finalSize)")

        // Ensure the scene is initialized
        guard let scene = scnView.scene else {
            throw NSError(
                domain: "ModelViewerPlusPlugin",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Scene not initialized"]
            )
        }

        // Apply the resized image as the scene's background (visible only)
        scene.background.contents = resizedImage

        // Use a neutral white texture for the lighting environment to avoid color tint
        scene.lightingEnvironment.contents = UIColor.white
        scene.lightingEnvironment.intensity = 1.0

        // Remove any existing lights to avoid conflicts
        scene.rootNode.enumerateChildNodes { (node, _) in
            if node.light != nil {
                node.removeFromParentNode()
                NSLog("Removed existing light node: \(node.name ?? "Unnamed")")
            }
        }

        // Add a neutral ambient light
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light!.type = .ambient
        ambientLight.light!.color = UIColor.white
        ambientLight.light!.intensity = 600 // Slightly increased for better illumination
        scene.rootNode.addChildNode(ambientLight)

        // Add a directional light for consistent model lighting
        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light!.type = .directional
        directionalLight.light!.color = UIColor.white
        directionalLight.light!.intensity = 1000
        directionalLight.position = SCNVector3(x: 10, y: 10, z: 10)
        directionalLight.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(directionalLight)

        NSLog("Successfully loaded HDR/EXR background with size \(finalSize), applied neutral lighting")
    }
}
