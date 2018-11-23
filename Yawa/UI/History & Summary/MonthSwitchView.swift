//
//  MonthSwitchView.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/21.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class MonthSwitchView: ShadowRoundedView {
  @IBOutlet weak var collectionView: UICollectionView!
  @IBOutlet weak var separator: UIView!
  
  private let margin: CGFloat = 8
  
  func setSeparatorHidden(progress: CGFloat, animated: Bool) {
    let animation = { [weak self] () -> Void in
      self?.separator.alpha = 1 - progress
    }
    if animated {
      let animator = UIViewPropertyAnimator(duration: Animation.duration, timingParameters: Animation.springTiming)
      animator.addAnimations(animation)
      animator.startAnimation()
    } else {
      animation()
    }
  }
}
