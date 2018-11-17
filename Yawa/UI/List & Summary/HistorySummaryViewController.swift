//
//  ViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class HistorySummaryViewController: UIViewController {
  private enum TransactionsViewMode: Int {
    case history
    case summary
  }
  
  @IBOutlet weak var navigationBar: UINavigationBar!
  private var navBarBorder = UIView()
  @IBOutlet weak var tableView: UITableView!
  private let tableViewBottomOffsetWhenCollapsed: CGFloat = -60
  @IBOutlet weak var controlPanel: UIView!
  
  @IBOutlet weak var fakeCard: ShadowRoundedView!
  private let fakeCardOffsetWhenExpanded: CGFloat = 16
  
  @IBOutlet weak var monthSwitcherCollectionView: UICollectionView!
  @IBOutlet weak var monthSwitchProvider: MonthSwitchProvider!
  
  let historyProvider = HistoryProvider()
  private let summaryProvider = SummaryProvider()
  
  private var historyLastContentOffset: CGFloat = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    historyProvider.dataProvider.presentor = self
    historyProvider.getSelectedMonth = { [weak self] in self?.monthSwitchProvider.selectedMonth }
    summaryProvider.getSelectedMonth = { [weak self] in self?.monthSwitchProvider.selectedMonth }
    summaryProvider.transactionsController = historyProvider.dataProvider
    tableView.separatorColor = UIColor(white: 0.2, alpha: 0.2)
    tableView.transform = CGAffineTransform(translationX: 0, y: tableViewBottomOffsetWhenCollapsed)
    tableView.showsVerticalScrollIndicator = false
    
    navigationBar.setBackgroundImage(UIImage(), for: .default)
    navigationBar.shadowImage = UIImage()
    navigationBar.isTranslucent = true
    navigationBar.addSubview(navBarBorder)
    navBarBorder.backgroundColor = UIColor(white: 1, alpha: 0.2)
    
    updateTotal()
    scrollToBottom()

    monthSwitcherCollectionView.allowsMultipleSelection = true
    monthSwitcherCollectionView.contentInset = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 8)
    monthSwitchProvider.subscribe(callback: historyProvider.monthChangedCallback)
    monthSwitchProvider.subscribe(callback: summaryProvider.monthChangedCallback)
    monthSwitchProvider.selectLastMonth()
    
    switchTo(mode: .history)
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    shareCsv()
  }
  
  private func shareCsv() {
    let filename = NSTemporaryDirectory() + "export-finances-\(Date.now).csv".replacingOccurrences(of: " ", with: "_")
    let csv = historyProvider.dataProvider.exportDataAsCSV()
    do {
      try csv.write(toFile: filename, atomically: true, encoding: String.Encoding.utf8)
      let fileURL = URL(fileURLWithPath: filename)
      let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
      activityVC.completionWithItemsHandler = { _, completed, _, _ in
        guard completed else { return }
        // Clean entire directory instead of one file
        // in case any of previous exports were interrupted after file creation but before shraing is finished
        FileManager.default.removeFiles(fromDirectory: NSTemporaryDirectory())
      }
      present(activityVC, animated: true)
    } catch {
      print("Cannot write export file: \(error)")
    }
  }
  
  override func loadView() {
    super.loadView()
    navBarBorder.frame = CGRect(x: 0, y: navigationBar.frame.height, width: view.frame.width, height: 1)
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let syncVC = segue.destination as? SyncViewController {
      syncVC.nameDelegate = self
      syncVC.transactionsDataSource = historyProvider.dataProvider
      syncVC.mergeDelegate = historyProvider.dataProvider
    }
  }
  
  private func scrollToBottom(animated: Bool = false) { // TODO: update when month switcher is done
    tableView.setContentOffset(CGPoint(x: 0, y: CGFloat.greatestFiniteMagnitude), animated: false)
  }
  
  private func switchTo(mode: TransactionsViewMode) {
    let contentOffset: CGFloat
    switch mode {
    case .history:
      historyProvider.tableView = tableView
      summaryProvider.tableView = nil
      contentOffset = historyLastContentOffset
    case .summary:
      historyLastContentOffset = tableView.contentOffset.y
      summaryProvider.tableView = tableView
      historyProvider.tableView = nil
      contentOffset = 0
    }
    
    tableView.reloadData()
    tableView.layoutIfNeeded()
    tableView.contentOffset = CGPoint(x: 0, y: contentOffset)
  }
  
  @IBAction func viewModeChanged(sender: UISegmentedControl) {
    guard let viewMode = TransactionsViewMode(rawValue: sender.selectedSegmentIndex) else { return }
    switchTo(mode: viewMode)
  }
}

extension HistorySummaryViewController: BladeViewScrollable {
  var scrollView: UIScrollView? {
    return tableView
  }
}

extension HistorySummaryViewController: SyncNameUpdateDelegate {
  func nameUpdated(from oldName: String, to newName: String) {
    historyProvider.dataProvider.changeOnwer(from: oldName, to: newName)
  }
}

extension HistorySummaryViewController: TransactionsPresentor {
  private func updateTotal() {
    monthSwitchProvider.reports = historyProvider.dataProvider.monthlyAmounts()
    monthSwitchProvider.todayAmount = historyProvider.dataProvider.totalAmount(forDay: Date.now)
  }
  
  func didUpdate(days: [Date]) {
    didUpdateAll()
  }
  
  func didUpdateAll() {
    DispatchQueue.main.async { [unowned self] in
      self.tableView.reloadData()
      self.updateTotal()
    }
  }
}

extension HistorySummaryViewController: GuilliotineStateDelegate {
  func didUpdateProgress(to progress: CGFloat) {
    let tableTransform: CGAffineTransform
    if progress == 1 {
      tableTransform = .identity
    } else {
      tableTransform = CGAffineTransform(translationX: 0, y: (1 - progress) * tableViewBottomOffsetWhenCollapsed)
    }
    tableView.transform = tableTransform
    fakeCard.transform = CGAffineTransform(translationX: 0, y: fakeCardOffsetWhenExpanded * progress)
  }
  
  func willSwitch(toState state: BladeState, withDuration duration: Double, andTimingProvider timing: UITimingCurveProvider) {
    let progress: CGFloat = state == .expanded ? 1 : 0
    let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
    animator.addAnimations { [unowned self] in
      self.didUpdateProgress(to: progress)
    }
    animator.startAnimation()
  }
}
