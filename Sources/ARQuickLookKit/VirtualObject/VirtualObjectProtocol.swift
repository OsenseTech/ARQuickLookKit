//
//  VirtualObjectProtocol.swift
//  
//
//  Created by 蘇健豪 on 2022/8/10.
//

import SceneKit
import ARKit

public enum ObjectType {
    case object
    case light
}

public protocol VirtualObjectProtocol: SCNNode {
    /// The alignments that are allowed for a virtual object.
    var allowedAlignment: ARRaycastQuery.TargetAlignment { get }
    
    /// Rotates the first child node of a virtual object.
    /// - Note: For correct rotation on horizontal and vertical surfaces, rotate around
    /// local y rather than world y.
    var objectRotation: Float { get set }
    
    /// The object's corresponding ARAnchor.
    var anchor: ARAnchor? { get set }
    
    /// The associated tracked raycast used to place this object.
    var raycast: ARTrackedRaycast? { get set }
    
    /// Flag that indicates the associated anchor should be updated
    /// at the end of a pan gesture or when the object is repositioned.
    var shouldUpdateAnchor: Bool { get set }
    
    var isPlaced: Bool { get set }
    
    var objectType: ObjectType { get set }
    
    func stopTrackedRaycast()
    
    /// Returns a `VirtualObject` if one exists as an ancestor to the provided node.
    static func existingObjectContainingNode(_ node: SCNNode) -> VirtualObjectProtocol?
}


public extension VirtualObjectProtocol {
    
    var objectRotation: Float {
        get {
            if let node = childNodes.first {
                return node.eulerAngles.y
            } else {
                return 0
            }
        }
        
        set (newValue) {
            if let node = childNodes.first {
                node.eulerAngles.y = newValue
            }
        }
    }
    
    func stopTrackedRaycast() {
        raycast?.stopTracking()
        raycast = nil
    }
    
    static func existingObjectContainingNode(_ node: SCNNode) -> VirtualObjectProtocol? {
        if let virtualObjectRoot = node as? VirtualObjectProtocol {
            return virtualObjectRoot
        }
        
        guard let parent = node.parent else { return nil }
        
        // Recurse up to check if the parent is a `VirtualObject`.
        return existingObjectContainingNode(parent)
    }
}
