//
//  GestureHandler.swift
//  
//
//  Created by 蘇健豪 on 2022/6/8.
//

import ARKit

public class GestureHandler: NSObject {
    
    private let sceneView: ARSCNView
    private let viewController: ARViewControllerProtocol
    private let gestures: [Gesture]
    
    public enum Gesture {
        /// 點擊改變位置
        case tap
        
        /// 拖曳
        case pan
        
        /// 旋轉
        case rotate
        
        /// 縮放
        case pinch
    }
    
    public init(sceneView: ARSCNView, viewController: ARViewControllerProtocol, gestures: [Gesture]) {
        self.sceneView = sceneView
        self.viewController = viewController
        self.gestures = gestures
        super.init()
        
        setup()
    }
    
    public func setup() {
        DispatchQueue.main.async {
            self.setupGesture()
        }
    }
    
    private func setupGesture() {
        if gestures.contains(.tap) {
            setupTapGesture()
        }
        if gestures.contains(.pan) {
            setupPanGestureRecognizer()
        }
        if gestures.contains(.rotate) {
            setupRotateGestureRecognizer()
        }
        if gestures.contains(.pinch) {
            setupPinchGestureRecognizer()
        }
        
        func setupTapGesture() {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
            tapGesture.delegate = self
            sceneView.addGestureRecognizer(tapGesture)
        }
        
        func setupPanGestureRecognizer() {
            let panGesture = ThresholdPanGesture(target: self, action: #selector(didPan(_:)))
            panGesture.delegate = self
            sceneView.addGestureRecognizer(panGesture)
        }
        
        func setupRotateGestureRecognizer() {
            let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(didRotate(_:)))
            rotationGesture.delegate = self
            sceneView.addGestureRecognizer(rotationGesture)
        }
        
        func setupPinchGestureRecognizer() {
            let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
            pinchGesture.delegate = self
            sceneView.addGestureRecognizer(pinchGesture)
        }
    }
    
    // MARK: - TapGesture
    
    @objc
    private func handleTapGesture(_ sender: UITapGestureRecognizer) {
        guard let object = viewController.virtualObjectLoader.loadedObjects.last else { return }
        
        let touchLocation = sender.location(in: sceneView)
        
        if object.isLoaded {
            placeVirtualObject(object, at: touchLocation)
        } else {
            self.viewController.virtualObjectLoader.loadVirtualObject(object) { result in
                switch result {
                    case let .success(object):
                        placeVirtualObject(object, at: touchLocation)
                        
                    case let .failure(error):
                        print(error.localizedDescription)
                }
            }
        }
        
        func placeVirtualObject(_ object: VirtualObject, at position: CGPoint) {
            object.stopTrackedRaycast()
            
            if let query = sceneView.raycastQuery(from: position, allowing: .estimatedPlane, alignment: object.allowedAlignment),
               let raycast = createTrackedRaycastAndSet3DPosition(of: object, from: query) {
                object.raycast = raycast
            } else {
                // If the tracked raycast did not succeed, simply update the anchor to the object's current position.
                object.shouldUpdateAnchor = false
                viewController.updateQueue.async {
                    self.addOrUpdateAnchor(for: object)
                }
            }
        }
    }
        
    // MARK: - PanGesture
    
    private var gestureEffectObject: VirtualObject?
    
    /// The tracked screen position used to update the `trackedObject`'s position.
    private var currentTrackingPosition: CGPoint?
    
    @objc
    private func didPan(_ gesture: ThresholdPanGesture) {
        switch gesture.state {
            case .began:
                // Check for an object at the touch location.
                if let object = objectInteracting(with: gesture, in: sceneView) {
                    gestureEffectObject = object
                }
                
            case .changed where gesture.isThresholdExceeded:
                guard let object = gestureEffectObject else { return }
                // Move an object if the displacment threshold has been met.
                translate(object, basedOn: updatedTrackingPosition(for: object, from: gesture))
                
                gesture.setTranslation(.zero, in: sceneView)
                
            case .changed:
                // Ignore the pan gesture until the displacment threshold is exceeded.
                break
                
            case .ended:
                // Update the object's position when the user stops panning.
                guard let object = gestureEffectObject else { break }
                setDown(object, basedOn: updatedTrackingPosition(for: object, from: gesture))
                
                fallthrough
                
            default:
                // Reset the current position tracking.
                currentTrackingPosition = nil
                gestureEffectObject = nil
        }
    }
    
