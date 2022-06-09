//
//  PositionHelper.swift
//  
//
//  Created by 蘇健豪 on 2022/6/9.
//

import Foundation
import ARKit
import ARQuickLookKit

/// Only for ObjC to easily access these two func
@objc public class PositionHelper: NSObject {
    
    private let virtualObjectLoader: VirtualObjectLoader
    private let gestureHandler: GestureHandler
    private let sceneView: ARSCNView
    private let updateQueue: DispatchQueue
    
    @objc
    public init(virtualObjectLoader: VirtualObjectLoader, gestureHandler: GestureHandler, sceneView: ARSCNView, updateQueue: DispatchQueue) {
        self.virtualObjectLoader = virtualObjectLoader
        self.gestureHandler = gestureHandler
        self.sceneView = sceneView
        self.updateQueue = updateQueue
    }
    
    @objc
    public func autoPlace(_ object: VirtualObject, at anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        guard object.parent == nil else { return }
        
        let x = Float(planeAnchor.transform.columns.3.x)
        let y = Float(planeAnchor.transform.columns.3.y)
        let z = Float(planeAnchor.transform.columns.3.z)
        let position = SCNVector3(x: x, y: y, z: z)
        
        place(object, at: position)
    }
    
    @objc
    public func place(_ object: VirtualObject, at position: SCNVector3) {
        guard object.parent == nil else { return }
        
        if object.isLoaded {
            setObject(object, position: position)
        } else {
            virtualObjectLoader.loadVirtualObject(object) { result in
                if case .success(_) = result {
                    setObject(object, position: position)
                }
            }
        }
        
        func setObject(_ object: VirtualObject, position: SCNVector3) {
            object.position = position
            
            if object.parent == nil {
                self.sceneView.scene.rootNode.addChildNode(object)
                object.shouldUpdateAnchor = true
            }
            
            if object.shouldUpdateAnchor {
                object.shouldUpdateAnchor = false
                self.updateQueue.async {
                    self.gestureHandler.addOrUpdateAnchor(for: object)
                }
            }
        }
    }
}
