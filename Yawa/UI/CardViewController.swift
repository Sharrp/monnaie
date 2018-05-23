//
//  CardViewController.swift
//  simplyhired-fresh
//
//  Created by Anton Vronskii on 2017/10/06.
//  Copyright © 2017 Anton Vronskii. All rights reserved.
//

import UIKit

protocol DismissCardDelegate {
    func dismissCard()
}

protocol DismissCardSubscriber: AnyObject {
    func cardDismissed()
}

class CardViewController: UIViewController {
    weak var dismissCardSubscriber: DismissCardSubscriber?
    var cardHeight: CGFloat?
    var scrollWithSwipeDown: UIScrollView?
    
    private var cardDefaultY: CGFloat {
        guard let cardHeight = cardHeight else { return 40 }
        return screenHeight - cardHeight
    }
    private var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = UIBezierPath(roundedRect: view.bounds, byRoundingCorners: [.topLeft, .topRight], cornerRadii: CGSize(width: 16, height: 16)).cgPath
        view.layer.mask = maskLayer
        
        let gesture = UIPanGestureRecognizer.init(target: self, action: #selector(panGesture))
        gesture.delegate = self
        view.addGestureRecognizer(gesture)
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        let velocity = recognizer.velocity(in: view)
        let translation = recognizer.translation(in: view)
        let y = view.frame.origin.y
        let newY = max(cardDefaultY, y + translation.y)
        view.frame = CGRect(x: 0, y: newY, width: view.frame.width, height: view.frame.height)
        recognizer.setTranslation(CGPoint.zero, in: view)
        
        if recognizer.state == .ended {
            var duration =  velocity.y < 0 ? Double((y - cardDefaultY) / -velocity.y) : Double((screenHeight - y) / velocity.y )
            duration = min(duration, 1)
            UIView.animate(withDuration: duration, delay: 0.0, options: [.allowUserInteraction], animations: { [unowned self] in
                if velocity.y >= 0 {
                    self.dismissCard()
                } else {
                    self.view.frame = CGRect(x: 0, y: self.cardDefaultY, width: self.view.frame.width, height: self.view.frame.height)
                }
            }, completion: { [weak self] _ in
                guard let strongSelf = self else { return }
                if velocity.y < 0 {
                    strongSelf.scrollWithSwipeDown?.isScrollEnabled = true
                }
            })
        }
    }
}

extension CardViewController: DismissCardDelegate {
    @IBAction func dismissCard() {
        dismiss(animated: true)
        dismissCardSubscriber?.cardDismissed()
    }
}

extension CardViewController: UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        if presented == self {
            let controller = CardPresentationController(presentedViewController: presented, presenting: presenting)
            controller.cardHeight = cardHeight
            controller.dismissDelegate = self
            return controller
        }
        return nil
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if presented == self {
            return CardAnimationController(isPresenting: true)
        } else {
            return nil
        }
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        if dismissed == self {
            return CardAnimationController(isPresenting: false)
        } else {
            return nil
        }
    }
}

class CardPresentationController: UIPresentationController {
    var dismissDelegate: DismissCardDelegate!
    private var dimmingView: UIView!
    var cardHeight: CGFloat?
    
    @objc func hide() {
        dismissDelegate.dismissCard()
    }
    
    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        guard let presentedView = presentedView else { return }
        
