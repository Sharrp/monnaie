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
  weak var view: MonthSwitchView? {
    didSet {
      guard let view = view else { return }
      view.collectionView.allowsMultipleSelection = true
      view.collectionView.contentInset = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 8)
      view.collectionView.dataSource = self
      view.collectionView.delegate = self
      view.collectionView.isScrollEnabled = false
//      view.collectionView.allowsSelection = false
      view.setSeparatorHidden(progress: 1, animated: false)
    }
  }
  
  var dataService: DataService? {
    didSet {
      dataServiceUpdated?()
    }
  }
  private var reports = [MonthReport]()
  private var todayAmount = 0.0
  private var monthsHideProgress: CGFloat = 1
  
  // Layout
  private let margin: CGFloat = 8
  private let interCellMargin: CGFloat = 4
  private let monthWidth: CGFloat = 110
  private let todayWidth: CGFloat = 92
  
  private var scrollStarted = false // ensures that offsetWhenScrollStarted calculated only once when scroll started
  private var offsetWhenScrollStarted: CGFloat = 0
  private var usersScrollOffset: CGFloat?
  private var offsetToHideToday: CGFloat {
    guard let collectionViewWidth = view?.collectionView.frame.width else { return 0 }
    return CGFloat(reports.count) * (monthWidth + interCellMargin) + margin - collectionViewWidth
  }
  private var offsetToShowToday: CGFloat {
    return offsetToHideToday + interCellMargin + todayWidth
  }
  
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
    guard let strongSelf = self else { return }
    let reports = dataService.monthlyAmounts()
    strongSelf.reports = reports
    strongSelf.todayAmount = dataService.totalAmount(forDay: Date.now)
    guard let collectionView = self?.view?.collectionView else { return }
    collectionView.reloadData()
  }
  
  lazy var bladeScroll: GuillotineScrollCallback? = { [weak self] progress in
    guard let scrollStarted = self?.scrollStarted else { return }
    guard let collectionView = self?.view?.collectionView else { return }
    let hideProgress = 1 - progress
    if !scrollStarted {
      self?.offsetWhenScrollStarted = collectionView.contentOffset.x
      self?.scrollStarted = true
    }
    self?.update(hideProgress: hideProgress, animated: false)
  }
  
  lazy var bladeStateSwitch: GuillotineBladeStateCallback? = { [weak self] state in
    let hideProgress: CGFloat = state == .expanded ? 0 : 1
    guard let strongSelf = self else { return }
    self?.view?.collectionView.contentInset.right = strongSelf.margin - (strongSelf.interCellMargin + strongSelf.todayWidth) * (1 - hideProgress)
    let scrollAndSelectionEnabled = state == .expanded
    self?.view?.collectionView.isScrollEnabled = scrollAndSelectionEnabled
    self?.view?.collectionView.allowsSelection = scrollAndSelectionEnabled
    self?.scrollStarted = false
    self?.update(hideProgress: hideProgress, animated: true)
  }
  
  private func update(hideProgress: CGFloat, animated: Bool) {
    view?.setSeparatorHidden(progress: hideProgress, animated: animated)
    
    let zeroOffset = usersScrollOffset ?? offsetToHideToday
    let offset = zeroOffset + hideProgress * (offsetToShowToday - zeroOffset)
    view?.collectionView?.contentOffset.x = offset
    monthsHideProgress = hideProgress
    view?.collectionView.reloadData()
  }
  
  private func setNonCurrentMonthCellsHidden(progress: CGFloat, animated: Bool) {
    monthsHideProgress = progress
    view?.collectionView.reloadData()
  }
  
  private func string(forMonth monthDate: Date) -> String {
    let isSameYear = Calendar.current.isDate(monthDate, equalTo: Date.now, toGranularity: .year)
    let format = isSameYear ? "MMMM" : "MMM yyyy"
    return DateFormatter(dateFormat: format).string(from: monthDate)
  }
  
  func selectLastMonth() {
    selectedIndex = reports.count - 1
    update(hideProgress: 1, animated: false)
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
    
    let isSelected = indexPath.row == selectedIndex
    let isCurrentMonth = indexPath.row == reports.count - 1 // FIX: works only if there is no months from the future
    if indexPath.row < reports.count {
      let report = reports[indexPath.row]
      cell.amountLabel.text = formatMoney(amount: report.amount, currency: .JPY)
      cell.monthLabel.text = string(forMonth: report.monthDate)
      
      let backgroundAlpha = isSelected ? (1 - monthsHideProgress) : 0
      var textActitvityLevel: CGFloat = 1
      if !isSelected {
        textActitvityLevel = isCurrentMonth ? monthsHideProgress : 0
      }
      cell.setState(textActiveLevel: textActitvityLevel, backgroundAlpha: backgroundAlpha)
      cell.alpha = isCurrentMonth ? 1 : 1 - monthsHideProgress
    } else {
      cell.amountLabel.text = formatMoney(amount: todayAmount, currency: .JPY)
      cell.monthLabel.text = "Today"
      cell.setState(textActiveLevel: 1, backgroundAlpha: 0)
      cell.alpha = monthsHideProgress
    }
    return cell
  }
}

extension MonthSwitchViewModel: UICollectionViewDelegate {
  func scrollViewDidScroll(_ scrollView: UIScrollView) {
    if scrollView.isDragging {
      usersScrollOffset = scrollView.contentOffset.x
    }
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    guard indexPath.row < reports.count else { return false }
    guard selectedIndex != indexPath.row else { return false }
    selectedIndex = indexPath.row
    let report = reports[selectedIndex]
    callbacks.forEach{ $0?(report.monthDate) }
    collectionView.reloadData()
    return false
  }
}

extension MonthSwitchViewModel: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    let isTodayCell = indexPath.row == reports.count
    let width = isTodayCell ? todayWidth : monthWidth
    return CGSize(width: width, height: 56)
  }
  
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
    return UIEdgeInsets(top: 0, left: interCellMargin, bottom: 0, right: 0)
  }
}
