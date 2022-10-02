//
//  ContentView.swift
//  ARScanner
//
//  Created by Tatsuya Ogawa on 2022/09/27.
//

import SwiftUI
import ARKit
import SceneKit
import SwiftUI


struct ARSceneViewContentView {
    @State var session: ARSession
    @State var scene: SCNScene
    @State var lineColor = Color.white

    init() {
        let session = ARSession()
        let configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        session.run(configuration)
        self.session = session

        self.scene = SCNScene()
    }
}

extension ARSceneViewContentView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            ARSceneView(
                session: self.$session,
                scene: self.$scene,
                lineColor: self.$lineColor
            )
            .ignoresSafeArea()

            ColorPicker("Line Color", selection: self.$lineColor)
                .padding()
        }
    }
}


