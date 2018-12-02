//
//  EditTransactionViewModel.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/11/20.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol ManagedTransactionEditor {
  func startEditing(transaction: Transaction, byReplacingView: UIView)
}

class EditTransactionViewModel {
  weak var guillotine: GuillotineViewController?
  weak var dataService: DataService?
  private var viewController: EditTransactionViewController?
  
  private var composerTransformBeforeEditing = CGAffineTransform.identity
  private var composerTransformToMatchCell = CGAffineTransform.identity
  private weak var replacedView: UIView?
  private var editingTransaction: Transaction?
  
  lazy var guillotineCancel: GuillotineCancelCallback = { [weak self] in
    self?.dismiss()
  }
}

extension EditTransactionViewModel: ManagedTransactionEditor {
  func startEditing(transaction: Transaction, byReplacingView viewToReplace: UIView) {
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    guard let controller = storyboard.instantiateViewController(withIdentifier: "editTransactionVC") as? EditTransactionViewController else { return }
    viewController = controller
    guillotine?.view.addSubview(controller.view)
    controller.delegate = self
    let saveButtonTitle = NSLocalizedString("Save", comment: "Save button title in transaction editing")
    controller.setCommitButton(title: saveButtonTitle)
    
    guillotine?.setNavigationBar(hidden: false, animated: true)
    guillotine?.navigationBarTitle = NSLocalizedString("Edit", comment: "Title of the view that edits transaction")
    
    guard let superviewOfViewToReplace = viewToReplace.superview else { return }
    replacedView = viewToReplace
    replacedView?.isHidden = true
    editingTransaction = transaction
    
    guard let composer = controller.composer else { return }
    let newPosition = superviewOfViewToReplace.convert(viewToReplace.frame.origin, to: nil)
    composerTransformBeforeEditing = composer.transform
    composer.transform = .identity // to properly calculate transform to match cell
    composerTransformToMatchCell = CGAffineTransform(translationX: 0, y: newPosition.y - 519)
    composer.transform = composerTransformToMatchCell
    
    controller.switchTo(mode: .table, animated: false)
    composer.alpha = 1
    composer.display(transaction: transaction)
    controller.setCommitButton(enabled: true)
    controller.set(date: transaction.date)
    controller.set(category: transaction.category)
    controller.hideControls(withProgress: 1, includingComposer: false)

    UIViewPropertyAnimator(duration: Animation.duration, curve: .easeOut) {
      controller.blurView.effect = UIBlurEffect(style: .light)
      controller.hideControls(withProgress: 0)
    }.startAnimation()

    composer.set(mode: .amount, animated: true)
  }
}

extension EditTransactionViewModel: TransactionEditorDelegate {
  func didSwitch(toMode: TransactionComposerMode) { }
  
  func commit(amount: Double, category: TransactionCategory, date: Date) {
    guard var transaction = editingTransaction else { return }
    transaction.amount = amount
    transaction.category = category
    transaction.date = date
    dataService?.update(transaction: transaction)
    dismiss()
  }
  
  private func dismiss() {
    guillotine?.setNavigationBar(hidden: true, animated: true)
    viewController?.composer.set(mode: .table, animated: true)
    let animator = UIViewPropertyAnimator(duration: Animation.duration, curve: .easeInOut) { [weak self] in
      guard let transformToMatchCell = self?.composerTransformToMatchCell else { return }
      self?.viewController?.blurView.effect = nil
      self?.viewController?.composer.transform = transformToMatchCell
      self?.viewController?.hideControls(withProgress: 1, includingComposer: false)
    }
    animator.addCompletion { [weak self] _ in
      self?.replacedView?.isHidden = false
      self?.viewController?.view.removeFromSuperview()
      self?.viewController = nil
      self?.replacedView?.isHidden = false
    }
    animator.startAnimation()
  }
}
