//
//  DataProjectionsViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol TransactionsProjecting: class {
  var projectionName: String { get }
  func project(intoTableView: UITableView?)
}

class ProjectionsViewController: UIViewController {
  var projectors = [TransactionsProjecting]() {
    didSet {
      guard projectors.count > 0 else {
        selectedProjectionIndex = nil
        return
      }
      contentOffsets = [CGFloat](repeating: 0, count: projectors.count)
      selectedProjectionIndex = 0
    }
  }
  private var selectedProjectionIndex: Int? {
    didSet {
      guard let selectedIndex = selectedProjectionIndex else { return }
      guard selectedIndex < projectors.count else { return }
      switchProjector(fromIndex: oldValue, toIndex: selectedIndex)
    }
  }
  
  @IBOutlet weak var navigationBar: UINavigationBar!
  private var navBarBorder = UIView()
  @IBOutlet weak var tableView: UITableView!
  private let tableViewBottomOffsetWhenCollapsed: CGFloat = -60
  @IBOutlet weak var controlPanel: UIView!
  
  @IBOutlet weak var fakeCard: ShadowRoundedView!
  private let fakeCardOffsetWhenExpanded: CGFloat = 16
  
  @IBOutlet weak var monthSwitcherCollectionView: UICollectionView!
  
  private var contentOffsets = [CGFloat]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.separatorColor = UIColor(white: 0.2, alpha: 0.2)
    tableView.transform = CGAffineTransform(translationX: 0, y: tableViewBottomOffsetWhenCollapsed)
    tableView.showsVerticalScrollIndicator = false
    
    navigationBar.setBackgroundImage(UIImage(), for: .default)
    navigationBar.shadowImage = UIImage()
    navigationBar.isTranslucent = true
    navigationBar.addSubview(navBarBorder)
    navBarBorder.backgroundColor = UIColor(white: 1, alpha: 0.2)
    
    monthSwitcherCollectionView.allowsMultipleSelection = true
    monthSwitcherCollectionView.contentInset = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 8)
    
    scrollToBottom()
  }
  
  override func loadView() {
    super.loadView()
    navBarBorder.frame = CGRect(x: 0, y: navigationBar.frame.height, width: view.frame.width, height: 1)
  }
  
  lazy var bladeScroll: GuillotineScrollCallback? = { [weak self] progress in
    guard let fakeCardOffsetWhenExpanded = self?.fakeCardOffsetWhenExpanded else { return }
    let tableTransform: CGAffineTransform
    if progress == 1 {
      tableTransform = .identity
    } else {
      guard let tableViewBottomOffsetWhenCollapsed = self?.tableViewBottomOffsetWhenCollapsed else { return }
      tableTransform = CGAffineTransform(translationX: 0, y: (1 - progress) * tableViewBottomOffsetWhenCollapsed)
    }
    self?.tableView.transform = tableTransform
    self?.fakeCard.transform = CGAffineTransform(translationX: 0, y: fakeCardOffsetWhenExpanded * progress)
  }
  
  lazy var bladeStateSwitch: GuillotineBladeStateCallback? = { [weak self] bladeState in
    let progress: CGFloat = bladeState == .expanded ? 1 : 0
    let animator = UIViewPropertyAnimator(duration: Animation.duration, timingParameters: Animation.springTiming)
    animator.addAnimations { [weak self] in
      self?.bladeScroll?(progress)
    }
    animator.startAnimation()
  }
  
  private func scrollToBottom(animated: Bool = false) { // TODO: update when month switcher is done
    tableView.setContentOffset(CGPoint(x: 0, y: CGFloat.greatestFiniteMagnitude), animated: false)
  }
  
  private func switchProjector(fromIndex previousIndex: Int?, toIndex nextIndex: Int) {
    if let previousIndex = previousIndex {
      let previous = projectors[previousIndex]
      contentOffsets[previousIndex] = tableView.contentOffset.y
      previous.project(intoTableView: nil)
    }
    
    let next = projectors[nextIndex]
    next.project(intoTableView: tableView)
    tableView.layoutIfNeeded()
    tableView.contentOffset = CGPoint(x: 0, y: contentOffsets[nextIndex])
  }
  
  @IBAction func viewModeChanged(sender: UISegmentedControl) {
    selectedProjectionIndex = sender.selectedSegmentIndex
  }
}

extension ProjectionsViewController: BladeViewScrollable {
  var scrollView: UIScrollView? {
    return tableView
  }
}
