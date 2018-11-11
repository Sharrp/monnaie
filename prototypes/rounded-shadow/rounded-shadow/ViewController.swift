//
//  ViewController.swift
//  rounded-shadow
//
//  Created by Anton Vronskii on 2018/11/08.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
  @IBOutlet weak var shadowView: UIView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    shadowView.set(cornerRadius: 8, forCorners: [.topLeft, .bottomRight],
                   shadowRadius: 4, shadowColor: UIColor(white: 0.84, alpha: 1), shadowOpacity: 0.35)
  }
}

extension UIView {
  func set(cornerRadius: CGFloat, forCorners corners: UIRectCorner,
           shadowRadius: CGFloat, shadowColor: UIColor, shadowOpacity: Float) {
    let countour = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners,
                                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
    
      layer.masksToBounds = false
    layer.shadowOffset = CGSize()
    layer.shadowColor = shadowColor.cgColor
    layer.shadowRadius = shadowRadius
    layer.shadowOpacity = shadowOpacity
    layer.shadowPath = countour
    
    let shapeLayer = CALayer()
    shapeLayer.frame = self.layer.bounds
    let maskLayer = CAShapeLayer()
    maskLayer.path = countour
    shapeLayer.mask = maskLayer
    layer.addSublayer(shapeLayer)
    
    let bgColor = backgroundColor!.cgColor
    backgroundColor = nil
    layer.backgroundColor = UIColor.clear.cgColor
    shapeLayer.backgroundColor = bgColor
  }
  
  func set(radius: CGFloat, forCormers corners: UIRectCorner) {
    let path = UIBezierPath(roundedRect: bounds,
                            byRoundingCorners: corners,
                            cornerRadii: CGSize(width: radius, height: radius))
    let maskLayer = CAShapeLayer()
    maskLayer.path = path.cgPath
    layer.mask = maskLayer
  }
}

