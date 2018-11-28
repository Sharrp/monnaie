//
//  Settings.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/15.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit
import MultipeerConnectivity

enum SubscribableSetting: String {
  case currency
}

typealias SettingUpdateCallback = () -> Void

class Settings {
  private let syncNameKey = "syncNameKey"
  private let peerIDKey = "peerIDKey"
  private let currencyKey = "currencyKey"
  
  private var callbacks = [String: [SettingUpdateCallback]]()
  func subscribe(callback: @escaping SettingUpdateCallback, forSetting setting: SubscribableSetting) {
    let key = setting.rawValue
    if callbacks.keys.contains(key) {
      callbacks[key]?.append(callback)
    } else {
      callbacks[key] = [callback]
    }
  }
  
  private func notifySubscribers(aboutSettingUpdate setting: SubscribableSetting) {
    guard let settingCallbacks = callbacks[setting.rawValue] else { return }
    for callback in settingCallbacks {
      callback()
    }
  }
  
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
  
  var userCurrency: Currency? {
    get {
      guard let currencyCode = UserDefaults.standard.string(forKey: currencyKey) else { return nil }
      return Currency(withCode: currencyCode)
    }
    
    set {
      guard let code = newValue?.code else { return }
      UserDefaults.standard.set(code, forKey: currencyKey)
      UserDefaults.standard.synchronize()
      notifySubscribers(aboutSettingUpdate: SubscribableSetting.currency)
    }
  }
}
