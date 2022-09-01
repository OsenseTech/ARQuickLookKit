//
//  VirtualObjectLoader.swift
//  
//
//  Created by 蘇健豪 on 2022/6/8.
//

import SceneKit

public class VirtualObjectLoader {
    
    public enum LoadObjectError: Error {
        case sceneViewPrepareFailed
    }
    
    public var loadedObjects: [any VirtualObjectProtocol] = []
    
    public var isLoading = false
    
    public init() { }
    
    deinit {
        removeAllVirtualObject()
    }
    
    public func loadVirtualObject(_ object: VirtualReferenceObject, loadedHandler: @escaping (VirtualReferenceObject) -> Void) {
        guard !object.isLoaded else {
            self.loadedObjects.append(object)
            return loadedHandler(object)
        }
        
        isLoading = true
        loadedObjects.append(object)
        
        // Load the content into the reference node.
        DispatchQueue.global(qos: .userInitiated).async {
            object.load()
            self.isLoading = false
            loadedHandler(object)
        }
    }
    
    public func removeAllVirtualObject() {
        for index in loadedObjects.indices.reversed() {
            removeVirtualObject(at: index)
        }
    }
    
    public func removeVirtualObject(at index: Int) {
        guard loadedObjects.indices.contains(index) else { return }
        
        loadedObjects[index].stopTrackedRaycast()
        loadedObjects[index].removeFromParentNode()
        
        // Recoup resources allocated by the object.
        if let object = loadedObjects[index] as? VirtualReferenceObject {
            object.unload()
        }
        
        loadedObjects.remove(at: index)
    }
    
}
