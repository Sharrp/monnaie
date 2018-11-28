//
//  HistoryViewModel.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/17.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class HistoryViewModel: NSObject {
  private struct SectionHeaderData {
    let firstDay: Date
    let isEmpty: Bool
    let numberOfDays: Int
  }
  
  private var sectionsHeadersData = [SectionHeaderData]()
  private var tableView: UITableView?
  
  weak var dataService: DataService?
  var editor: ManagedTransactionEditor?
  var getSelectedMonth: SelectedMonthGetter?
  weak var settings: Settings?
  
  private var isActive: Bool {
    return tableView != nil
  }
  
  // It should be lazy so self is instantiated when it's assigned
  lazy var monthChanged: MonthSwitchedCallback? = { [weak self] m in
    guard let isActive = self?.isActive, isActive else { return }
    self?.update()
  }
  
  lazy var dataServiceUpdated: DataServiceUpdateCallback? = { [weak self] in
    guard let isActive = self?.isActive, isActive else { return }
    self?.update()
  }
  
  private func update() {
    tableView?.reloadData()
  }
}

extension HistoryViewModel: TransactionsProjecting {
  var projectionName: String {
    return "History"
  }
  
  func project(intoTableView tableView: UITableView?) {
    self.tableView = tableView
    guard let tableView = tableView else { return }
    tableView.dataSource = self
    tableView.delegate = self
    update()
  }
}

extension HistoryViewModel: UITableViewDataSource {
  // Merges all consequemtial empty days into one section
  private func recalculateHeaders(forNumberOfFirstDays numOfDays: Int, inMonth monthDate: Date) {
    sectionsHeadersData = [SectionHeaderData]()
    guard let nonEmptyDays = dataService?.daysWithTransactions(forMonth: monthDate) else { return }
    var firstDayOfCurrentSection = 0
    var currentNumberOfSequentialEmptyDays = 0
    for i in 0..<numOfDays {
      let day = i + 1
      if nonEmptyDays.contains(day) {
        if currentNumberOfSequentialEmptyDays > 0,
          let firstEmptyDayDate = monthDate.date(bySettingDayTo: firstDayOfCurrentSection) {
          let sectionData = SectionHeaderData(firstDay: firstEmptyDayDate, isEmpty: true,
                                              numberOfDays: currentNumberOfSequentialEmptyDays)
          sectionsHeadersData.append(sectionData)
          currentNumberOfSequentialEmptyDays = 0
        }
        guard let currentDayDate = monthDate.date(bySettingDayTo: day) else { continue }
        let sectionData = SectionHeaderData(firstDay: currentDayDate, isEmpty: false, numberOfDays: 1)
        sectionsHeadersData.append(sectionData)
      } else {
        if currentNumberOfSequentialEmptyDays == 0 {
          firstDayOfCurrentSection = day
        }
        currentNumberOfSequentialEmptyDays += 1
      }
    }
    if currentNumberOfSequentialEmptyDays > 0,
      let firstEmptyDayDate = monthDate.date(bySettingDayTo: firstDayOfCurrentSection) {
      let sectionData = SectionHeaderData(firstDay: firstEmptyDayDate, isEmpty: true,
                                          numberOfDays: currentNumberOfSequentialEmptyDays)
      sectionsHeadersData.append(sectionData)
    }
  }
  
  func numberOfSections(in tableView: UITableView) -> Int {
    guard let selectedMonthDate = getSelectedMonth?() else { return 0 }
    let daysToShow: Int
    if selectedMonthDate.isSame(.month, asDate: Date.now) {
      daysToShow = Calendar.current.component(.day, from: Date.now)
    } else {
      guard let daysCount = Calendar.current.range(of: .day, in: .month, for: selectedMonthDate)?.count else { return 0 }
      daysToShow = daysCount
    }
    recalculateHeaders(forNumberOfFirstDays: daysToShow, inMonth: selectedMonthDate)
    return sectionsHeadersData.count
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionData = sectionsHeadersData[section]
    if sectionData.isEmpty {
      return 0
    } else {
      guard let count = dataService?.numberOfTransactions(onDay: sectionData.firstDay) else { return 0 }
      return count
    }
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "transactionCell"
    let cell = tableView.dequeueReusableCell(withIdentifier: cellID) as! TransactionCell
    let sectionDate = sectionsHeadersData[indexPath.section].firstDay
    guard let transaction = dataService?.transaction(index: indexPath.row, forDay: sectionDate) else {
      fatalError("cellForRowAt: Inconsistency in UITableViewDataSource data")
    }
    cell.emojiLabel.text = "\(transaction.category.emoji)"
    cell.categoryLabel.text = "\(transaction.category.name)"
    let currency = settings?.userCurrency ?? Currency.defaultCurrency
    cell.amountLabel.text = formatMoney(amount: transaction.amount, currency: currency)
    if transaction.authorName == settings?.syncName {
      cell.authorLabel.text = ""
      cell.topMarginConstraint.constant = 19
    } else {
      cell.authorLabel.text = "\(transaction.authorName)"
      cell.topMarginConstraint.constant = 8
    }
    
    cell.isFirst = indexPath.row == 0
    let cellsInSection = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
    cell.isLast = indexPath.row == cellsInSection - 1
    
    return cell
  }
  
  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    return true
  }
  
  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    guard editingStyle == .delete else { return }
    // TODO: implement more convenient remove method in TransactionsController
    let day = sectionsHeadersData[indexPath.section].firstDay
    guard let transaction = dataService?.transaction(index: indexPath.row, forDay: day) else { return }
    dataService?.remove(transaction: transaction)
  }
}

