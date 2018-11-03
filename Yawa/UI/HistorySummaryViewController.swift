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
  
  @IBOutlet weak var monthSwitcherCollectionView: UICollectionView!
  @IBOutlet weak var monthSwitchProvider: MonthSwitchProvider!
  
  private let dateFormatter = DateFormatter()
  let dataProvider = TransactionsController()
  private let summaryProvider = SummaryProvider()
  
  private var historyLastContentOffset: CGFloat = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataProvider.presentor = self
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    summaryProvider.transactionsController = dataProvider
    tableView.separatorColor = UIColor(white: 0.2, alpha: 0.2)
    
    navigationBar.setBackgroundImage(UIImage(), for: .default)
    navigationBar.shadowImage = UIImage()
    navigationBar.isTranslucent = true
    navigationBar.addSubview(navBarBorder)
    navBarBorder.backgroundColor = UIColor(white: 1, alpha: 0.2)
    
    updateTotal()
    scrollToBottom()

    monthSwitcherCollectionView.allowsMultipleSelection = true
    monthSwitcherCollectionView.contentInset = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 8)
    monthSwitchProvider.selectLastMonth()
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    shareCsv()
  }
  
  private func shareCsv() {
    let filename = NSTemporaryDirectory() + "export-finances-\(Date()).csv".replacingOccurrences(of: " ", with: "_")
    let csv = dataProvider.exportDataAsCSV()
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
      syncVC.transactionsDataSource = dataProvider
      syncVC.mergeDelegate = dataProvider
    }
  }
  
  private func scrollToBottom(animated: Bool = false) { // TODO: update when month switcher is done
    tableView.setContentOffset(CGPoint(x: 0, y: CGFloat.greatestFiniteMagnitude), animated: false)
  }
  
  @IBAction func viewModeChanged(sender: UISegmentedControl) {
    guard let viewMode = TransactionsViewMode(rawValue: sender.selectedSegmentIndex) else { return }
    let contentOffset: CGFloat
    switch viewMode {
    case .history:
      tableView.dataSource = self
      tableView.delegate = nil
      contentOffset = historyLastContentOffset
    case .summary:
      historyLastContentOffset = tableView.contentOffset.y
      summaryProvider.updateData()
      tableView.dataSource = summaryProvider
      tableView.delegate = summaryProvider
      contentOffset = 0
    }
    
    tableView.reloadData()
    tableView.layoutIfNeeded()
    tableView.contentOffset = CGPoint(x: 0, y: contentOffset)
  }
}

extension HistorySummaryViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
//    let range = Calendar.current.range(of: .day, in: .month, for: Date())!
//    let numberOfDays = range.count
    return Calendar.current.component(.day, from: Date())
  }
  
  private func date(forSection section: Int) -> Date? {
    let today = Date()
    var components = DateComponents()
    components.day = section + 1
    components.month = Calendar.current.component(.month, from: today)
    components.year = Calendar.current.component(.year, from: today)
    return Calendar.current.date(from: components)
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let dateForSection = date(forSection: section) else { return 0 }
    return dataProvider.numberOfTransactions(onDay: dateForSection)
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    guard let dateForSection = date(forSection: section) else { return nil }
    var title: String
    if Calendar.current.isDate(dateForSection, inSameDayAs: Date()) {
      title = "Today"
    } else if Calendar.current.isDate(dateForSection, inSameDayAs: Date(timeIntervalSinceNow: -86400)) {
      title = "Yesterday"
    } else {
      title = dateFormatter.string(from: dateForSection)
    }
    
    let daySum = dataProvider.totalAmount(forDay: dateForSection)
    title += " — " + formatMoney(amount: daySum, currency: .JPY)
    return title
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "transactionCell"
    let cell: TransactionCell
    if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: cellID) as? TransactionCell {
      cell = dequeuedCell
    } else {
      cell = TransactionCell(style: .subtitle, reuseIdentifier: cellID)
    }
    
    guard let dateForSection = date(forSection: indexPath.section) else { return cell }
    guard let transaction = dataProvider.transaction(index: indexPath.row, forDay: dateForSection) else { return cell }
    cell.backgroundColor = .clear
    cell.emojiLabel.text = "\(transaction.category.emoji)"
    cell.categoryLabel.text = "\(transaction.category.name)"
    cell.amountLabel.text = formatMoney(amount: transaction.amount, currency: .JPY)
    if transaction.authorName == Settings.main.syncName {
      cell.authorLabel.text = ""
      cell.topMarginConstraint.constant = 19
    } else {
      cell.authorLabel.text = "\(transaction.authorName)"
      cell.topMarginConstraint.constant = 8
    }
    return cell
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    guard editingStyle == .delete else { return }
    // TODO: implement more convenient remove method in TransactionsController
    guard let dateForSection = date(forSection: indexPath.section) else { return }
    guard let transaction = dataProvider.transaction(index: indexPath.row, forDay: dateForSection) else { return }
    dataProvider.remove(transaction: transaction)
  }
}

extension HistorySummaryViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
    view.tintColor = .clear
    guard let header = view as? UITableViewHeaderFooterView else { return }
    header.textLabel?.textColor = UIColor(white: 0.2, alpha: 0.8)
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 60
  }
}

extension HistorySummaryViewController: BladeScrollViewDelegate {
  var scrollView: UIScrollView? {
    return tableView
  }
}

extension HistorySummaryViewController: SyncNameUpdateDelegate {
  func nameUpdated(from oldName: String, to newName: String) {
    dataProvider.changeOnwer(from: oldName, to: newName)
  }
}

extension HistorySummaryViewController: TransactionsPresentor {
  private func updateTotal() {
    monthSwitchProvider.reports = dataProvider.monthlyAmounts()
    monthSwitchProvider.todayAmount = dataProvider.totalAmount(forDay: Date())
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
