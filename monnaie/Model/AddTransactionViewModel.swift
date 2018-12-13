//
//  AddTransactionViewModel.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/11/20.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

typealias TransactionAddedCallback = () -> Void

class AddTransactionViewModel {
  weak var guillotine: GuillotineViewController?
  weak var dataService: DataService?
  weak var viewController: EditTransactionViewController?
  weak var settings: Settings?
  
  private var callbacks = [TransactionAddedCallback?]()
  func subscribeForAdding(callback: TransactionAddedCallback?) {
    callbacks.append(callback)
  }
  
  lazy var guillotineCancel: GuillotineCancelCallback = { [weak self] in
    self?.viewController?.switchTo(mode: .waitingForInput, animated: true)
    self?.configure(forMode: .waitingForInput, animated: true)
  }
  
  func didFinishLaunching() {
    configure(forMode: .waitingForInput, animated: false)
    viewController?.switchTo(mode: .waitingForInput, animated: false)
  }
  
  private func configure(forMode mode: TransactionComposerMode, animated: Bool) {
    guillotine?.navigationBarTitle = NSLocalizedString("Addding", comment: "Navigation bar title during adding")
    let barHidden = mode == .waitingForInput
    guillotine?.setNavigationBar(hidden: barHidden, animated: animated)
    guillotine?.setBlade(hidden: shouldHideBlade(inMode: mode), animated: animated)
  }
  
  private func shouldHideBlade(inMode mode: TransactionComposerMode) -> Bool {
    let hasNoTransactions = dataService?.isEmpty() ?? true
    return hasNoTransactions || mode != .waitingForInput
  }
  
  private func notifySubscribers() {
    callbacks.forEach{ $0?() }
  }
}

extension AddTransactionViewModel: TransactionEditorDelegate {
  func didSwitch(toMode mode: TransactionComposerMode) {
    configure(forMode: mode, animated: true)
  }
  
  func commit(amount: Double, category: TransactionCategory, date: Date) {
    let syncName = settings?.syncName ?? ""
    let transaction = Transaction(amount: amount, category: category,
                                  authorName: syncName, transactionDate: date)
    dataService?.add(transaction: transaction)
    configure(forMode: .waitingForInput, animated: true)
    viewController?.animateComposerFlyAway()
    notifySubscribers()
  }
}