extension HistoryViewModel: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    var height: CGFloat = 56
    if indexPath.row == 0 {
      height += TransactionCell.shadowInset
    }
    let cellsInSection = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
    if indexPath.row == cellsInSection - 1 { // it's the last cell in section
      height += TransactionCell.shadowInset
    }
    return height
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 56
  }
  
  private func displayString(forDate date: Date, formatter: DateFormatter) -> String {
    if Calendar.current.isDate(date, inSameDayAs: Date.now) {
      return "Today"
    } else if Calendar.current.isDate(date, inSameDayAs: Date(timeIntervalSinceNow: -Date.secondsPerDay)) {
      return "Yesterday"
    } else {
      return formatter.string(from: date)
    }
  }
  
  private func title(forSectionHeader sectionData: SectionHeaderData) -> String {
    if sectionData.numberOfDays == 1 {
      let dateFormatter = DateFormatter(dateFormat: "EEEE d")
      return displayString(forDate: sectionData.firstDay, formatter: dateFormatter)
    } else {
      let weekdayFormatter = DateFormatter(dateFormat: "E d")
      let firstDayString = displayString(forDate: sectionData.firstDay, formatter: weekdayFormatter)
      let lastDay = sectionData.firstDay.addingTimeInterval(Double(Date.secondsPerDay * Double(sectionData.numberOfDays - 1)))
      let lastDayString = displayString(forDate: lastDay, formatter: weekdayFormatter)
      return "\(firstDayString) - \(lastDayString)"
    }
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let headerView = UIView()
    //    headerView.backgroundColor = .clear
    let sectionData = sectionsHeadersData[section]
    
    let amountLabel = UILabel()
    amountLabel.font = .systemFont(ofSize: 17, weight: .medium)
    amountLabel.textColor = .darkGray
    amountLabel.textAlignment = .right
    
    let amount: Double
    if !sectionData.isEmpty,
      let dayAmount = dataService?.totalAmount(forDay: sectionData.firstDay) {
      amount = dayAmount
    } else {
        amount = 0
    }
    amountLabel.text = formatMoney(amount: amount, currency: .JPY)
    
    amountLabel.translatesAutoresizingMaskIntoConstraints = false
    headerView.addSubview(amountLabel)
    amountLabel.addConstraints([
      NSLayoutConstraint(item: amountLabel, attribute: .width , relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 108),
      NSLayoutConstraint(item: amountLabel, attribute: .height , relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 26)
      ])
    headerView.addConstraints([
      NSLayoutConstraint(item: amountLabel, attribute: .trailing , relatedBy: .equal, toItem: headerView, attribute: .trailingMargin, multiplier: 1, constant: 0),
      NSLayoutConstraint(item: amountLabel, attribute: .centerY , relatedBy: .equal, toItem: headerView, attribute: .centerY, multiplier: 1, constant: 0)
      ])
    
    let dateLabel = UILabel()
    dateLabel.font = .systemFont(ofSize: 17, weight: .medium)
    dateLabel.textColor = .darkGray
    dateLabel.text = title(forSectionHeader: sectionData)
    
    dateLabel.translatesAutoresizingMaskIntoConstraints = false
    headerView.addSubview(dateLabel)
    dateLabel.addConstraint(
      NSLayoutConstraint(item: dateLabel, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 26)
    )
    headerView.addConstraints([
      NSLayoutConstraint(item: dateLabel, attribute: .centerY, relatedBy: .equal, toItem: headerView, attribute: .centerY, multiplier: 1, constant: 0),
      NSLayoutConstraint(item: dateLabel, attribute: .leading, relatedBy: .equal, toItem: headerView, attribute: .leading, multiplier: 1, constant: 16),
      NSLayoutConstraint(item: dateLabel, attribute: .trailing, relatedBy: .equal, toItem: amountLabel, attribute: .leading, multiplier: 1, constant: 8)
      ])
    
    return headerView
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) as? TransactionCell else { return }
    let sectionDate = sectionsHeadersData[indexPath.section].firstDay
    guard let transaction = dataService?.transaction(index: indexPath.row, forDay: sectionDate) else { return }
    editor?.startEditing(transaction: transaction, byReplacingView: cell)
  }
}