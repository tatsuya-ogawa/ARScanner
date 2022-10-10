//
//  ARSceneViewContainer.swift
//  ARScanner
//
//  Created by Tatsuya Ogawa on 2022/10/03.
//
import ARKit
import SceneKit
import SwiftUI

struct ARSceneView {
    @Binding var session: ARSession
    @Binding var scene: SCNScene
    @Binding var lineColor: Color
}
class Nodes{
    enum Mode{
        case camera
        case depth
    }
    static let mode:Mode = .depth
    let cameraNode:SCNNode
    let wireNode:SCNNode
    init(anchor: ARMeshAnchor, frame: ARFrame){
        let geometry = Nodes.createScnGeometry(anchor: anchor, frame: frame)
        self.cameraNode = SCNNode(geometry: geometry.camera)
        self.cameraNode.simdTransform = anchor.transform
        self.wireNode = SCNNode(geometry: geometry.wire)
        self.wireNode.simdTransform = anchor.transform
    }
    func update(anchor: ARMeshAnchor, frame: ARFrame){
        let geometry = Nodes.createScnGeometry(anchor: anchor, frame: frame)
        self.cameraNode.geometry = geometry.camera
        self.cameraNode.simdTransform = anchor.transform
        self.wireNode.geometry = geometry.wire
        self.wireNode.simdTransform = anchor.transform
    }
    func appendToRoot(rootNode:SCNNode){
        rootNode.addChildNode(self.cameraNode)
        rootNode.addChildNode(self.wireNode)
    }
    func removeFromParentNode(){
        self.cameraNode.removeFromParentNode()
        self.wireNode.removeFromParentNode()
    }
    private static func createScnGeometry(anchor: ARMeshAnchor, frame: ARFrame)->(camera:SCNGeometry,wire:SCNGeometry){
        let cameraGeometry = SCNGeometry(anchor: anchor, camera: frame.camera)
        let cameraMaterial = SCNMaterial()
        cameraMaterial.fillMode = .fill
        if Nodes.mode == .camera{
            if let image = frame.cameraUIImage{
                cameraMaterial.diffuse.contents = image
                cameraMaterial.transparency = 1.0
            }
        }else if Nodes.mode == .depth{
            if let image = frame.depthMapUIImage{
                cameraMaterial.diffuse.contents = image
                cameraMaterial.transparency = 0.5
            }
        }
        cameraGeometry.materials = [cameraMaterial]
        
        let wireGeometry = SCNGeometry(anchor: anchor, camera: frame.camera)
        let wireMaterial = SCNMaterial()
        wireMaterial.fillMode = .lines
        wireMaterial.diffuse.contents = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        wireMaterial.blendMode = .add
        wireGeometry.materials = [wireMaterial]
        
        return (camera:cameraGeometry,wire:wireGeometry)
    }
}

extension ARSceneView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        ARSCNView(frame: .zero)
    }
    
    func makeCoordinator() -> Self.Coordinator {
        Self.Coordinator(scene: self.$scene, lineColor: self.$lineColor)
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        if uiView.session != self.session {
            uiView.session.delegate = nil
            uiView.session = self.session
            uiView.session.delegate = context.coordinator
        }
        uiView.scene = self.scene
    }
}

extension ARSceneView {
    final class Coordinator: NSObject {
        @Binding var scene: SCNScene
        @Binding var lineColor: Color
        var knownAnchors = [UUID: Nodes]()
        
        init(scene: Binding<SCNScene>, lineColor: Binding<Color>) {
            self._scene = scene
            self._lineColor = lineColor
        }
    }
}

extension ARSceneView.Coordinator: ARSessionDelegate {
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard let currentFrame = session.currentFrame else{
            return
        }
        for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            let node = Nodes(anchor: anchor, frame: currentFrame)
            node.appendToRoot(rootNode: self.scene.rootNode)
            self.knownAnchors[anchor.identifier] = node
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard let currentFrame = session.currentFrame else{
            return
        }
        for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            if let node = self.knownAnchors[anchor.identifier] {
                node.update(anchor: anchor, frame: currentFrame)
            }
        }
    }
    
    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors.compactMap({ $0 as? ARMeshAnchor }) {
            if let node = self.knownAnchors[anchor.identifier] {
                node.removeFromParentNode()
                self.knownAnchors.removeValue(forKey: anchor.identifier)
            }
        }
    }
}
extension ARFrame {
    var cameraUIImage: UIImage? {
        let pixelBuffer = self.capturedImage
        
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        
        let context = CIContext(options:nil)
        guard let cameraImage = context.createCGImage(image, from: image.extent) else {return nil}
        
        return UIImage(cgImage: cameraImage)
    }
    var depthMapUIImage: UIImage? {
        guard let pixelBuffer = self.sceneDepth?.depthMap else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent)
        guard let image = cgImage else { return nil }
        return UIImage(cgImage: image)
    }
    var confidenceMapUIImage: UIImage? {
        guard let pixelBuffer = self.sceneDepth?.confidenceMap else { return nil }
        // 0 ~ 2 -> 0 ~ 255
        let lockFlags: CVPixelBufferLockFlags = CVPixelBufferLockFlags(rawValue: 0)
        CVPixelBufferLockBaseAddress(pixelBuffer, lockFlags)
        guard let rawBuffer = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let len = bytesPerRow*height
        let stride = MemoryLayout<UInt8>.stride
        var i = 0
        while i < len {
            let data = rawBuffer.load(fromByteOffset: i, as: UInt8.self)
            let v = UInt8(ceil(Float(data) / Float(ARConfidenceLevel.high.rawValue) * 255))
            rawBuffer.storeBytes(of: v, toByteOffset: i, as: UInt8.self)
            i += stride
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, lockFlags)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent)
        guard let image = cgImage else { return nil }
        return UIImage(cgImage: image)
    }
}
struct ARSceneView_Previews: PreviewProvider {
    static var previews: some View {
        ARSceneView(
            session: .constant(ARSession()),
            scene: .constant(SCNScene()),
            lineColor: .constant(.white)
        )
    }
}
