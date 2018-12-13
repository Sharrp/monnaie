//
//  SyncViewController.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit
import MultipeerConnectivity

extension Notification.Name {
  static let syncDidDismiss = Notification.Name("syncDidDismiss")
}

// Responsible for setting up all the pieces requried for sync
class SyncViewController: UIViewController {
  @IBOutlet weak var nameLabel: UILabel?
  @IBOutlet weak var nameView: UIView!
  
  @IBOutlet var stepLabels: [UILabel]!
  @IBOutlet var stepHeights: [NSLayoutConstraint]!
  
  var syncManager: P2PSyncManager? {
    didSet {
      syncManager?.presentor = self
      syncManager?.dataDelegate = syncController
      syncController.dataSender = syncManager
      guard let syncName = syncManager?.syncName else { return }
      display(name: syncName)
    }
  }
  weak var settings: Settings?
  weak var mergeDelegate: MergeDelegate? {
    didSet {
      syncController.mergeDelegate = mergeDelegate
    }
  }
  weak var renamer: AuthorRenamer?
  weak var syncDataSource: SyncTransactionsDataSource? {
    didSet {
      syncController.dataSource = syncDataSource
    }
  }
  
  private let syncController = SyncController()
  private var autoSyncBuddy: SyncBuddy?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    if let syncName = syncManager?.syncName {
      display(name: syncName)
    }
    nameView.layer.borderColor = Color.border.cgColor
  }
  
  override func updateViewConstraints() {
    super.updateViewConstraints()
    
    for (i, height) in stepHeights.enumerated() {
      let width = UIScreen.main.bounds.width - 24 * 2 // sorry for that
      let restrictionBox = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
      height.constant = stepLabels[i].sizeThatFits(restrictionBox).height
    }
  }

  private func dismissWithNotification() {
    self.dismiss(animated: true, completion: nil)
    NotificationCenter.default.post(name: .syncDidDismiss, object: nil)
  }
  
  @IBAction func cancel() {
    syncManager?.stopSync()
    dismissWithNotification()
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard segue.identifier == "name-edit" else { return }
    guard let vc = segue.destination as? SyncNameViewController else { return }
    vc.currentName = syncManager?.syncName
    vc.delegate = self
  }
}

extension SyncViewController: SyncPresentorDelegate {
  private func updateStatus(to newStatus: String) {
//    self.syncStatusLabel.text = newStatus
  }
  
  func updated(availableBuddies: [SyncBuddy]) {
//    buddies = availableBuddies
//    peersTableView.reloadData()
  }
  
  func syncRequestReceived(fromBuddy buddy: SyncBuddy, handler: @escaping SyncRequestHandler) {
    let alert = UIAlertController(title: "Sync request",
                                message: "Do you want to sync with \(buddy.name)?",
                         preferredStyle: .alert)
    let noAction = UIAlertAction(title: "No", style: .default) { [weak self] _ in
      handler(false)
      self?.updateStatus(to: "You declined sync request")
    }
    alert.addAction(noAction)
    let yesAction = UIAlertAction(title: "Yes", style: .default) { _ in
      handler(true)
    }
    alert.addAction(yesAction)
    self.present(alert, animated: true, completion: nil)
  }
  
  func requestDeclined(byBuddy buddy: SyncBuddy) {
    updateStatus(to: "\(buddy.name) declined sync request")
  }
  
  func syncInProgress(withBuddy buddy: SyncBuddy) {
    updateStatus(to: "Syncing with \(buddy.name)")
  }
  
  func syncFinished(withBuddy: SyncBuddy) {
    updateStatus(to: "Sync finished")
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
      self?.dismissWithNotification()
    }
  }
  
  func sync(withBuddy: SyncBuddy, failedWithMessage message: String) {
    updateStatus(to: "Sync failed: \(message)")
  }
}

extension SyncViewController: SyncNameUpdateDelegate {
  func display(name: String) {
    let formattedText = NSMutableAttributedString(string: "You are \(name)")
    let font = UIFont.systemFont(ofSize: 16, weight: .medium)
    let range = NSRange(location: formattedText.length - name.count, length: name.count)
    formattedText.addAttribute(.font, value: font, range: range)
    formattedText.addAttribute(.foregroundColor, value: Color.accentText, range: range)
    nameLabel?.attributedText = formattedText
  }
  
  func nameUpdated(to newName: String) {
    display(name: newName)
    let oldName = settings?.syncName ?? ""
    settings?.syncName = newName
    renamer?.renameAuthor(from: oldName, to: newName)
    syncManager?.deviceNameUpdated(toName: newName)
  }
}
