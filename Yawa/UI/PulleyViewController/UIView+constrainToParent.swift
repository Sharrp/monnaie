//
//  UIView+constrainToParent.swift
//  Pulley
//
//  Created by Mathew Polzin on 8/22/17.
//

import UIKit

extension UIView {
    
    func constrainToParent() {
        constrainToParent(insets: .zero)
    }
    
    func constrainToParent(insets: UIEdgeInsets) {
        guard let parent = superview else { return }
        
        translatesAutoresizingMaskIntoConstraints = false
        let metrics: [String : Any] = ["left" : insets.left, "right" : insets.right, "top" : insets.top, "bottom" : insets.bottom]
        
        parent.addConstraints(["H:|-(left)-[view]-(right)-|", "V:|-(top)-[view]-(bottom)-|"].flatMap {
            NSLayoutConstraint.constraints(withVisualFormat: $0, metrics: metrics, views: ["view": self])
        })
    }
}

extension UIViewController {
  
  /// If this viewController pertences to a PulleyViewController, return it.
  public var pulleyViewController: PulleyViewController? {
    var parentVC = parent
    while parentVC != nil {
      if let pulleyViewController = parentVC as? PulleyViewController {
        return pulleyViewController
      }
      parentVC = parentVC?.parent
    }
    return nil
  }
}

protocol PulleyPassthroughScrollViewDelegate: class {
  func shouldTouchPassthroughScrollView(scrollView: PulleyPassthroughScrollView, point: CGPoint) -> Bool
  func viewToReceiveTouch(scrollView: PulleyPassthroughScrollView, point: CGPoint) -> UIView
}

class PulleyPassthroughScrollView: UIScrollView {
  weak var touchDelegate: PulleyPassthroughScrollViewDelegate?
  
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    if let touchDelegate = touchDelegate,
      touchDelegate.shouldTouchPassthroughScrollView(scrollView: self, point: point) {
      return touchDelegate.viewToReceiveTouch(scrollView: self, point: point).hitTest(touchDelegate.viewToReceiveTouch(scrollView: self, point: point).convert(point, from: self), with: event)
    }
    
    return super.hitTest(point, with: event)
  }
}
