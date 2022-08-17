//
//  VirtualReferenceObject.swift
//  
//
//  Created by 蘇健豪 on 2022/8/10.
//

import SceneKit
import ARKit

public class VirtualReferenceObject: SCNReferenceNode, VirtualObjectProtocol {
    
    public var allowedAlignment: ARRaycastQuery.TargetAlignment
    
    public var anchor: ARAnchor?
    
    public var raycast: ARTrackedRaycast?
    
    public var shouldUpdateAnchor: Bool = false
    
    public var isPlaced = false
    
    public var objectType: ObjectType
    
    public init?(url: URL, allowedAlignment: ARRaycastQuery.TargetAlignment, objectType: ObjectType = .object) {
        self.allowedAlignment = allowedAlignment
        self.objectType = objectType
        
        super.init(url: url)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    }
    
}