    /** A helper method to return the first object that is found under the provided `gesture`s touch locations.
     Performs hit tests using the touch locations provided by gesture recognizers. By hit testing against the bounding
     boxes of the virtual objects, this function makes it more likely that a user touch will affect the object even if the
     touch location isn't on a point where the object has visible content. By performing multiple hit tests for multitouch
     gestures, the method makes it more likely that the user touch affects the intended object.
     - Tag: TouchTesting
     */
    private func objectInteracting(with gesture: UIGestureRecognizer, in view: ARSCNView) -> VirtualObject? {
        for index in 0..<gesture.numberOfTouches {
            let touchLocation = gesture.location(ofTouch: index, in: view)
            
            // Look for an object directly under the `touchLocation`.
            if let object = virtualObject(at: touchLocation) {
                return object
            }
        }
        
        // As a last resort look for an object under the center of the touches.
        if let center = gesture.center(in: view) {
            return virtualObject(at: center)
        }
        
        return nil
    }
    
    /// Hit tests against the `sceneView` to find an object at the provided point.
    private func virtualObject(at point: CGPoint) -> VirtualObject? {
        let hitTestOptions: [SCNHitTestOption: Any] = [.boundingBoxOnly: true]
        let hitTestResults = sceneView.hitTest(point, options: hitTestOptions)
        
        return hitTestResults.lazy.compactMap { result in
            return VirtualObject.existingObjectContainingNode(result.node)
        }.first
    }
    
    private func translate(_ object: VirtualObject, basedOn screenPos: CGPoint) {
        object.stopTrackedRaycast()
        
        // Update the object by using a one-time position request.
        if let query = sceneView.raycastQuery(from: screenPos, allowing: .estimatedPlane, alignment: object.allowedAlignment) {
            createRaycastAndUpdate3DPosition(of: object, from: query)
        }
    }
    
    private func createRaycastAndUpdate3DPosition(of virtualObject: VirtualObject, from query: ARRaycastQuery) {
        guard let result = sceneView.session.raycast(query).first else { return }
        
        if virtualObject.allowedAlignment == .any {
            // If an object that's aligned to a surface is being dragged, then
            // smoothen its orientation to avoid visible jumps, and apply only the translation directly.
            virtualObject.simdWorldPosition = result.worldTransform.translation
            
            let previousOrientation = virtualObject.simdWorldTransform.orientation
            let currentOrientation = result.worldTransform.orientation
            virtualObject.simdWorldOrientation = simd_slerp(previousOrientation, currentOrientation, 0.1)
        } else {
            self.setPosition(of: virtualObject, with: result)
        }
    }
    
    private func updatedTrackingPosition(for object: VirtualObject, from gesture: UIPanGestureRecognizer) -> CGPoint {
        let translation = gesture.translation(in: sceneView)
        
        let currentPosition = currentTrackingPosition ?? CGPoint(sceneView.projectPoint(object.position))
        let updatedPosition = CGPoint(x: currentPosition.x + translation.x, y: currentPosition.y + translation.y)
        currentTrackingPosition = updatedPosition
        return updatedPosition
    }
    
    private func setDown(_ object: VirtualObject, basedOn screenPos: CGPoint) {
        object.stopTrackedRaycast()
        
        // Prepare to update the object's anchor to the current location.
        object.shouldUpdateAnchor = true
        
        // Attempt to create a new tracked raycast from the current location.
        if let query = sceneView.raycastQuery(from: screenPos, allowing: .estimatedPlane, alignment: object.allowedAlignment),
           let raycast = createTrackedRaycastAndSet3DPosition(of: object, from: query) {
            object.raycast = raycast
        } else {
            // If the tracked raycast did not succeed, simply update the anchor to the object's current position.
            object.shouldUpdateAnchor = false
            viewController.updateQueue.async {
                self.addOrUpdateAnchor(for: object)
            }
        }
    }
    
