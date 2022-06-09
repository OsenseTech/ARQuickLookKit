//
//  SCNNodeExtension.swift
//  ARObjectInteraction
//
//  Created by 蘇健豪 on 2022/5/26.
//

import SceneKit

extension SCNNode {
    
    var scaleRatio: Float {
        set {
            self.scale = SCNVector3(x: newValue, y: newValue, z: newValue)
        }
        
        get {
            self.scale.x
        }
    }
    
}