        dimmingView = UIView(frame: containerView.bounds)
        dimmingView.backgroundColor = UIColor(white: 0.0, alpha: 0.3)
        dimmingView.alpha = 0
        let hideTap = UITapGestureRecognizer(target: self, action: #selector(hide))
        dimmingView.addGestureRecognizer(hideTap)
        
        containerView.addSubview(dimmingView)
        containerView.addSubview(presentedView)
        
        if let transitionCoordinator = self.presentingViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: { [weak self] _ in
                guard let strongSelf = self else { return }
                strongSelf.dimmingView.alpha = 1.0
            })
        }
    }
    
    override func presentationTransitionDidEnd(_ completed: Bool)  {
        if !completed {
            self.dimmingView.removeFromSuperview()
        }
    }
    
    override func dismissalTransitionWillBegin()  {
        // Fade out the dimming view alongside the transition
        if let transitionCoordinator = self.presentingViewController.transitionCoordinator {
            transitionCoordinator.animate(alongsideTransition: {_ -> Void in
                self.dimmingView.alpha  = 0.0
            })
        }
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            self.dimmingView.removeFromSuperview()
        }
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        // We don't want the presented view to fill the whole container view, so inset it's frame
        let frame = self.containerView!.bounds
        let cardHeight = self.cardHeight ?? frame.height
        let size = CGSize(width: frame.size.width, height: cardHeight)
        let origin = CGPoint(x: 0, y: frame.height - cardHeight)
        return CGRect(origin: origin, size: size)
    }
    
    override func viewWillTransition(to size: CGSize, with transitionCoordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: transitionCoordinator)
        
        guard let containerView = containerView else { return }
        transitionCoordinator.animate(alongsideTransition: {_ -> Void in
            self.dimmingView.frame = containerView.bounds
        })
    }
}

class CardAnimationController: NSObject {
    let isPresenting: Bool
    let duration: TimeInterval = 0.4
    
    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        super.init()
    }
}

extension CardAnimationController: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning)  {
        let fromVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)
        let fromView = fromVC?.view
        let toVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
        let toView = toVC?.view
        
        let containerView = transitionContext.containerView
        if isPresenting {
            containerView.addSubview(toView!)
        }
        
        let topVC = isPresenting ? toVC : fromVC
        let topPresentedView = topVC?.view
        var topPresentedFrame = transitionContext.finalFrame(for: topVC!)
        let topDismissedFrame = topPresentedFrame
        topPresentedFrame.origin.y -= topDismissedFrame.size.height
        let topInitialFrame = topDismissedFrame
        let topFinalFrame = isPresenting ? topPresentedFrame : topDismissedFrame
        topPresentedView?.frame = topInitialFrame
        
        UIView.animate(withDuration: self.transitionDuration(using: transitionContext),
                       delay: 0, usingSpringWithDamping: 300.0, initialSpringVelocity: 5.0,
                       options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                topPresentedView?.frame = topFinalFrame
            },
            completion: { _ in
                if !self.isPresenting {
                    fromView?.removeFromSuperview()
                }
            })
        
        if isPresenting {
            animatePresentationWithTransitionContext(transitionContext)
        } else {
            animateDismissalWithTransitionContext(transitionContext)
        }
    }
    
    func animatePresentationWithTransitionContext(_ transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let presentedController = transitionContext.viewController(forKey: .to) else { return }
        guard let presentedControllerView = transitionContext.view(forKey: .to) else { return }
        
        // Position the presented view off the top of the container view
        presentedControllerView.frame = transitionContext.finalFrame(for: presentedController)
        presentedControllerView.center.y += containerView.bounds.size.height
        containerView.addSubview(presentedControllerView)
        
        UIView.animate(withDuration: self.duration, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .allowUserInteraction, animations: {
            presentedControllerView.center.y -= containerView.bounds.size.height
        }, completion: {(completed: Bool) -> Void in
            transitionContext.completeTransition(completed)
        })
    }
    
    func animateDismissalWithTransitionContext(_ transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        guard let presentedControllerView = transitionContext.view(forKey: .from) else { return }
        
        // Animate the presented view off the bottom of the view
        UIView.animate(withDuration: self.duration, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .allowUserInteraction, animations: {
            presentedControllerView.center.y += containerView.bounds.size.height
        }, completion: {(completed: Bool) -> Void in
            transitionContext.completeTransition(completed)
        })
    }
}

extension CardViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let gesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        guard let scrollView = scrollWithSwipeDown else { return false }
        let direction = gesture.velocity(in: view).y
        let y = view.frame.minY
        if y == cardDefaultY && (scrollView.contentOffset.y <= -scrollView.contentInset.top) && direction > 0 {
            scrollView.isScrollEnabled = false
        } else {
            scrollView.isScrollEnabled = true
        }
        return false
    }
}
