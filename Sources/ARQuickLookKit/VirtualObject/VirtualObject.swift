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
    
    public init(geometry: SCNGeometry?, allowedAlignment: ARRaycastQuery.TargetAlignment, objectType: ObjectType = .object) {
        self.allowedAlignment = allowedAlignment
        self.objectType = objectType
        super.init()
        
        self.geometry = geometry
    }
    
    public init(allowedAlignment: ARRaycastQuery.TargetAlignment,
                anchor: ARAnchor?,
                raycast: ARTrackedRaycast?,
                shouldUpdateAnchor: Bool,
                isPlaced: Bool,
                objectType: ObjectType) {
        self.allowedAlignment = allowedAlignment
        self.anchor = anchor
        self.raycast = raycast
        self.shouldUpdateAnchor = shouldUpdateAnchor
        self.isPlaced = isPlaced
        self.objectType = objectType
        super.init()
    }
    
    public override func copy(with zone: NSZone? = nil) -> Any {
        let copyObject = VirtualObject(allowedAlignment: allowedAlignment,
                                       anchor: anchor,
                                       raycast: raycast,
                                       shouldUpdateAnchor: shouldUpdateAnchor,
                                       isPlaced: isPlaced,
                                       objectType: objectType)
        copyObject.geometry = self.geometry
        copyObject.name = self.name
        copyObject.scale = self.scale
        
        return copyObject
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
}
