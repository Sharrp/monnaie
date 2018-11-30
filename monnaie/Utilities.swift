//
//  Utilities.swift
//  monnaie
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
    } catch {
      print("Error while cleaning directory \(dirPath): \(error)")
    }
  }
}

func formatMoney(amount: Double, currency: Currency, symbolEnabled: Bool = true) -> String {
  let sign = symbolEnabled ? currency.sign : ""
  return NSString(format: "%@%.0f", sign, amount) as String
}

extension UIButton {
  func setBackgroundColor(color: UIColor, forState: UIControl.State) {
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

extension UIView {
  func set(radius: CGFloat, forCormers corners: UIRectCorner) {
    let path = UIBezierPath(roundedRect: bounds,
                            byRoundingCorners: corners,
                            cornerRadii: CGSize(width: radius, height: radius))
    let maskLayer = CAShapeLayer()
    maskLayer.path = path.cgPath
    layer.mask = maskLayer
  }
}

extension DateFormatter {
  convenience init(dateFormat: String) {
    self.init()
    self.dateFormat = dateFormat
  }
}

typealias TimestampRange = (start: TimeInterval, end: TimeInterval)

extension Date {
  static var secondsPerDay: TimeInterval {
    return 86400
  }
  
  static var now: Date {
    return Date()
  }
  
  init?(calendar: Calendar, year: Int, month: Int, day: Int = 1, nanoseconds: Int = 0) {
    var dateComponents = DateComponents()
    dateComponents.year = year
    dateComponents.month = month
    dateComponents.day = day
    dateComponents.nanosecond = nanoseconds
    guard let date = calendar.date(from: dateComponents) else { return nil }
    self = date
  }
  
  func isSame(_ granularity: Calendar.Component, asDate dateToCompare: Date) -> Bool {
    return Calendar.current.compare(self, to: dateToCompare, toGranularity: granularity) == .orderedSame
  }
  
  func date(bySettingDayTo value: Int) -> Date? {
    var components = Calendar.current.dateComponents([.day, .month, .year], from: self)
    components.day = value
    return Calendar.current.date(from: components)
  }
  
  func timestampRangeForMonth() -> TimestampRange {
    var components = DateComponents()
    components.day = 1
    components.month = Calendar.current.component(.month, from: self)
    components.year = Calendar.current.component(.year, from: self)
    let start = Calendar.current.date(from: components)!.timeIntervalSince1970
    
    let maxDayOfCurrentMonth = Calendar.current.range(of: .day, in: .month, for: self)!.count
    components.day = maxDayOfCurrentMonth
    let end = Calendar.current.date(from: components)!.timeIntervalSince1970 + Date.secondsPerDay // first second of the next month
    
    return (start: start, end: end)
  }
  
  func timestampRangeForDay() -> TimestampRange {
    let start = Calendar.current.startOfDay(for: self).timeIntervalSince1970
    return (start: start, end: start + Date.secondsPerDay)
  }
}

struct Animation {
  static let duration = 0.35
  static let durationFast = 0.3
  static let appearceWithShfit: CGFloat = 10
  static let dampingRatio: CGFloat = 0.7
  static let curve = UIView.AnimationCurve.easeInOut
  static let springTiming = UISpringTimingParameters(dampingRatio: Animation.dampingRatio)
}

struct Color {
  static let inactiveText = UIColor(hex: 0xAAAAAA)
  static let accentText = UIColor(hex: 0x333333)
  static let shadowColor = UIColor(white: 0.84, alpha: 1)
  static let background = UIColor(hex: 0xF9F9F9)
  static let cellBackground = UIColor(hex: 0xF2F2F6)
}