    // MARK: - RotateGesture
    
    /**
     For looking down on the object (99% of all use cases), you subtract the angle.
     To make rotation also work correctly when looking from below the object one would have to
     flip the sign of the angle depending on whether the object is above or below the camera.
     - Tag: didRotate */
    @objc
    private func didRotate(_ gesture: UIRotationGestureRecognizer) {
        guard gesture.state == .changed else { return }
        
        gestureEffectObject?.objectRotation -= Float(gesture.rotation)
        gesture.rotation = 0
    }
    
    public func setRotation(degrees: Float) {
        let radian = degrees / 180 * .pi
        gestureEffectObject?.objectRotation -= Float(radian)
    }
    
    // MARK: - PinchGesture
    
    @objc
    private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let object = gestureEffectObject else { return }
        
        switch gesture.state {
            case .changed:
                object.scaleRatio = Float(gesture.scale) * object.scaleRatio
                gesture.scale = 1
            default:
                break
        }
    }
    
    // MARK: - Set Position
    
    private func createTrackedRaycastAndSet3DPosition(of object: VirtualObject, from query: ARRaycastQuery) -> ARTrackedRaycast? {
        return sceneView.session.trackedRaycast(query) { [weak self] (results) in
            guard let self = self else { return }
            self.setVirtualObject3DPosition(results, with: object)
        }
    }
    
    private func setVirtualObject3DPosition(_ results: [ARRaycastResult], with object: VirtualObject) {
        guard let result = results.first else {
            fatalError("Unexpected case: the update handler is always supposed to return at least one result.")
        }
        
        setPosition(of: object, with: result)
        
        if object.parent == nil {
            self.sceneView.scene.rootNode.addChildNode(object)
            object.shouldUpdateAnchor = true
        }
        
        if object.shouldUpdateAnchor {
            object.shouldUpdateAnchor = false
            viewController.updateQueue.async {
                self.addOrUpdateAnchor(for: object)
            }
        }
    }
    
    private func setPosition(of object: VirtualObject, with result: ARRaycastResult) {
        object.position = SCNVector3(x: result.worldTransform.columns.3.x,
                                     y: result.worldTransform.columns.3.y,
                                     z: result.worldTransform.columns.3.z)
    }
    
    func addOrUpdateAnchor(for object: VirtualObject) {
        if let anchor = object.anchor {
            sceneView.session.remove(anchor: anchor)
        }
        
        let newAnchor = ARAnchor(transform: object.simdWorldTransform)
        object.anchor = newAnchor
        sceneView.session.add(anchor: newAnchor)
    }
    
}

extension GestureHandler: UIGestureRecognizerDelegate {
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
}

/// Extends `UIGestureRecognizer` to provide the center point resulting from multiple touches.
private extension UIGestureRecognizer {
    func center(in view: UIView) -> CGPoint? {
        guard numberOfTouches > 0 else { return nil }
        
        let first = CGRect(origin: location(ofTouch: 0, in: view), size: .zero)
        
        let touchBounds = (1..<numberOfTouches).reduce(first) { touchBounds, index in
            return touchBounds.union(CGRect(origin: location(ofTouch: index, in: view), size: .zero))
        }
        
        return CGPoint(x: touchBounds.midX, y: touchBounds.midY)
    }
}

fileprivate extension float4x4 {
    /**
     Treats matrix as a (right-hand column-major convention) transform matrix
     and factors out the translation component of the transform.
     */
    var translation: SIMD3<Float> {
        get {
            let translation = columns.3
            return [translation.x, translation.y, translation.z]
        }
        
        set(newValue) {
            columns.3 = [newValue.x, newValue.y, newValue.z, columns.3.w]
        }
    }
    
    /**
     Factors out the orientation component of the transform.
     */
    var orientation: simd_quatf {
        return simd_quaternion(self)
    }
}


fileprivate extension CGPoint {
    /// Extracts the screen space point from a vector returned by SCNView.projectPoint(_:).
    init(_ vector: SCNVector3) {
        self.init(x: CGFloat(vector.x), y: CGFloat(vector.y))
    }
}
