//
//  Settings.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/15.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

struct Settings {
  static var main: Settings = {
    return Settings()
  }()
  
  private let syncNameKey = "syncNameKey"
  
  var syncName: String {
    get {
      if let savedName = UserDefaults.standard.value(forKey: syncNameKey) as? String {
        return savedName
      } else {
        return UIDevice.current.name
      }
    }
    
    set {
      UserDefaults.standard.set(newValue, forKey: syncNameKey)
      UserDefaults.standard.synchronize()
    }
  }
}
