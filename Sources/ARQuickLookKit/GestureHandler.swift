//
//  GestureHandler.swift
//  
//
//  Created by 蘇健豪 on 2022/6/8.
//

import ARKit

public protocol GestureHandlerDelegate: AnyObject {
    func updatedTrackingPosition(_ position: CGPoint)
}

public class GestureHandler: NSObject {
    
    public weak var delegate: GestureHandlerDelegate?
    public var isEnable: Bool = true
    
    private weak var viewController: ARViewControllerProtocol?
    private let supportedGestures: [Gesture]
    
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
    
    public init(viewController: ARViewControllerProtocol, supportedGestures: [Gesture] = [.tap, .pan, .rotate, .pinch]) {
        self.viewController = viewController
        self.supportedGestures = supportedGestures
        super.init()
        
        setup()
    }
    
    public func setup() {
        DispatchQueue.main.async {
            self.setupGesture()
        }
    }
    
    private func setupGesture() {
        weak var _self = self
        guard let sceneView = _self?.viewController?.sceneView else { return }
        
        if supportedGestures.contains(.tap) {
            setupTapGesture()
        }
        if supportedGestures.contains(.pan) {
            setupPanGestureRecognizer()
        }
        if supportedGestures.contains(.rotate) {
            setupRotateGestureRecognizer()
        }
        if supportedGestures.contains(.pinch) {
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
        weak var _self = self
        
        func placeVirtualObject(_ object: any VirtualObjectProtocol, at position: CGPoint) {
            object.stopTrackedRaycast()
            guard let sceneView = _self?.viewController?.sceneView else { return }
            
            if let query = sceneView.raycastQuery(from: position, allowing: .estimatedPlane, alignment: object.allowedAlignment),
               let raycast = createTrackedRaycastAndSet3DPosition(of: object, from: query) {
                object.raycast = raycast
            } else {
                // If the tracked raycast did not succeed, simply update the anchor to the object's current position.
                object.shouldUpdateAnchor = false
                _self?.viewController?.updateQueue.async {
                    self.addOrUpdateAnchor(for: object)
                }
            }
        }
        
        guard isEnable else { return }
        guard let loadedObjects = viewController?.virtualObjectLoader.loadedObjects else { return }
        guard let sceneView = viewController?.sceneView else { return }
        let touchLocation = sender.location(in: sceneView)
        
        for object in loadedObjects {
            placeVirtualObject(object, at: touchLocation)
        }
    }
        
    // MARK: - PanGesture
    
    private var gestureEffectObject: (any VirtualObjectProtocol)?
    
    /// The tracked screen position used to update the `trackedObject`'s position.
    private var currentTrackingPosition: CGPoint?
    
    @objc
    private func didPan(_ gesture: ThresholdPanGesture) {
        guard isEnable else { return }
        guard let sceneView = viewController?.sceneView else { return }
        
        switch gesture.state {
            case .began:
                // Check for an object at the touch location.
                if let object = objectInteracting(with: gesture, in: sceneView) {
                    gestureEffectObject = object
                }
                
            case .changed where gesture.isThresholdExceeded:
                guard let object = gestureEffectObject else { return }
                // Move an object if the displacment threshold has been met.
                let position = updatedTrackingPosition(for: object, from: gesture)
                translate(object, basedOn: position)
                delegate?.updatedTrackingPosition(position)
                
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
    private func objectInteracting(with gesture: UIGestureRecognizer, in view: ARSCNView) -> (any VirtualObjectProtocol)? {
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
    private func virtualObject(at point: CGPoint) -> (any VirtualObjectProtocol)? {
        let hitTestOptions: [SCNHitTestOption: Any] = [.boundingBoxOnly: true]
        guard let sceneView = viewController?.sceneView else { return nil }
        let hitTestResults = sceneView.hitTest(point, options: hitTestOptions)
        
        return hitTestResults.lazy.compactMap { result in
            VirtualObject.existingObjectContainingNode(result.node)
        }.first
    }
    
    public func translate(_ object: any VirtualObjectProtocol, basedOn screenPos: CGPoint) {
        weak var _self = self
        
        func createRaycastAndUpdate3DPosition(of virtualObject: any VirtualObjectProtocol, from query: ARRaycastQuery) {
            guard let result = _self?.viewController?.sceneView.session.raycast(query).first else { return }
            
            if virtualObject.allowedAlignment == .any {
                guard let gestureEffectObject = _self?.gestureEffectObject else { return }
                guard virtualObject == gestureEffectObject else { return }
                
                // If an object that's aligned to a surface is being dragged, then
                // smoothen its orientation to avoid visible jumps, and apply only the translation directly.
                virtualObject.simdWorldPosition = result.worldTransform.translation
                
                let previousOrientation = virtualObject.simdWorldTransform.orientation
                let currentOrientation = result.worldTransform.orientation
                virtualObject.simdWorldOrientation = simd_slerp(previousOrientation, currentOrientation, 0.1)
            } else {
                _self?.setPosition(of: virtualObject, with: result)
            }
        }
        
        object.stopTrackedRaycast()
        
        // Update the object by using a one-time position request.
        guard let sceneView = viewController?.sceneView else { return }
        if let query = sceneView.raycastQuery(from: screenPos, allowing: .estimatedPlane, alignment: object.allowedAlignment) {
            createRaycastAndUpdate3DPosition(of: object, from: query)
        }
    }
    
    private func updatedTrackingPosition(for object: any VirtualObjectProtocol, from gesture: UIPanGestureRecognizer) -> CGPoint {
        guard let sceneView = viewController?.sceneView else { fatalError() }
        let translation = gesture.translation(in: sceneView)
        
        let currentPosition = currentTrackingPosition ?? CGPoint(sceneView.projectPoint(object.position))
        let updatedPosition = CGPoint(x: currentPosition.x + translation.x, y: currentPosition.y + translation.y)
        currentTrackingPosition = updatedPosition
        return updatedPosition
    }
    
    private func setDown(_ object: any VirtualObjectProtocol, basedOn screenPos: CGPoint) {
        object.stopTrackedRaycast()
        
        // Prepare to update the object's anchor to the current location.
        object.shouldUpdateAnchor = true
        
        // Attempt to create a new tracked raycast from the current location.
        guard let sceneView = viewController?.sceneView else { return }
        if let query = sceneView.raycastQuery(from: screenPos, allowing: .estimatedPlane, alignment: object.allowedAlignment),
           let raycast = createTrackedRaycastAndSet3DPosition(of: object, from: query) {
            object.raycast = raycast
        } else {
            // If the tracked raycast did not succeed, simply update the anchor to the object's current position.
            object.shouldUpdateAnchor = false
            viewController?.updateQueue.async {
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
        guard isEnable else { return }
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
        guard isEnable else { return }
        guard let sceneView = viewController?.sceneView else { return }
        
        switch gesture.state {
            case .began:
                if let object = objectInteracting(with: gesture, in: sceneView) {
                    gestureEffectObject = object
                }
                
            case .changed:
                guard let object = gestureEffectObject else { return }
                
                object.scaleRatio = object.scaleRatio * Float(gesture.scale)
                gesture.scale = 1
                
            case .ended:
                gestureEffectObject = nil
                
            default:
                break
        }
    }
    
    // MARK: - Set Position
    
    private func createTrackedRaycastAndSet3DPosition(of object: any VirtualObjectProtocol, from query: ARRaycastQuery) -> ARTrackedRaycast? {
        guard let sceneView = viewController?.sceneView else { return nil }
        
        return sceneView.session.trackedRaycast(query) { [weak self] (results) in
            guard let self = self else { return }
            self.setVirtualObject3DPosition(results, with: object)
        }
    }
    
    private func setVirtualObject3DPosition(_ results: [ARRaycastResult], with object: any VirtualObjectProtocol) {
        guard let result = results.first else {
            fatalError("Unexpected case: the update handler is always supposed to return at least one result.")
        }
        guard let sceneView = viewController?.sceneView else { return }
        
        setPosition(of: object, with: result)
        
        if object.parent == nil {
            sceneView.scene.rootNode.addChildNode(object)
            object.shouldUpdateAnchor = true
        }
        
        if object.shouldUpdateAnchor {
            object.shouldUpdateAnchor = false
            viewController?.updateQueue.async {
                self.addOrUpdateAnchor(for: object)
            }
        }
    }
    
    private func setPosition(of object: any VirtualObjectProtocol, with result: ARRaycastResult) {
        object.position = SCNVector3(x: result.worldTransform.columns.3.x,
                                     y: result.worldTransform.columns.3.y,
                                     z: result.worldTransform.columns.3.z)
    }
    
    func addOrUpdateAnchor(for object: any VirtualObjectProtocol) {
        guard let sceneView = viewController?.sceneView else { return }
        
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
