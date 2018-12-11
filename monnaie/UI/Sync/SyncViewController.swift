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
  weak var mergeDelegate: MergeDelegate?
  weak var transactionsDataSource: SyncTransactionsDataSource?
  weak var renamer: AuthorRenamer?
  
  private let syncController = SyncController()
  private var autoSyncBuddy: SyncBuddy?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    syncController.mergeDelegate = mergeDelegate
    syncController.dataSource = transactionsDataSource
    
    guard let syncName = syncManager?.syncName else { return }
    display(name: syncName)
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
    nameLabel?.text = "You are \(name)"
  }
  
  func nameUpdated(to newName: String) {
    display(name: newName)
    let oldName = settings?.syncName ?? ""
    settings?.syncName = newName
    renamer?.renameAuthor(from: oldName, to: newName)
    syncManager?.deviceNameUpdated(toName: newName)
  }
}
