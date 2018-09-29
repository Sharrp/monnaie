//
//  ColorfulView.swift
//  colorful
//
//  Created by Anton Vronskii on 2018/09/27.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

// All values are related to screen's width
class ColorfulView: UIView {
  private struct CircleInfo {
    let radius: CGFloat
    let topLeft: CGPoint
    let hex: Int
  }
  
  private var circles = [UIView]()
  private let circlesInfo = [
    CircleInfo(radius: 0.61, topLeft: CGPoint(x: -0.11, y: -0.04), hex: 0x003061), // dark blue
    CircleInfo(radius: 0.65, topLeft: CGPoint(x: -0.15, y: -0.32), hex: 0x067FAB), // blue
    CircleInfo(radius: 0.52, topLeft: CGPoint(x: 0.04, y: -0.35), hex: 0x0ACAD1), // light blue
    CircleInfo(radius: 0.25, topLeft: CGPoint(x: 0.62, y: -0.07), hex: 0x03AC91), // green
    CircleInfo(radius: 0.18, topLeft: CGPoint(x: 0.46, y: 0.3), hex: 0x03AC91), // green
    CircleInfo(radius: 0.23, topLeft: CGPoint(x: -0.19, y: 0.31), hex: 0x323aa0), // violet
    CircleInfo(radius: 0.08, topLeft: CGPoint(x: -0.04, y: 0.30), hex: 0xDF5EBD), // pink small
    CircleInfo(radius: 0.11, topLeft: CGPoint(x: -0.02, y: 0.7), hex: 0xDF5EBD), // pink middle
    CircleInfo(radius: 0.18, topLeft: CGPoint(x: 0.69, y: 0.38), hex: 0xDF5EBD), // pink large
  ].reversed()
  private let darkCover = UIView()
  private let blurView = CustomBlurView(withRadius: 60)
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
    backgroundColor = UIColor(hex: 0x031022)
    darkCover.backgroundColor = .black
    darkCover.alpha = isOledScreen() ? 0.3 : 0.45
    addSubview(blurView)
    sendSubview(toBack: blurView)
    addSubview(darkCover)
    sendSubview(toBack: darkCover)
    
    for info in circlesInfo {
      let circle = UIView()
      circle.backgroundColor = UIColor(hex: info.hex)
      addSubview(circle)
      circles.append(circle)
      sendSubview(toBack: circle)
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    for (i, info) in circlesInfo.enumerated() {
      let radius = frame.width * info.radius
      let origin = CGPoint(x: frame.width * info.topLeft.x,
                           y: frame.height * info.topLeft.y)
      circles[i].frame = CGRect(origin: origin, size: CGSize(width: 2*radius, height: 2*radius))
      circles[i].layer.cornerRadius = radius
    }
    
    darkCover.frame = bounds
    blurView.frame = bounds
    
    if !animationStarted {
      startAnimation()
    }
  }
  
  private var animationStarted: Bool {
    guard circles.count > 0 else { return false }
    guard let animationKeys = circles[0].layer.animationKeys() else { return false }
    return animationKeys.count > 0
  }
  
  private func startAnimation() {
    for circle in circles {
      let clockwise = arc4random() % 2 == 0
      let rotationRadius = 20 + 6 * CGFloat(arc4random()) / CGFloat(UINT32_MAX)
      let circlePath = UIBezierPath(arcCenter: circle.center, radius: rotationRadius, startAngle: 0, endAngle: .pi*2, clockwise: clockwise)
      
      let animation = CAKeyframeAnimation(keyPath: #keyPath(CALayer.position))
      animation.duration = 5 + 6 * Double(arc4random()) / Double(UINT32_MAX)
      animation.repeatCount = MAXFLOAT
      animation.path = circlePath.cgPath
      circle.layer.add(animation, forKey: nil)
    }
  }
  
  // I'm really sorry for how ugly this is
  // but it's used only for appearance nuance
  private func isOledScreen() -> Bool {
    guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
    let screenHeight = UIScreen.main.nativeBounds.height
    return screenHeight == 2436 || // iPhone X, Xs
      screenHeight == 2688 // iPhone Xs Max
  }
}

// Origin: https://gist.github.com/afshin-hoseini/9c370268ffa4c43b0696
private class CustomBlurView: UIVisualEffectView {
  private let blurEffect: UIBlurEffect
  
  public convenience init() {
    self.init(withRadius: 0)
  }
  
  public init(withRadius radius: CGFloat) {
    let customBlurClass: AnyObject.Type = NSClassFromString("_UICustomBlurEffect")!
    let customBlurObject: NSObject.Type = customBlurClass as! NSObject.Type
    self.blurEffect = customBlurObject.init() as! UIBlurEffect
    self.blurEffect.setValue(1.0, forKeyPath: "scale")
    self.blurEffect.setValue(radius, forKeyPath: "blurRadius")
    super.init(effect: radius == 0 ? nil : self.blurEffect)
  }
  
  required public init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
