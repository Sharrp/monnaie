//
//  ViewController.swift
//  card-ui
//
//  Created by Anton Vronskii on 2018/06/02.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol GuillotineBaseUpdateDelegate {
  func didUpdate(baseVC: UIViewController)
}

protocol GuillotineBladeUpdateDelegate {
  func didUpdate(bladeVC: UIViewController)
}

class GuillotineViewController: UIViewController {
  private enum BladeState {
    case collapsed
    case expanded
  }
  
  private var bladeViewController: UIViewController!
  @IBOutlet var bladeBottomInsetConstraint: NSLayoutConstraint!
  @IBOutlet var bladeHeightConstraint: NSLayoutConstraint!
  
  private var panGesture: UIPanGestureRecognizer!
  private var directionDetectionDistance: CGFloat = 10
  private var verticalPanDetectionAngle = CGFloat.pi / 6
  private var panIsNotVertical = false
  private var isPanning = false
  
  private let dampingRatio: CGFloat = 0.7
  private let duration = 0.35
  
  private var bladeState = BladeState.collapsed
  private var collapsedBottomInset: CGFloat = 0
  private let expandedBottomInset: CGFloat = 32
  private var didntCaclulateInsetsYet = true
  private let alwaysVisibleHeight: CGFloat = 74
  private let additionalHeightToCoverOnSprings: CGFloat = 50
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    panGesture = UIPanGestureRecognizer(target: self, action: #selector(panHandler))
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let baseVC = childViewControllers.first else { return }
    guard let bladeVC = childViewControllers.last else { return }
    bladeViewController = bladeVC
    (baseVC as? GuillotineBladeUpdateDelegate)?.didUpdate(bladeVC: bladeVC)
    (bladeVC as? GuillotineBaseUpdateDelegate)?.didUpdate(baseVC: baseVC)
    bladeVC.view.layer.cornerRadius = 14
    
    view.addGestureRecognizer(panGesture)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if didntCaclulateInsetsYet {
      let insets = view.safeAreaInsets
      collapsedBottomInset = view.frame.height - insets.top - insets.bottom - alwaysVisibleHeight
      bladeHeightConstraint.constant = view.frame.height - insets.bottom - bladeBottomInsetConstraint.constant + additionalHeightToCoverOnSprings
      bladeBottomInsetConstraint.constant = bottomInset(forState: bladeState)
      didntCaclulateInsetsYet = false
    }
  }
  
  private func bottomInset(forState state: BladeState) -> CGFloat {
    switch state {
    case .collapsed:
      return collapsedBottomInset
    case .expanded:
      return expandedBottomInset
    }
  }
  
  @objc func panHandler(pan: UIPanGestureRecognizer) {
    switch pan.state {
    case .began:
      panIsNotVertical = false
      isPanning = false
    case .changed:
      if isPanning {
        moveBlade(withPan: pan)
        break
      }
      if panIsNotVertical { break }
      
      let shift = pan.translation(in: view)
      if !canDetectDirection(shift: shift, detectionDistance: directionDetectionDistance) {
        break
      }
      if isPanNonVertical(shift: shift) {
        panIsNotVertical = true
        break
      }
      isPanning = true
      moveBlade(withPan: pan)
    case .cancelled, .failed, .ended:
      if panIsNotVertical { break }
      
      let timingProvider = UISpringTimingParameters(dampingRatio: dampingRatio)
      let animator = UIViewPropertyAnimator(duration: 0.8*duration, timingParameters: timingProvider)
      
      // Determine next state
      let velocity = pan.velocity(in: view)
      if velocity.y == 0 {
        let inititalInset = bottomInset(forState: bladeState)
        let currentInset = inititalInset + pan.translation(in: view).y
        let middlePoint = (expandedBottomInset + collapsedBottomInset) / 2
        bladeState = currentInset > middlePoint ? .collapsed : .expanded
      } else {
        bladeState = velocity.y > 0 ? .expanded: .collapsed
      }
      
      // That's the way constraints are animated
      view.layoutIfNeeded()
      bladeBottomInsetConstraint.constant = bottomInset(forState: bladeState)
      animator.addAnimations { [unowned self] in
        self.view.layoutIfNeeded()
      }
      animator.startAnimation()
    case .possible:
      break
    }
  }
  
  private func canDetectDirection(shift: CGPoint, detectionDistance: CGFloat) -> Bool {
    let distanceTravelled = sqrt(shift.x * shift.x + shift.y * shift.y)
    return distanceTravelled >= directionDetectionDistance
  }
  
  private func isPanNonVertical(shift: CGPoint) -> Bool {
    let angleTan = abs(shift.x / shift.y)
    return angleTan > tan(verticalPanDetectionAngle)
  }
  
  private func moveBlade(withPan pan: UIPanGestureRecognizer) {
    let shift = pan.translation(in: view)
    
    let initialInset = bottomInset(forState: bladeState)
    let fingerWantsInset = initialInset - shift.y
    let displayedInset: CGFloat
    let distance = collapsedBottomInset - expandedBottomInset
    if fingerWantsInset > collapsedBottomInset {
      let excess = fingerWantsInset - collapsedBottomInset
      displayedInset = expandedBottomInset + elasticTranslation(forExcess: excess, onDistance: distance)
    } else if fingerWantsInset < expandedBottomInset {
      let excess = expandedBottomInset - fingerWantsInset
      let stretchedDistance = elasticTranslation(forExcess: excess, onDistance: distance)
      displayedInset = expandedBottomInset - (stretchedDistance - distance)
    } else {
      displayedInset = fingerWantsInset
    }
    bladeBottomInsetConstraint.constant = displayedInset
    view.setNeedsLayout()
  }
  
  private func elasticTranslation(forExcess excess: CGFloat, onDistance distance: CGFloat) -> CGFloat {
    return distance * (1 + log10(1 + 0.5*excess/distance))
  }
}
