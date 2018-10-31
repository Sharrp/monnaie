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
  return "\(UIDevice.current.name.hash)"
}

extension FileManager {
  func removeFiles(fromDirectory dirPath: String) {
    do {
      let files = try contentsOfDirectory(atPath: dirPath)
      for fileName in files {
        let filePath = dirPath + "/" + fileName
        try removeItem(atPath: filePath)
      }
    } catch let error {
      print("Error while cleaning directory \(dirPath): \(error)")
    }
  }
}

enum Currency {
  case JPY
}

func formatMoney(amount: Double, currency: Currency, symbolEnabled: Bool = true) -> String {
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
  }
}

extension UIColor {
  convenience init(red: Int, green: Int, blue: Int) {
    assert(red >= 0 && red <= 255, "Invalid red component")
    assert(green >= 0 && green <= 255, "Invalid green component")
    assert(blue >= 0 && blue <= 255, "Invalid blue component")
    
    self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
  }
  
  convenience init(hex: Int) {
    self.init(
      red: (hex >> 16) & 0xFF,
      green: (hex >> 8) & 0xFF,
      blue: hex & 0xFF
    )
  }
}

extension DateFormatter {
  convenience init(dateFormat: String) {
    self.init()
    self.dateFormat = dateFormat
  }
}

extension Date {
  init?(calendar: Calendar, year: Int, month: Int, day: Int = 1, nanoseconds: Int = 0) {
    var dateComponents = DateComponents()
    dateComponents.year = year
    dateComponents.month = month
    dateComponents.day = day
    dateComponents.nanosecond = nanoseconds
    guard let date = calendar.date(from: dateComponents) else { return nil }
    self = date
  }
  
  func isSameDay(date: Date) -> Bool {
    return Calendar.current.compare(self, to: date, toGranularity: .day) == .orderedSame
  }
}

struct Animation {
  static let duration = 0.3
  static let durationFast = 0.2
  static let appearceWithShfit: CGFloat = 10
}
