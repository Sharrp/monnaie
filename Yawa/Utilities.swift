//
//  Utilities.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

func deviceUniqueIdentifier() -> String {
  if let uuid = UIDevice.current.identifierForVendor?.uuidString {
    return uuid
  }
  return "\(UIDevice.current.name.hashValue)"
}
