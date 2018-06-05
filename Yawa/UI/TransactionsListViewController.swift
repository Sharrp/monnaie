//
//  ViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class TransactionsListViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  
  @IBOutlet weak var dayLabel: UILabel!
  @IBOutlet weak var dayAmountLabel: UILabel!
  @IBOutlet weak var monthLabel: UILabel!
  @IBOutlet weak var monthAmountLabel: UILabel!
  
  private let dateFormatter = DateFormatter()
  let dataProvider = TransactionsController()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataProvider.presentor = self
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .none
    
    updateTotal()
    
    scrollToBottom()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//    if let transactionVC = segue.destination as? TransactionViewController {
//      transactionVC.delegate = dataProvider
//      transactionVC.dismissCardSubscriber = self
//      transactionVC.cardHeight = view.frame.height - 70
//
//      if segue.identifier == "editTransaction" {
//        guard let indexPath = tableView.indexPathForSelectedRow else { return }
//        transactionVC.transaction = dataProvider.transaction(forDay: indexPath.section, withIndex: indexPath.row)
//      }
//    }
    if let syncVC = segue.destination as? SyncViewController {
      syncVC.delegate = dataProvider
      syncVC.transactionsToSync = dataProvider.syncTransactions
      syncVC.nameDelegate = self
    }
  }
  
  private func scrollToBottom() {
    let days = dataProvider.numberOfDays
    guard days > 0 else { return }
    let numberOfRows = dataProvider.numberOfTransactions(forDay: days-1)
    tableView.scrollToRow(at: IndexPath(row: numberOfRows-1, section: days-1), at: .top, animated: false)
  }
}

extension TransactionsListViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return dataProvider.numberOfDays
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
    
    // Daily amount in each section
    let dailySum = dataProvider.totalAmount(forDay: section)
    title += " — " + formatMoney(amount: dailySum, currency: .JPY)
    
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

extension TransactionsListViewController: SyncNameUpdateDelegate {
  func nameUpdated(toName name: String) {
    dataProvider.updateNameInTransactionsFromThisDevice(toNewName: name)
  }
}

extension TransactionsListViewController: TransactionsPresentor {
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
