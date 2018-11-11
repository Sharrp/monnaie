//
//  ShadowRoundedView.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/11.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class ShadowRoundedView: UIView {
  private let cornerRadius: CGFloat = 8
  var shadowRadius: CGFloat = 8 {
    didSet {
      layer.shadowRadius = shadowRadius
    }
  }
  private let shadowColor = Color.shadowColor.cgColor
  private let shadowOpacity: Float = 1
  private let shapeLayer = CALayer()
  
  var roundedCorners = UIRectCorner.allCorners {
    didSet {
      setNeedsLayout()
    }
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
    layer.masksToBounds = false
    layer.shadowOffset = CGSize()
    layer.shadowColor = shadowColor
    layer.shadowRadius = shadowRadius
    layer.shadowOpacity = shadowOpacity
    
    layer.insertSublayer(shapeLayer, at: 0)
    
    let bgColor = backgroundColor!.cgColor
    backgroundColor = nil
    layer.backgroundColor = UIColor.clear.cgColor
    shapeLayer.backgroundColor = bgColor
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let countour = UIBezierPath(roundedRect: bounds, byRoundingCorners: roundedCorners,
                                cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
    layer.shadowPath = countour
    shapeLayer.frame = layer.bounds
    let maskLayer = CAShapeLayer()
    maskLayer.path = countour
    shapeLayer.mask = maskLayer
  }
}
