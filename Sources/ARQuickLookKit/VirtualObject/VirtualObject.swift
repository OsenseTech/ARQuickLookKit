//
//  VirtualObject.swift
//  ARObjectInteraction
//
//  Created by 蘇健豪 on 2022/5/24.
//

import SceneKit
import ARKit

public class VirtualObject: SCNReferenceNode {
    
    /// The alignments that are allowed for a virtual object.
    var allowedAlignment: ARRaycastQuery.TargetAlignment {
        .horizontal
    }
    
    /// Rotates the first child node of a virtual object.
    /// - Note: For correct rotation on horizontal and vertical surfaces, rotate around
    /// local y rather than world y.
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
    
    /// The object's corresponding ARAnchor.
    var anchor: ARAnchor?
    
    /// The associated tracked raycast used to place this object.
    var raycast: ARTrackedRaycast?
    
    /// Flag that indicates the associated anchor should be updated
    /// at the end of a pan gesture or when the object is repositioned.
    var shouldUpdateAnchor = false
    
    func stopTrackedRaycast() {
        raycast?.stopTracking()
        raycast = nil
    }
    
    /// Returns a `VirtualObject` if one exists as an ancestor to the provided node.
    static func existingObjectContainingNode(_ node: SCNNode) -> VirtualObject? {
        if let virtualObjectRoot = node as? VirtualObject {
            return virtualObjectRoot
        }
        
        guard let parent = node.parent else { return nil }
        
        // Recurse up to check if the parent is a `VirtualObject`.
        return existingObjectContainingNode(parent)
    }
}
