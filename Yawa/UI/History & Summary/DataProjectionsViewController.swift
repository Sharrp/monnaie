//
//  DataProjectionsViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol TransactionsProjecting: AnyObject {
  var projectionName: String { get }
  func project(intoTableView: UITableView?)
}

class ProjectionsViewController: UIViewController {
  var projectors = [TransactionsProjecting]() {
    didSet {
      contentOffsets = [CGFloat](repeating: 0, count: projectors.count)
      tabSwitcher.titles = projectors.map{ $0.projectionName }
      switchProjector(fromIndex: nil, toIndex: 0)
    }
  }
  weak var settings: Settings?
  
  @IBOutlet weak var navigationBar: UIView!
  private var navBarBorder = UIView()
  @IBOutlet weak var tabSwitcher: TabSwitcher!
  @IBOutlet weak var tableView: UITableView!
  private let tableViewBottomOffsetWhenCollapsed: CGFloat = -60
  
  @IBOutlet weak var fakeCard: ShadowRoundedView!
  private let fakeCardOffsetWhenExpanded: CGFloat = 16
  @IBOutlet weak var monthSwitchView: MonthSwitchView!
  private var contentOffsets = [CGFloat]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.separatorColor = UIColor(white: 0.2, alpha: 0.2)
    tableView.transform = CGAffineTransform(translationX: 0, y: tableViewBottomOffsetWhenCollapsed)
    tableView.showsVerticalScrollIndicator = false
    
    navigationBar.addSubview(navBarBorder)
    navigationBar.backgroundColor = .white
    tabSwitcher.subscribe(callback: tabSwitched)
    
    navigationBar.layer.masksToBounds = false
    navigationBar.layer.shadowOffset = CGSize()
    navigationBar.layer.shadowColor = Color.shadowColor.cgColor
    navigationBar.layer.shadowRadius = 8
    navigationBar.layer.shadowOpacity = 1
    
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
  
  lazy var bladeStateSwitch: GuillotineBladeStateCallback? = { bladeState in
    let progress: CGFloat = bladeState == .expanded ? 1 : 0
    let animator = UIViewPropertyAnimator(duration: Animation.duration, timingParameters: Animation.springTiming)
    animator.addAnimations { [weak self] in
      self?.bladeScroll?(progress)
    }
    animator.startAnimation()
  }
  
  lazy var tabSwitched: TabSwitchedCallback = { [weak self] previous, next in
    self?.switchProjector(fromIndex: previous, toIndex: next)
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
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let navController = segue.destination as? UINavigationController {
      guard let settingsVC = navController.children.first as? SettingsViewController else { return }
      settingsVC.settings = settings
    } else if let syncVC = segue.destination as? SyncViewController {
      guard let settings = settings else { return }
      syncVC.syncManager = P2PSyncManager(settings: settings)
    }
  }
}

extension ProjectionsViewController: BladeViewScrollable {
  var scrollView: UIScrollView? {
    return tableView
  }
}
