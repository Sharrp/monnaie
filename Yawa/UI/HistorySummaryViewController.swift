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
  
  @IBOutlet weak var tableView: UITableView!
  
  @IBOutlet weak var dayLabel: UILabel!
  @IBOutlet weak var dayAmountLabel: UILabel!
  @IBOutlet weak var monthLabel: UILabel!
  @IBOutlet weak var monthAmountLabel: UILabel!
  
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
    
    updateTotal()
    scrollToBottom()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if let syncVC = segue.destination as? SyncViewController {
      syncVC.nameDelegate = self
      syncVC.transactionsDataSource = dataProvider
      syncVC.mergeDelegate = dataProvider
    }
  }
  
  private func scrollToBottom() {
    let days = dataProvider.totalNumberOfDays()
    guard days > 0 else { return }
    let numberOfRows = dataProvider.numberOfTransactions(forDay: days-1)
    tableView.scrollToRow(at: IndexPath(row: numberOfRows-1, section: days-1), at: .top, animated: false)
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
    return dataProvider.totalNumberOfDays()
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return dataProvider.numberOfTransactions(forDay: section)
  }
  
  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    let day = dataProvider.date(forDay: section)
    var title: String
    if Calendar.current.isDate(day, inSameDayAs: Date()) {
      title = "Today"
    } else if Calendar.current.isDate(day, inSameDayAs: Date(timeIntervalSinceNow: -86400)) {
      title = "Yesterday"
    } else {
      title = dateFormatter.string(from: day)
    }
    
    let daySum = dataProvider.totalAmount(forDay: section)
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
    
    let transaction = dataProvider.transaction(forDay: indexPath.section, withIndex: indexPath.row)
    cell.textLabel?.text = "\(transaction.category)"
    cell.amountLabel.text = formatMoney(amount: transaction.amount, currency: .JPY)
    if transaction.authorName != Settings.main.syncName {
      cell.detailTextLabel?.text = "\(transaction.authorName)"
    } else {
      cell.detailTextLabel?.text = ""
    }
    return cell
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    guard editingStyle == .delete else { return }
    dataProvider.removeTransaction(inDay: indexPath.section, withIndex: indexPath.row)
  }
}

extension HistorySummaryViewController: BladeScrollViewDelegate {
  var scrollView: UIScrollView? {
    return tableView
  }
}

extension HistorySummaryViewController: SyncNameUpdateDelegate {
  func nameUpdated(toName name: String) {
    dataProvider.updateNameInTransactionsFromThisDevice(toNewName: name)
  }
}

extension HistorySummaryViewController: TransactionsPresentor {
  private func updateTotal() {
    let todaySum = dataProvider.totalAmountForToday()
    dayAmountLabel.text = formatMoney(amount: todaySum, currency: .JPY)
    
    let monthlyAmount = dataProvider.totalAmountForCurrentMonth()
    monthAmountLabel.text = formatMoney(amount: monthlyAmount, currency: .JPY)
    
    let dateFormatter = DateFormatter()
    dateFormatter.setLocalizedDateFormatFromTemplate("MMMM yy")
    monthLabel.text = dateFormatter.string(from: Date()).replacingOccurrences(of: " ", with: "'")
  }
  
  func didUpdate(days: [Int]) {
    DispatchQueue.main.async { [unowned self] in
      let sections = IndexSet(days)
      self.tableView.reloadSections(sections, with: .automatic)
      self.updateTotal()
    }
  }
  
  func didUpdateTransactions(atIndexPaths indexPaths: [IndexPath]) {
    DispatchQueue.main.async { [unowned self] in
      self.tableView.reloadRows(at: indexPaths, with: .automatic)
      self.updateTotal()
    }
  }
  
  func didUpdateAll() {
    DispatchQueue.main.async { [unowned self] in
      self.tableView.reloadData()
      self.updateTotal()
    }
  }
}
