//
//  ARViewContainer.swift
//  ARScanner
//
//  Created by Tatsuya Ogawa on 2022/09/27.
//

import RealityKit
import ARKit
import SwiftUI

class ARViewContainerDelegate:NSObject,ARSessionDelegate{
    
}

struct ARViewContainer: UIViewRepresentable {
    let delegate:ARViewContainerDelegate = ARViewContainerDelegate()
    func makeUIView(context: Context) -> ARView {
        func setARViewOptions() {
            arView.debugOptions.insert(.showSceneUnderstanding)
        }
        func buildConfigure() -> ARWorldTrackingConfiguration {
            let configuration = ARWorldTrackingConfiguration()
            
            configuration.environmentTexturing = .automatic
            configuration.sceneReconstruction = .mesh
            if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
                configuration.frameSemantics = .sceneDepth
            }
            
            return configuration
        }
        func initARView() {
            setARViewOptions()
            let configuration = buildConfigure()
            arView.session.run(configuration)
        }
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.session.delegate = self.delegate
        initARView()
        arView.addTapGesture()
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        
    }
}
