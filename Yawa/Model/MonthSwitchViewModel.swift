//
//  MonthSwitchViewModel.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

typealias MonthSwitchedCallback = (Date) -> Void
typealias SelectedMonthGetter = () -> Date?

class MonthSwitchViewModel: NSObject {
  weak var collectionView: UICollectionView? {
    didSet {
      collectionView?.dataSource = self
      collectionView?.delegate = self
    }
  }
  
  var dataService: DataService? {
    didSet {
      dataServiceUpdated?()
    }
  }
  private var reports = [MonthReport]()
  private var todayAmount = 0.0
  
  private var selectedIndex = 0
  var selectedMonth: Date? {
    guard reports.count > selectedIndex else { return nil }
    return reports[selectedIndex].monthDate
  }
  
  private var callbacks = [MonthSwitchedCallback?]()
  func subscribe(callback: MonthSwitchedCallback?) {
    callbacks.append(callback)
  }
  
  lazy var dataServiceUpdated: DataServiceUpdateCallback? = { [weak self] in
    guard let dataService = self?.dataService else { return }
    self?.reports = dataService.monthlyAmounts()
    self?.todayAmount = dataService.totalAmount(forDay: Date.now)
    self?.collectionView?.reloadData()
  }
  
  private func string(forMonth monthDate: Date) -> String {
    let isSameYear = Calendar.current.isDate(monthDate, equalTo: Date.now, toGranularity: .year)
    let format = isSameYear ? "MMMM" : "MMM yyyy"
    return DateFormatter(dateFormat: format).string(from: monthDate)
  }
  
  func selectLastMonth() {
    // We need to wait until reload data is finished, scrollToItem won't work
    let indexPath = IndexPath(item: reports.count - 1, section: 0)
    selectedIndex = indexPath.row
    if let selectedCell = collectionView?.cellForItem(at: indexPath) as? MonthSwitchCell {
      selectedCell.setState(selected: true)
    }
    collectionView?.performBatchUpdates(nil, completion: { [unowned self] _ in
      self.collectionView?.selectItem(at: indexPath, animated: false, scrollPosition: .left)
    })
  }
}

extension MonthSwitchViewModel: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return reports.count + 1
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let reuseID = "monthSwitchCell"
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath) as! MonthSwitchCell
    cell.layer.cornerRadius = 8
    
    if indexPath.row < reports.count {
      let report = reports[indexPath.row]
      cell.amountLabel.text = formatMoney(amount: report.amount, currency: .JPY)
      cell.monthLabel.text = string(forMonth: report.monthDate)
      cell.setState(selected: indexPath.row == selectedIndex)
    } else {
      cell.amountLabel.text = formatMoney(amount: todayAmount, currency: .JPY)
      cell.monthLabel.text = "Today"
      cell.setState(selected: true)
    }
    return cell
  }
}

extension MonthSwitchViewModel: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    // There is no good way to disable celection of a particular cell ("Today" in out case)
    // That's why multiple selection is enabled and selection is maintained semi-manually
    let prviouslySelectedIndex = IndexPath(row: selectedIndex, section: 0)
    collectionView.deselectItem(at: prviouslySelectedIndex, animated: true)
    if let deselectedRow = collectionView.cellForItem(at: prviouslySelectedIndex) as? MonthSwitchCell {
      deselectedRow.setState(selected: false)
    }
    
    selectedIndex = indexPath.row
    let report = reports[selectedIndex]
    if let selectedRow = collectionView.cellForItem(at: indexPath) as? MonthSwitchCell {
      selectedRow.setState(selected: true)
    }
    callbacks.forEach{ $0?(report.monthDate) }
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    return indexPath.row != reports.count
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
    return false // we deselect cells manually on selection
  }
}

extension MonthSwitchViewModel: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let width: CGFloat
    if indexPath.row == reports.count {
      width = 92
    } else {
      width = 110
    }
    return CGSize(width: width, height: 56)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
  }
}
