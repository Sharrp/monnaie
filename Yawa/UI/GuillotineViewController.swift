//
//  ViewController.swift
//  card-ui
//
//  Created by Anton Vronskii on 2018/06/02.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol GuillotineDelegate {
  func finishedSetup(ofGuillotine: GuillotineInfo)
}

protocol GuillotineInfo {
  var bladeViewController: UIViewController! { get }
  var baseViewController: UIViewController! { get }
  var bladeState: BladeState { get }
  
  func setBlade(hidden: Bool, animated: Bool)
}

protocol BladeViewScrollable {
  var scrollView: UIScrollView? { get }
}

protocol GuilliotineStateDelegate {
  func didUpdateProgress(to progress: CGFloat)
  func willSwitch(toState: BladeState, withDuration: Double, andTimingProvider: UITimingCurveProvider)
}

enum BladeState {
  case collapsed
  case expanded
}

class GuillotineViewController: UIViewController {
  private(set) var baseViewController: UIViewController!
  private(set) var bladeViewController: UIViewController!
  @IBOutlet weak var bladeBottomInsetConstraint: NSLayoutConstraint!
  @IBOutlet weak var bladeHeightConstraint: NSLayoutConstraint!
  
  private var panGesture: UIPanGestureRecognizer!
  private var directionDetectionDistance: CGFloat = 20
  private var verticalPanDetectionAngle = CGFloat.pi / 6
  private var panIsNotVertical = false
  private var isPanning = false
  private var panDetectionLocation = CGPoint()
  
  private let dampingRatio: CGFloat = 0.7
  private let duration = 0.35
  
  private(set) var bladeState = BladeState.collapsed
  private var collapsedBottomInset: CGFloat = 0
  private let expandedBottomInset: CGFloat = 32
  private var didCaclulateInsets = false
  private let alwaysVisibleHeight: CGFloat = 100
  private let additionalHeightToCoverOnSprings: CGFloat = 50
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    panGesture = UIPanGestureRecognizer(target: self, action: #selector(panHandler))
    panGesture.delegate = self
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    guard let baseVC = children.first else { return }
    guard let bladeVC = children.last else { return }
    baseViewController = baseVC
    bladeViewController = bladeVC
    (baseVC as? GuillotineDelegate)?.finishedSetup(ofGuillotine: self)
    (bladeVC as? GuillotineDelegate)?.finishedSetup(ofGuillotine: self)
    
    view.addGestureRecognizer(panGesture)
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    if !didCaclulateInsets {
      let insets = view.safeAreaInsets
      collapsedBottomInset = view.frame.height - insets.top - insets.bottom - alwaysVisibleHeight
      bladeHeightConstraint.constant = view.frame.height - insets.bottom - bladeBottomInsetConstraint.constant // FIXME //+ additionalHeightToCoverOnSprings
      bladeBottomInsetConstraint.constant = bottomInset(forState: bladeState)
      didCaclulateInsets = true
      
      // To compensate existence of additionalHeightToCoverOnSprings
      // FIXME
//      bladeViewController.additionalSafeAreaInsets = UIEdgeInsetsMake(additionalHeightToCoverOnSprings + insets.top, 0, 0, 0)
    }
  }
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return UIInterfaceOrientationMask(arrayLiteral: [.portrait, .portraitUpsideDown])
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
      panDetectionLocation = pan.location(in: view)
      moveBlade(withPan: pan)
    case .cancelled, .failed, .ended:
      if panIsNotVertical { break }
      
      let timingProvider = UISpringTimingParameters(dampingRatio: dampingRatio)
      let animator = UIViewPropertyAnimator(duration: Animation.durationFast, timingParameters: timingProvider)
      
      // Determine the next state
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
      (baseViewController as? GuilliotineStateDelegate)?.willSwitch(toState: bladeState, withDuration: Animation.duration, andTimingProvider: timingProvider)
      (bladeViewController as? GuilliotineStateDelegate)?.willSwitch(toState: bladeState, withDuration: Animation.duration, andTimingProvider: timingProvider)
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
    let currentTouchLocation = pan.location(ofTouch: 0, in: view)
    let yShift = currentTouchLocation.y - panDetectionLocation.y
    
    let initialInset = bottomInset(forState: bladeState)
    let fingerWantsInset = initialInset - yShift
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
    
    let progress = (collapsedBottomInset - displayedInset) / distance
    (baseViewController as? GuilliotineStateDelegate)?.didUpdateProgress(to: progress)
    (bladeViewController as? GuilliotineStateDelegate)?.didUpdateProgress(to: progress)
  }
  
  private func elasticTranslation(forExcess excess: CGFloat, onDistance distance: CGFloat) -> CGFloat {
    return distance * (1 + log10(1 + 0.5*excess/distance))
  }
}

extension GuillotineViewController: GuillotineInfo {
  func setBlade(hidden: Bool, animated: Bool) {
    let transform: CGAffineTransform
    if hidden {
       // FIX: replace view.safeAreaInsets.top with 44 but ensure layout is done when the method is called after launch
      transform = CGAffineTransform(translationX: 0, y: -alwaysVisibleHeight - 44)
    } else {
      transform = .identity
    }
    panGesture.isEnabled = !hidden
    
    if animated {
      let animator = UIViewPropertyAnimator(duration: Animation.duration, curve: .easeOut) { [unowned self] in
        self.bladeViewController.view.transform = transform
      }
      animator.startAnimation()
    } else {
      bladeViewController.view.transform = transform
    }
  }
}

extension GuillotineViewController: UIGestureRecognizerDelegate {
  // To avoid conflicts of the gesture with gestures in tableView
  func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard let scrollView = (bladeViewController as? BladeViewScrollable)?.scrollView else { return true }
    let touchLocation = gestureRecognizer.location(ofTouch: 0, in: scrollView)
    let touchesScrollView = scrollView.bounds.contains(touchLocation)
    return !touchesScrollView
  }
}
