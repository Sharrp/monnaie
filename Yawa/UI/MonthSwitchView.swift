//
//  MonthSwitcherView.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol MonthSwitchDelegate {
  func didSelect(monthDate: Date)
}

class MonthSwitchProvider: NSObject {
  @IBOutlet weak var collectionView: UICollectionView!
  
  private var selectedIndex = 0
  var delegate: MonthSwitchDelegate?
  var reports = [MonthReport]() {
    didSet {
      collectionView.reloadData()
    }
  }
  var todayAmount = 0.0 {
    didSet {
      let todayIndexPath = IndexPath(row: reports.count, section: 0)
      collectionView.reloadItems(at: [todayIndexPath])
    }
  }
  
  private func string(forMonth monthDate: Date) -> String {
    let format: String
    if Calendar.current.isDate(monthDate, equalTo: Date(), toGranularity: .year) {
      format = "MMMM"
    } else {
      format = "MMM yyyy"
    }
    return DateFormatter(dateFormat: format).string(from: monthDate)
  }
  
  func selectLastMonth() {
    // We need to wait until reload data is finished, scrollToItem won't work
    let indexPath = IndexPath(item: reports.count - 1, section: 0)
    selectedIndex = indexPath.row
    if let selectedCell = collectionView.cellForItem(at: indexPath) as? MonthSwitchCell {
      selectedCell.setState(selected: true)
    }
    collectionView.performBatchUpdates(nil, completion: { [unowned self] _ in
      self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .left)
    })
  }
}

extension MonthSwitchProvider: UICollectionViewDataSource {
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

extension MonthSwitchProvider: UICollectionViewDelegate {
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
    delegate?.didSelect(monthDate: report.monthDate)
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
    return indexPath.row != reports.count
  }
  
  func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
    return false // we deselect cells manually on selection
  }
}

extension MonthSwitchProvider: UICollectionViewDelegateFlowLayout {
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

class MonthSwitchCell: UICollectionViewCell {
  @IBOutlet weak var amountLabel: UILabel!
  @IBOutlet weak var monthLabel: UILabel!
  
  override func awakeFromNib() {
    super.awakeFromNib()
    
    selectedBackgroundView = UIView(frame: bounds)
    selectedBackgroundView?.backgroundColor = UIColor(hex: 0xF2F2F6)
  }
  
  func setState(selected: Bool) {
    let black = UIColor(hex: 0x333333)
    let gray = UIColor(hex: 0xAAAAAA)
    amountLabel.textColor = selected ? black : gray
    monthLabel.textColor = selected ? black : gray
  }
}
