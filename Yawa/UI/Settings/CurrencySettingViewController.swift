//
//  CurrencySettingViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/26.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class CurrencySettingViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    tableView.backgroundColor = Color.background
  }
}

extension CurrencySettingViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 2
  }
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0: return Currency.allCases.count - 1
    case 1: return 1
    default: return 0
    }
  }
  
  private func currencyFor(indexPath: IndexPath) -> Currency {
    return indexPath.section == 1 ? Currency.all : Currency.allCases[indexPath.row]
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "currencyCell"
    let cell: UITableViewCell
    if let dequedCell = tableView.dequeueReusableCell(withIdentifier: cellID) {
      cell = dequedCell
    } else {
      cell = UITableViewCell(style: .default, reuseIdentifier: cellID)
      cell.tintColor = Color.accentText
      cell.textLabel?.textColor = Color.accentText
      cell.selectionStyle = .none
    }
    let currency = currencyFor(indexPath: indexPath)
    cell.textLabel?.text = currency.name
    return cell
  }
  
  func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    if section == 1 {
      return "The currency sign ¤ is a character used to denote an unspecified currency."
    }
    return nil
  }
}

extension CurrencySettingViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    guard let cell = tableView.cellForRow(at: indexPath) else { return }
    cell.accessoryType = .checkmark
//    let currency = currencyFor(indexPath: indexPath)
  }
  
  func tableView(_ tableView: UITableView, willDeselectRowAt indexPath: IndexPath) -> IndexPath? {
    guard let cell = tableView.cellForRow(at: indexPath) else { return nil }
    cell.accessoryType = .none
    return indexPath
  }
}
