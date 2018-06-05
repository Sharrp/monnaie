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

enum Currency {
  case JPY
}

func formatMoney(amount: Float, currency: Currency, symbolEnabled: Bool = true) -> String {
  return NSString(format: "%@%.0f", symbolEnabled ? "¥" : "", amount) as String
}

extension UIButton {
  func setBackgroundColor(color: UIColor, forState: UIControlState) {
    UIGraphicsBeginImageContext(CGSize(width: 1, height: 1))
    UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
    UIGraphicsGetCurrentContext()!.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
    let colorImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    self.setBackgroundImage(colorImage, for: forState)
    
//    UIGraphicsBeginImageContext(frame.size)
//    UIGraphicsGetCurrentContext()!.setFillColor(color.cgColor)
//    UIGraphicsGetCurrentContext()!.fill(bounds)
//    UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).addClip()
//    let colorImage = UIGraphicsGetImageFromCurrentImageContext()
//    UIGraphicsEndImageContext()
//    self.setBackgroundImage(colorImage, for: forState)
  }
}
