//
//  TabSwitcher.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/23.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

typealias TabSwitchedCallback = (Int?, Int) -> Void // get previously selected and currently selected indexes

class TabSwitcher: UIView {
  private var labels = [UILabel]()
  private var indicator = UIView()
  @IBOutlet weak var width: NSLayoutConstraint!
  
  private let activeFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
  private let inactiveFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
  
  private let margin: CGFloat = 12
  private let labelY: CGFloat = 9
  private let indicatorTopSpace: CGFloat = 10
  private let indicatorHeight: CGFloat = 2
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    addSubview(indicator)
    indicator.backgroundColor = Color.accentText
  }
  
  private var selectedIndex = 0 {
    didSet {
      guard selectedIndex < titles.count else { return }
      labels[oldValue].font = inactiveFont
      labels[oldValue].textColor = Color.inactiveText
      labels[selectedIndex].font = activeFont
      labels[selectedIndex].textColor = Color.accentText
      layoutIndicator()
    }
  }
  
  var titles = [String]() {
    didSet {
      labels.forEach{ $0.removeFromSuperview() }
      labels = [UILabel]()
      for (i, title) in titles.enumerated() {
        let label = UILabel()
        label.text = title
        let isSelected = i == selectedIndex
        label.font = isSelected ? activeFont : inactiveFont
        label.textColor = isSelected ? Color.accentText : Color.inactiveText
        addSubview(label)
        labels.append(label)
      }
      selectedIndex = 0
      setNeedsLayout()
    }
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    var x = margin
    for label in labels {
      label.sizeToFit()
      label.frame.origin.x = x
      label.frame.origin.y = labelY
      x += label.frame.width + 2 * margin
    }
    guard labels.count > 0 else { return }
    width.constant = labels.last!.frame.maxX + margin
    layoutIndicator()
  }
  
  private func layoutIndicator() {
    guard selectedIndex < labels.count else { return }
    let label = labels[selectedIndex]
    let x = label.frame.minX - margin
    let y = label.frame.maxY + indicatorTopSpace
    let width = 2 * margin + label.frame.width
    indicator.frame = CGRect(x: x, y: y, width: width, height: indicatorHeight)
  }
  
  private var callbacks = [TabSwitchedCallback?]()
  func subscribe(callback: TabSwitchedCallback?) {
    callbacks.append(callback)
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let location = touches.first?.location(in: self) else { return }
    var tappedIndex = selectedIndex
    for (i, label) in labels.enumerated() {
      if label.frame.minX - margin <= location.x && location.x <= label.frame.maxX + margin {
        tappedIndex = i
        break
      }
    }
    guard tappedIndex != selectedIndex else { return }
    let previousIndex = selectedIndex
    selectedIndex = tappedIndex
    callbacks.forEach{ $0?(previousIndex, tappedIndex) }
  }
}
