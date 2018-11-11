//
//  SummaryProvider.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/09/26.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class SummaryProvider: NSObject {
  weak var transactionsController: TransactionsController?
  private var summary: CategoriesSummary? // cached data
  var monthDate = Date.now {
    didSet {
      updateData()
    }
  }
  
  let minChartBarWidth: CGFloat = 8
}

extension SummaryProvider: UITableViewDataSource {
  private func updateData() {
    guard let updatedSummary = transactionsController?.categoriesSummary(forMonth: monthDate) else { return }
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
    
    let maxChartBarWidth = cell.valueLabel.frame.origin.x - cell.categoryLabel.frame.origin.x - 8 // margin between bar and valueLabel
    let maxCategoryAmount = summary[0].amount
    let chartBarWidth = maxChartBarWidth * CGFloat(categoryInfo.amount / maxCategoryAmount)
    cell.chartBarWidth.constant = max(minChartBarWidth, chartBarWidth)
    cell.valueLabel.text = "\(formatMoney(amount: categoryInfo.amount, currency: .JPY))"
    return cell
  }
}

extension SummaryProvider: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 60
  }
  
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return .leastNormalMagnitude
  }
}
