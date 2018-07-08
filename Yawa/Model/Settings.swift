//
//  Settings.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/15.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit
import MultipeerConnectivity

struct Settings {
  static var main: Settings = {
    return Settings()
  }()
  
  private let syncNameKey = "syncNameKey"
  private let peerIDKey = "peerIDKey"
  private let didChangeDefaultIconKey = "didChangeDefaultIconKey"
  
  var syncName: String {
    get {
      guard let savedName = UserDefaults.standard.value(forKey: syncNameKey) as? String else { return UIDevice.current.name }
      return savedName
    }
    
    set {
      UserDefaults.standard.set(newValue, forKey: syncNameKey)
      UserDefaults.standard.synchronize()
    }
  }
  
  var devicePeerID: MCPeerID? {
    get {
      guard let peerIDData = UserDefaults.standard.data(forKey: peerIDKey) else { return nil }
      return NSKeyedUnarchiver.unarchiveObject(with: peerIDData) as? MCPeerID
    }
    
    set(peerID) {
      guard let peerID = peerID else { return }
      let peerIDData = NSKeyedArchiver.archivedData(withRootObject: peerID)
      UserDefaults.standard.set(peerIDData, forKey: peerIDKey)
      UserDefaults.standard.synchronize()
    }
  }
  
  var didChangeDefaultIcon: Bool {
    get {
      return UserDefaults.standard.bool(forKey: didChangeDefaultIconKey)
    }
    
    set {
      UserDefaults.standard.set(newValue, forKey: didChangeDefaultIconKey)
      UserDefaults.standard.synchronize()
    }
  }
}
