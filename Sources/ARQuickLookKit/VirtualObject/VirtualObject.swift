//
//  VirtualObject.swift
//  ARObjectInteraction
//
//  Created by 蘇健豪 on 2022/5/24.
//

import SceneKit
import ARKit

public class VirtualObject: SCNNode, VirtualObjectProtocol {
    
    public var allowedAlignment: ARRaycastQuery.TargetAlignment
    
    public var anchor: ARAnchor?
    
    public var raycast: ARTrackedRaycast?
    
    public var shouldUpdateAnchor = false
    
    public var isPlaced = false
    
    public var objectType: ObjectType
    
    public var timer: Timer?
    
    public var playerLooper: AVPlayerLooper?
    
    public init(geometry: SCNGeometry?, allowedAlignment: ARRaycastQuery.TargetAlignment, objectType: ObjectType = .object) {
        self.allowedAlignment = allowedAlignment
        self.objectType = objectType
        super.init()
        
        self.geometry = geometry
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    deinit {
        invalidTimer()
    }
    
}
