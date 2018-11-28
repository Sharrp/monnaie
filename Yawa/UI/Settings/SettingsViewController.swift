//
//  SettingsViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/11/26.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

enum SettingOption {
  case currency
  case export
  case hapticFeedback
  case feedback
  
  var title: String {
    switch self {
    case .currency: return "Currency sign"
    case .export: return "Export data as CSV"
    case .hapticFeedback: return "Haptic feedback"
    case .feedback: return "Email feedback"
    }
  }
}

class SettingsViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  weak var settings: Settings?

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.backgroundColor = Color.background
    navigationController?.navigationBar.tintColor = Color.accentText
  }
  
  @IBAction func dismiss() {
    dismiss(animated: true, completion: nil)
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard let currencyVC = segue.destination as? CurrencySettingViewController else { return }
    currencyVC.delegate = self
    currencyVC.selectedCurrency = settings?.userCurrency ?? Currency.defaultCurrency
  }
}

extension SettingsViewController: UITableViewDataSource {
  func numberOfSections(in tableView: UITableView) -> Int {
    return 3
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0:
      return 2
    case 1:
      return 1
    case 2:
      return 1
    default:
      return 0
    }
  }

  private func settingOption(forIndexPath indexPath: IndexPath) -> SettingOption {
    switch (indexPath.section, indexPath.row) {
    case (0, 0):
      return .currency
    case (0, 1):
      return .export
    case (1, 0):
      return .hapticFeedback
    case (2, 0):
      return .feedback
    default:
      fatalError("Unkown option in settings at index: \(indexPath)")
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cellID = "Settings"
    let cell: UITableViewCell
    if let dequedCell = tableView.dequeueReusableCell(withIdentifier: cellID) {
      cell = dequedCell
    } else {
      cell = UITableViewCell(style: .default, reuseIdentifier: cellID)
      cell.textLabel?.textColor = Color.accentText
    }
    let setting = settingOption(forIndexPath: indexPath)
    cell.textLabel?.text = setting.title
    if setting == .currency {
      cell.accessoryType = .disclosureIndicator
    }
    return cell
  }
}

extension SettingsViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let setting = settingOption(forIndexPath: indexPath)
    switch setting {
    case .currency:
      performSegue(withIdentifier: "CurrecySettingSegue", sender: self)
    default:
      break
    }
    tableView.deselectRow(at: indexPath, animated: true)
  }
}

extension SettingsViewController: CurrencyDelegate {
  func didChangeCurrency(to currency: Currency) {
    settings?.userCurrency = currency
  }
}
