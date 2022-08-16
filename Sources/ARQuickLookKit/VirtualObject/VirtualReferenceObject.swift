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
    
    init?(url: URL,
          allowedAlignment: ARRaycastQuery.TargetAlignment,
          anchor: ARAnchor? = nil,
          raycast: ARTrackedRaycast? = nil,
          shouldUpdateAnchor: Bool = false,
          isPlaced: Bool = false,
          objectType: ObjectType) {
        self.allowedAlignment = allowedAlignment
        self.anchor = anchor
        self.raycast = raycast
        self.shouldUpdateAnchor = shouldUpdateAnchor
        self.isPlaced = isPlaced
        self.objectType = objectType
        
        super.init(url: url)
    }
    
    public override func copy(with zone: NSZone? = nil) -> Any {
        let copyObject = VirtualReferenceObject(url: referenceURL,
                                                allowedAlignment: allowedAlignment,
                                                anchor: anchor,
                                                raycast: raycast,
                                                shouldUpdateAnchor: shouldUpdateAnchor,
                                                isPlaced: isPlaced,
                                                objectType: objectType)
        copyObject?.geometry = self.geometry
        copyObject?.name = self.name
        copyObject?.scale = self.scale
        copyObject?.eulerAngles = self.eulerAngles
        
        return copyObject as Any
    }
}

