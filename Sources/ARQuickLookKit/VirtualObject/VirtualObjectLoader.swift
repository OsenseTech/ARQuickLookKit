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
    
    public var loadedObjectTable: [String: Int] = [:]
    public var isLoading = false
    
    public init() { }
    
    }
    
    public func loadVirtualObject(_ object: VirtualReferenceObject, key: String) {
        loadObject(object) { result in
            if case let .success(object) = result {
                self.loadedObjects.append(object)
                self.loadedObjectTable[key] = self.loadedObjects.count - 1
            }
        }
    }
    public func loadVirtualObject(_ object: VirtualReferenceObject, loadedHandler: @escaping (VirtualReferenceObject) -> Void) {
        isLoading = true
        loadedObjects.append(object)
        
        // Load the content into the reference node.
        DispatchQueue.global(qos: .userInitiated).async {
            object.load()
            self.isLoading = false
            loadedHandler(object)
        }
    }
    
    public func getObject(for key: String) -> VirtualObjectProtocol? {
        guard let index = loadedObjectTable[key] else { return nil }
        let object = loadedObjects[index]
        
        return object
    }
    
}
