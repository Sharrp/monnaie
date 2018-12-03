//
//  SummaryViewModel.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/09/26.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class SummaryViewModel: NSObject {
  weak var dataService: DataService?
  private var summary: CategoriesSummary? // cached data
  var getSelectedMonth: SelectedMonthGetter?
  weak var settings: Settings?
  
  private var tableView: UITableView?
  
  private var isActive: Bool {
    return tableView != nil
  }
  
  lazy var monthChanged: MonthSwitchedCallback? = { [weak self] _ in
    guard let isActive = self?.isActive, isActive else { return }
    self?.update()
  }
  
  lazy var dataServiceUpdated: DataServiceUpdateCallback? = { [weak self] in
    guard let isActive = self?.isActive, isActive else { return }
    self?.update()
  }
  
  lazy var currencyChanged: SettingUpdateCallback = { [weak self] in
    self?.update()
  }
  
  private func update() {
    updateCache()
    tableView?.reloadData()
  }
}

extension SummaryViewModel: TransactionsProjecting {
  var projectionName: String {
    return NSLocalizedString("Summary", comment: "Monthly summary tab name")
  }
  
  func project(intoTableView tableView: UITableView?) {
    self.tableView = tableView
    guard let tableView = tableView else { return }
    tableView.dataSource = self
    tableView.delegate = self
    update()
  }
}

extension SummaryViewModel: UITableViewDataSource {
  private func updateCache() {
    guard let selectedMonth = getSelectedMonth?() else { return }
    guard let updatedSummary = dataService?.categoriesSummary(forMonth: selectedMonth) else { return }
    summary = updatedSummary
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    guard let summary = summary else { return 0 }
    return summary.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    guard let summary = summary else { return UITableViewCell() }
    
    let categoryInfo = summary[indexPath.row]
    let cellID = "summaryCell"
    let cell: SummaryCell
    if let dequeuedCell = tableView.dequeueReusableCell(withIdentifier: cellID) as? SummaryCell {
      cell = dequeuedCell
    } else {
      cell = SummaryCell(style: .default, reuseIdentifier: cellID)
    }
    cell.backgroundColor = .clear
    cell.emojiLabel.text = categoryInfo.category.emoji
    cell.categoryLabel.text = categoryInfo.category.name
    cell.level = categoryInfo.amount / summary[0].amount
    
    let currency = settings?.userCurrency ?? Currency.defaultCurrency
    cell.valueLabel.text = "\(formatMoney(amount: categoryInfo.amount, currency: currency))"
    return cell
  }
  
  func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    cell.layoutIfNeeded()
    cell.setNeedsUpdateConstraints()
  }
}

extension SummaryViewModel: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 60
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return .leastNormalMagnitude
  }
}
