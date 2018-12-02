//
//  SettingsViewController.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/11/26.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

enum SettingOption {
  case currency
  case export
  case hapticFeedback
  case feedbackTelegram
  
  var title: String {
    switch self {
    case .currency: return NSLocalizedString("Currency sign", comment: "Name of currency sign setting")
    case .export: return NSLocalizedString("Export data as CSV", comment: "Name of export data as CSV setting")
    case .hapticFeedback: return NSLocalizedString("Haptic feedback", comment: "Name of haptic feedback setting")
    case .feedbackTelegram: return NSLocalizedString("Telegram your feedback", comment: "Name of telegram feedback setting")
    }
  }
}

class SettingsViewController: UIViewController {
  @IBOutlet weak var tableView: UITableView!
  weak var settings: Settings?
  weak var exporter: Exporter?
  private let telegramUsername = "sharrp"
  private let hapticSwitch = UISwitch()

  override func viewDidLoad() {
    super.viewDidLoad()
    tableView.backgroundColor = Color.background
    navigationController?.navigationBar.tintColor = Color.accentText
    
    hapticSwitch.addTarget(self, action: #selector(hapticEnabledChanged), for: .valueChanged)
    hapticSwitch.onTintColor = Color.accentText
  }
  
  @IBAction func dismiss() {
    dismiss(animated: true, completion: nil)
  }
  
  @objc func hapticEnabledChanged(theSwitch: UISwitch) {
    settings?.hapticEnabled = theSwitch.isOn
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
      return .feedbackTelegram
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
    
    switch setting {
    case .currency:
      cell.accessoryType = .disclosureIndicator
    case .hapticFeedback:
      cell.accessoryView = hapticSwitch
      hapticSwitch.isOn = settings?.hapticEnabled ?? false
    default:
      break
    }
    return cell
  }
}

extension SettingsViewController: UITableViewDelegate {
  private func openTelegram() {
    guard let url = URL(string: "tg://resolve?domain=\(telegramUsername)") else { return }
    if UIApplication.shared.canOpenURL(url) {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    } else {
      
      let alertTitle = NSLocalizedString("Telegram isn't installed", comment: "Alert title when Telegram isn't installed")
      let messagePrefix = NSLocalizedString("Use Telegram messenger to reach out to", comment: "Prefix for Telegram username to reach out to")
      let alert = UIAlertController(title: alertTitle message: messagePrefix + " " + telegramUsername,
                                    preferredStyle: .actionSheet)
      let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel button title")
      let cancel = UIAlertAction(title: cancelTitle, style: .cancel, handler: nil)
      let installTitle = NSLocalizedString("Install Telegram", comment: "Install telegram dialogue title")
      let install = UIAlertAction(title: installTitle, style: .default) { _ in
        guard let telegramAppStoreURL = URL(string: "https://itunes.apple.com/app/id686449807") else { return }
        UIApplication.shared.open(telegramAppStoreURL, options: [:], completionHandler: nil)
      }
      alert.addAction(cancel)
      alert.addAction(install)
      present(alert, animated: true, completion: nil)
    }
  }
  
  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let setting = settingOption(forIndexPath: indexPath)
    switch setting {
    case .currency:
      performSegue(withIdentifier: "CurrecySettingSegue", sender: self)
    case .feedbackTelegram:
      openTelegram()
    case .export:
      exporter?.exportAll(presentor: self)
    case .hapticFeedback:
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
