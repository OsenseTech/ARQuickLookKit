//
//  VirtualObjectLoaderExtension.swift
//  
//
//  Created by 蘇健豪 on 2022/6/9.
//

import Foundation
import ARQuickLookKit

extension VirtualObjectLoader {
    @objc
    public func loadVirtualObjectObjC(_ object: VirtualObject, loadedHandler: @escaping (Bool) -> Void) {
        loadObject(object) { result in
            switch result {
                case let .success(object):
                    self.loadedObjects.append(object)
                    loadedHandler(true)
                case .failure(_):
                    loadedHandler(false)
            }
        }
    }
}
