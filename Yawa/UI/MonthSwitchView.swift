//
//  MonthSwitcherView.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/01.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

struct MonthReport {
  let monthDate: Date
  let amount: Double
}

protocol MonthSwitchDelegate {
  func didSelect(monthDate: Date)
}

class MonthSwitchProvider: NSObject {
  var delegate: MonthSwitchDelegate?
  var reports = [MonthReport]() {
    didSet {
      collectionView.reloadData()
    }
  }
  var todayAmount = 0.0
  
  @IBOutlet weak var collectionView: UICollectionView!
  
  private var selectedIndex = 0
  
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
    collectionView.performBatchUpdates(nil, completion: { [unowned self] _ in
      self.collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .right)
    })
  }
}

extension MonthSwitchProvider: UICollectionViewDataSource {
  func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    return reports.count
  }
  
  func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    let reuseID = "monthSwitchCell"
    let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseID, for: indexPath) as! MonthSwitchCell
    cell.layer.cornerRadius = 8
    let report = reports[indexPath.row]
    cell.amountLabel.text = formatMoney(amount: report.amount, currency: .JPY)
    cell.monthLabel.text = string(forMonth: report.monthDate)
    return cell
  }
}

extension MonthSwitchProvider: UICollectionViewDelegate {
  func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    selectedIndex = indexPath.row
    let report = reports[selectedIndex]
    delegate?.didSelect(monthDate: report.monthDate)
  }
}

extension MonthSwitchProvider: UICollectionViewDelegateFlowLayout {
  func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
    return CGSize(width: 116, height: 56)
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
}
