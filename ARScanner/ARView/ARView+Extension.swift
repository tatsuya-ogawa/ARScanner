//
//  ARView+Extension.swift
//  ARScanner
//
//  Created by Tatsuya Ogawa on 2022/09/28.
//
import SwiftUI
import RealityKit
import ARKit
import MetalKit
extension ARView {
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        self.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleTap(recognizer: UITapGestureRecognizer) {
        
        // タップしたロケーションを取得
        let tapLocation = recognizer.location(in: self)
        
        // タップした位置に対応する3D空間上の平面とのレイキャスト結果を取得
        let raycastResults = raycast(from: tapLocation, allowing: .estimatedPlane, alignment: .vertical)
        
        guard let firstResult = raycastResults.first else { return }
        // taplocationをワールド座標系に変換
        let position = simd_make_float3(firstResult.worldTransform.columns.3)
        
        //        placeCanvas(at: position)
        exportObject()
    }
    private func exportObject(){
        let arView = self
        guard let camera = arView.session.currentFrame?.camera else {return}
        
        func convertToAsset(meshAnchors: [ARMeshAnchor]) -> MDLAsset? {
            guard let device = MTLCreateSystemDefaultDevice() else {return nil}
            
            let asset = MDLAsset()
            
            for anchor in meshAnchors {
                print(anchor.identifier)
                let mdlMesh = anchor.geometry.toMDLMesh(device: device, camera: camera, modelMatrix: anchor.transform)
                asset.add(mdlMesh)
            }
            
            return asset
        }
        func export(asset: MDLAsset) throws -> URL {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = directory.appendingPathComponent("scaned.obj")
            
            try asset.export(to: url)
            
            return url
        }
        func share(url: URL) {
            //            let vc = UIActivityViewController(activityItems: [url],applicationActivities: nil)
            //            vc.popoverPresentationController?.sourceView = sender
            //            self.present(vc, animated: true, completion: nil)
        }
        //        arView.session.getCurrentWorldMap{ worldMap, error in
        //            guard let map = worldMap else {
        //                return
        //            }
        //            let meshAnchors = map.anchors.compactMap({$0 as? ARMeshAnchor})
        //            print(meshAnchors.count)
        // Add a snapshot image indicating where the map was captured.
        //            guard let snapshotAnchor = SnapshotAnchor(capturing: self.sceneView)
        //                else { fatalError("Can't take snapshot") }
        //            map.anchors.append(snapshotAnchor)
        //
        //            do {
        //                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
        //                try data.write(to: self.mapSaveURL, options: [.atomic])
        //                DispatchQueue.main.async {
        //                    self.loadExperienceButton.isHidden = false
        //                    self.loadExperienceButton.isEnabled = true
        //                }
        //            } catch {
        //                fatalError("Can't save map: \(error.localizedDescription)")
        //            }
        //        }
        if let meshAnchors = arView.session.currentFrame?.anchors.compactMap({ $0 as? ARMeshAnchor }),
           let asset = convertToAsset(meshAnchors: meshAnchors) {
            do {
                print(meshAnchors.count)
                let url = try export(asset: asset)
                share(url: url)
            } catch {
                print("export error")
            }
        }
    }
    /// キャンバスを配置する
    private func placeCanvas(at position: SIMD3<Float>) {
        
        //        guard let artTexture = getArtMaterial(name: "matsuda")
        //        else { return }
        
        let mesh = MeshResource.generateBox(width: 2, height: 3, depth: 0.15)
        //        let canvas = ModelEntity(mesh: mesh, materials: [artTexture])
        let canvas = ModelEntity(mesh: mesh, materials: [])
        
        canvas.look(at: cameraTransform.translation, from: position, relativeTo: nil)
        
        let anchorEntity = AnchorEntity(world: position)
        anchorEntity.addChild(canvas)
        
        scene.addAnchor(anchorEntity)
    }
    
    /// アートマテリアルを取得する
    private func getArtMaterial(name resourceName: String) -> PhysicallyBasedMaterial? {
        
        guard let texture = try? TextureResource.load(named: resourceName)
        else { return nil }
        
        var imageMaterial = PhysicallyBasedMaterial()
        let baseColor = MaterialParameters.Texture(texture)
        imageMaterial.baseColor = PhysicallyBasedMaterial.BaseColor(tint: .white, texture: baseColor)
        return imageMaterial
    }
}
extension ARMeshGeometry {
    func vertex(at index: UInt32) -> SIMD3<Float> {
        assert(vertices.format == MTLVertexFormat.float3, "Expected three floats (twelve bytes) per vertex.")
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + (vertices.stride * Int(index)))
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return vertex
    }
    
    // helps from StackOverflow:
    // https://stackoverflow.com/questions/61063571/arkit-3-5-how-to-export-obj-from-new-ipad-pro-with-lidar
    func toMDLMesh(device: MTLDevice, camera: ARCamera, modelMatrix: simd_float4x4) -> MDLMesh {
        func convertVertexLocalToWorld() {
            let verticesPointer = vertices.buffer.contents()
            
            for vertexIndex in 0..<vertices.count {
                let vertex = self.vertex(at: UInt32(vertexIndex))
                
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.x, y: vertex.y, z: vertex.z, w: 1)
                let vertexWorldPosition = (modelMatrix * vertexLocalTransform).columns.3
                
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                let componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x, toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y, toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z, toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)
            }
        }
        convertVertexLocalToWorld()
        
        let allocator = MTKMeshBufferAllocator(device: device);
        
        let data = Data.init(bytes: vertices.buffer.contents(), count: vertices.stride * vertices.count);
        let vertexBuffer = allocator.newBuffer(with: data, type: .vertex);
        
        let indexData = Data.init(bytes: faces.buffer.contents(), count: faces.bytesPerIndex * faces.count * faces.indexCountPerPrimitive);
        let indexBuffer = allocator.newBuffer(with: indexData, type: .index);
        
        let submesh = MDLSubmesh(indexBuffer: indexBuffer,
                                 indexCount: faces.count * faces.indexCountPerPrimitive,
                                 indexType: .uInt32,
                                 geometryType: .triangles,
                                 material: nil);
        
        let vertexDescriptor = MDLVertexDescriptor();
        vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                                            format: .float3,
                                                            offset: 0,
                                                            bufferIndex: 0);
        vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: vertices.stride);
        
        let mesh = MDLMesh(vertexBuffer: vertexBuffer,
                           vertexCount: vertices.count,
                           descriptor: vertexDescriptor,
                           submeshes: [submesh])
        
        return mesh
    }
}
