//
//  SyncPermissionsManager.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/06/23.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import Foundation

class SyncPermissionsManager {
  private let storeManager = StoreManager()
  private var allowedDeviceIDs: [String]
  
  init() {
    allowedDeviceIDs = storeManager.loadPermissions()
  }
  
  func isAllowedToSync(withDeviceID deviceID: String) -> Bool {
    return allowedDeviceIDs.contains(deviceID)
  }
  
  func allowSync(withDeviceID deviceID: String) {
    if !allowedDeviceIDs.contains(deviceID) {
      allowedDeviceIDs.append(deviceID)
      storeManager.save(permissions: allowedDeviceIDs)
    }
  }
  
  func denySync(withDeviceID deviceID: String) {
    if let index = allowedDeviceIDs.index(of: deviceID) {
      allowedDeviceIDs.remove(at: index)
      storeManager.save(permissions: allowedDeviceIDs)
    }
  }
}
