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
    
    private let sceneView: SCNSceneRenderer
    
    public var loadedObjectTable: [String: Int] = [:]
    
    public var loadedObjects: [VirtualObjectProtocol] = []
    
    public init(sceneView: SCNSceneRenderer) {
        self.sceneView = sceneView
    }
    
    public func loadVirtualObject(_ object: VirtualReferenceObject, loadedHandler: @escaping (Result<VirtualReferenceObject, LoadObjectError>) -> Void) {
        if object.isLoaded {
            return loadedHandler(.success(object))
        }
        
        loadObject(object) { result in
            switch result {
                case let .success(object):
                    self.loadedObjects.append(object)
                    loadedHandler(.success(object))
                case let .failure(error):
                    loadedHandler(.failure(error))
            }
        }
    }
    
    public func loadVirtualObject(_ object: VirtualReferenceObject, key: String) {
        loadObject(object) { result in
            if case let .success(object) = result {
                self.loadedObjects.append(object)
                self.loadedObjectTable[key] = self.loadedObjects.count - 1
            }
        }
    }
    
    private func loadObject(_ object: VirtualReferenceObject, loadedHandler: @escaping (Result<VirtualReferenceObject, LoadObjectError>) -> Void) {
        // Load the content into the reference node.
        DispatchQueue.global(qos: .userInitiated).async {
            object.load()
            
            let scene: SCNScene
            do {
                scene = try SCNScene(url: object.referenceURL, options: nil)
            } catch {
                fatalError("Failed to load SCNScene from object.referenceURL")
            }
            
            self.sceneView.prepare([scene]) { success in
                DispatchQueue.main.async {
                    if success {
                        loadedHandler(.success(object))
                    } else {
                        loadedHandler(.failure(.sceneViewPrepareFailed))
                    }
                }
            }
        }
    }
    
    public func getObject(for key: String) -> VirtualObjectProtocol? {
        guard let index = loadedObjectTable[key] else { return nil }
        let object = loadedObjects[index]
        
        return object
    }
    
}
