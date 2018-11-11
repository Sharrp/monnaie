//
//  ViewController.swift
//  rounded-shadow
//
//  Created by Anton Vronskii on 2018/11/08.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

enum CellSectionPosition {
  case first
  case middle
  case last
}

class ShadowCell: UITableViewCell {
  var position = CellSectionPosition.middle
  
  private let sideInset: CGFloat = 20
  private let cornerRadius: CGFloat = 12
  private let shadowRadius: CGFloat = 8
  private let shapeLayer = CALayer()
  
  var shadowInset: CGFloat {
    return 2 * shadowRadius
  }
  
  override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
    super.init(style: style, reuseIdentifier: reuseIdentifier)
    
    layer.masksToBounds = false
    layer.shadowOffset = CGSize()
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowRadius = shadowRadius
    layer.shadowOpacity = 1

    layer.insertSublayer(shapeLayer, at: 0)
    
    backgroundColor = nil
    layer.backgroundColor = UIColor.clear.cgColor
    shapeLayer.backgroundColor = UIColor.white.cgColor
  }
  
  required init?(coder aDecoder: NSCoder) {
    fatalError("Not implemented")
  }
  
  override var frame: CGRect {
    get {
      return super.frame
    }
    set (newFrame) {
      let yAddition = position == .first ? shadowInset : 0
      let heightChange = position != .middle ? -shadowInset : 0
      super.frame = CGRect(x: newFrame.origin.x + sideInset, y: newFrame.origin.y + yAddition,
                           width: newFrame.width - 2 * sideInset, height: newFrame.height + heightChange)
    }
  }
  
  private func roundedCorners(forPosition position: CellSectionPosition) -> UIRectCorner {
    if position == .first {
      return [.topRight, .topLeft]
    } else if position == .last {
      return [.bottomRight, .bottomLeft]
    } else {
      return []
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    let corners = roundedCorners(forPosition: position)
    
    // For the non-first row we extend shadow to the top so we won't see shadow's top rounded corners (they will be masked)
    let topShadowInset = position != .first ? -cornerRadius : 0
    let bottomShadowInset = position != .last ? -cornerRadius : 0
    let shadowRect = bounds.inset(by: UIEdgeInsets(top: topShadowInset, left: 0, bottom: bottomShadowInset, right: 0))
    let shadowPath = UIBezierPath(roundedRect: shadowRect, byRoundingCorners: corners,
                                  cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
    layer.shadowPath = shadowPath
    
    // Shadow mask
    let topShadowMaskInset = position == .first ? shadowInset : 0
    let bottomShadowMaskInset = position == .last ? shadowInset : 0
    let shadowMaskRect = CGRect(x: -shadowInset, y: -topShadowMaskInset,
                                width: bounds.width + 2*shadowInset, height: bounds.height + topShadowMaskInset + bottomShadowMaskInset)
    let shadowMaskLayer = CAShapeLayer()
    shadowMaskLayer.path = UIBezierPath(rect: shadowMaskRect).cgPath
    layer.mask = shadowMaskLayer
    
    // Visible shape
    shapeLayer.frame = layer.bounds
    let shapeMaskLayer = CAShapeLayer()
    shapeMaskLayer.path = UIBezierPath(roundedRect: bounds, byRoundingCorners: corners,
                                       cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)).cgPath
    shapeLayer.mask = shapeMaskLayer
  }
}

class ViewController: UIViewController {
  @IBOutlet weak var someView: UIView!
  @IBOutlet weak var tableView: UITableView!
  private let cellsPerSection = 5
  
  override func viewDidLoad() {
    super.viewDidLoad()
  }
}

extension ViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 10
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return cellsPerSection
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let names = ["Samantha", "Jack", "Rosie", "Mike", "Synthia"]
    let cellID = "cell"
    let cell: ShadowCell
    if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: cellID) as? ShadowCell {
      cell = dequeuedCell
    } else {
      cell = ShadowCell(style: .default, reuseIdentifier: cellID)
    }
    cell.textLabel?.text = "\(names[indexPath.row]) \(indexPath.section)"
    
    if indexPath.row == 0 {
      cell.position = .first
    } else if indexPath.row == cellsPerSection - 1 {
      cell.position = .last
    } else {
      cell.position = .middle
    }
    
    return cell
  }
}

extension ViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 30
  }
  
  func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return 50
  }
  
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    let height: CGFloat = 48
    if indexPath.row == 0 || indexPath.row == cellsPerSection - 1 {
      return height + 16
    } else {
      return height
    }
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

