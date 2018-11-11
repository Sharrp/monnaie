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
  
  private struct SectionHeaderData {
    let firstDay: Date
    let isEmpty: Bool
    let numberOfDays: Int
  }
  
  @IBOutlet weak var navigationBar: UINavigationBar!
  private var navBarBorder = UIView()
  @IBOutlet weak var tableView: UITableView!
  private let tableViewBottomOffsetWhenCollapsed: CGFloat = -60
  private var sectionsHeadersData = [SectionHeaderData]()
  @IBOutlet weak var controlPanel: UIView!
  
  @IBOutlet weak var fakeCard: ShadowRoundedView!
  private let fakeCardOffsetWhenExpanded: CGFloat = 16
  
  @IBOutlet weak var monthSwitcherCollectionView: UICollectionView!
  @IBOutlet weak var monthSwitchProvider: MonthSwitchProvider!
  private var selectedMonthDate = Date()
  
  private let defaultDateFormatter = DateFormatter(dateFormat: "EEEE d")
  let dataProvider = TransactionsController(dbName: "production")
  private let summaryProvider = SummaryProvider()
  
  private var historyLastContentOffset: CGFloat = 0
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dataProvider.presentor = self
    summaryProvider.transactionsController = dataProvider
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
    monthSwitchProvider.delegate = self
    monthSwitchProvider.selectLastMonth()
    
    fakeCard.shadowRadius = 12
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
      summaryProvider.monthDate = selectedMonthDate
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
  // Merges all consequemtial empty days into one section
  private func recalculateHeaders(forNumberOfFirstDays numOfDays: Int, inMonth monthDate: Date) {
    sectionsHeadersData = [SectionHeaderData]()
    let nonEmptyDays = dataProvider.daysWithTransactions(forMonth: monthDate)
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
    let daysToShow: Int
    if selectedMonthDate.isSame(granularity: .month, asDate: Date()) {
      daysToShow = Calendar.current.component(.day, from: selectedMonthDate)
    } else {
      guard let daysCount = Calendar.current.range(of: .day, in: .month, for: selectedMonthDate)?.count else { return 0 }
      daysToShow = daysCount
    }
    recalculateHeaders(forNumberOfFirstDays: daysToShow, inMonth: selectedMonthDate)
    return sectionsHeadersData.count
  }
  
  private func date(forSection section: Int) -> Date? {
    var components = DateComponents()
    components.day = section + 1
    components.month = Calendar.current.component(.month, from: selectedMonthDate)
    components.year = Calendar.current.component(.year, from: selectedMonthDate)
    return Calendar.current.date(from: components)
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let sectionData = sectionsHeadersData[section]
    if sectionData.isEmpty {
      return 0
    } else {
      let count = dataProvider.numberOfTransactions(onDay: sectionData.firstDay)
      return count
    }
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
    
//    let cellsInSection = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
//    if indexPath.row == 0 {
//      cell.set(radius: 8, forCormers: [.topLeft, .topRight])
//    } else if indexPath.row == cellsInSection - 1 {
//      cell.set(radius: 8, forCormers: [.bottomLeft, .bottomRight])
//    } else {
//      cell.layer.mask = nil
//    }
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
  func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    return 56
  }
  
  private func displayString(forDate date: Date, formatter: DateFormatter) -> String {
    if Calendar.current.isDate(date, inSameDayAs: Date()) {
      return "Today"
    } else if Calendar.current.isDate(date, inSameDayAs: Date(timeIntervalSinceNow: -86400)) {
      return "Yesterday"
    } else {
      return formatter.string(from: date)
    }
  }
  
  private func title(forSectionHeader sectionData: SectionHeaderData) -> String {
    if sectionData.numberOfDays == 1 {
      return displayString(forDate: sectionData.firstDay, formatter: defaultDateFormatter)
    } else {
      let weekdayFormatter = DateFormatter(dateFormat: "E d")
      let firstDayString = displayString(forDate: sectionData.firstDay, formatter: weekdayFormatter)
      let lastDay = sectionData.firstDay.addingTimeInterval(Double(86400 * (sectionData.numberOfDays - 1)))
      let lastDayString = displayString(forDate: lastDay, formatter: weekdayFormatter)
      return "\(firstDayString) - \(lastDayString)"
    }
  }
  
  func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    let headerView = UIView()
    let sectionData = sectionsHeadersData[section]
    
    let amountLabel = UILabel()
    amountLabel.font = .systemFont(ofSize: 17, weight: .medium)
    amountLabel.textColor = .darkGray
    amountLabel.textAlignment = .right
    let amount = sectionData.isEmpty ? 0 : dataProvider.totalAmount(forDay: sectionData.firstDay)
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

extension HistorySummaryViewController: MonthSwitchDelegate {
  func didSelect(monthDate: Date) {
    selectedMonthDate = monthDate
    summaryProvider.monthDate = monthDate
    tableView.reloadData()
  }
}

extension HistorySummaryViewController: GuilliotineSlideProgressDelegate {
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
