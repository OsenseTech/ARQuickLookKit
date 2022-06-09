//
//  VirtualObjectLoader.swift
//  
//
//  Created by 蘇健豪 on 2022/6/8.
//

import SceneKit

@objc
public class VirtualObjectLoader: NSObject {
    
    public enum LoadObjectError: Error {
        case sceneViewPrepareFailed
    }
    
    private let sceneView: SCNSceneRenderer
    
    var loadedObjectTable: [String: Int] = [:]
    
    @objc
    public var loadedObjects: [VirtualObject] = []
    
    @objc
    public init(sceneView: SCNSceneRenderer) {
        self.sceneView = sceneView
    }
    
    public func loadVirtualObject(_ object: VirtualObject, loadedHandler: @escaping (Result<VirtualObject, LoadObjectError>) -> Void) {
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
    
    public func loadVirtualObject(_ object: VirtualObject, key: String) {
        loadObject(object) { result in
            if case let .success(object) = result {
                self.loadedObjects.append(object)
                self.loadedObjectTable[key] = self.loadedObjects.count - 1
            }
        }
    }
    
    public func loadObject(_ object: VirtualObject, loadedHandler: @escaping (Result<VirtualObject, LoadObjectError>) -> Void) {
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
    
    public func getObject(for key: String) -> VirtualObject? {
        guard let index = loadedObjectTable[key] else { return nil }
        let object = loadedObjects[index]
        
        return object
    }
    
}
