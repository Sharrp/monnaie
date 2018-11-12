//
//  TransactionViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol TransactionUpdateDelegate: AnyObject {
  func add(transaction: Transaction)
  func update(transaction: Transaction)
}

class TransactionViewController: UIViewController {
  @IBOutlet weak var composer: TransactionComponserView!
  
  @IBOutlet weak var addButton: UIButton!
  
  @IBOutlet weak var keyboardHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var keyboardView: DigitKeyboardView!
  
  @IBOutlet weak var categoryCollectionView: UICollectionView!
  private let categoriesProvider = CategoriesProvider()
  
  @IBOutlet weak var dateTimePicker: UIDatePicker!
  
  weak var delegate: TransactionUpdateDelegate?
  var transaction: Transaction?
  private var guillotineInfoProvider: GuillotineInfoProvider?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(syncDidDismiss), name: .syncDidDismiss, object: nil)
    
    keyboardView.textField = composer.amountInput
    keyboardView.heightContraint = keyboardHeightConstraint
    
    categoryCollectionView.dataSource = categoriesProvider
    categoryCollectionView.delegate = categoriesProvider
    categoriesProvider.delegate = self
    clearCategory()
    
    dateTimePicker.setValue(UIColor(white: 0.6, alpha: 1), forKey: "textColor")

    composer.delegate = self
    composer.set(mode: .waitingForInput, animated: false)
    composer.set(date: Date.now)
    composer.set(category: .defaultCategory)
  }
  
  @objc func appDidBecomeActive() {
    resetStateAfterBackground()
  }
  
  private func resetStateAfterBackground() {
    guard composer.amountInput.text?.count == 0 else { return }
    resetDate()
    clearCategory()
    
    if guillotineInfoProvider?.bladeState == .collapsed {
      composer.reset()
    }
  }
  
  @objc func syncDidDismiss() {
    if composer.mode == .amount || composer.mode == .waitingForInput {
      composer.set(mode: composer.mode)
    }
  }
  
  // MARK: Category
  
  private func selectCategory(atIndex index: Int) {
    let indexPath = IndexPath(row: index, section: 0)
    categoryCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: .top)
  }
  
  private func deselectCategory() {
    guard let selectedItems = categoryCollectionView.indexPathsForSelectedItems else { return }
    if selectedItems.count > 0 {
      categoryCollectionView.deselectItem(at: selectedItems[0], animated: false)
    }
  }
  
  private func clearCategory() {
    deselectCategory()
  }
  
  // MARK: Date & time
  
  private func resetDate() {
    let today = Date.now
    dateTimePicker.date = today
    composer.set(date: today)
  }
  
  @IBAction func dateChanged(sender: UIDatePicker) {
    composer.set(date: sender.date)
  }
  
  // MARK: Add transaction
  
  @IBAction func addTapped() {
    guard let amount = composer.amount else { return }
    let category = categoriesProvider.selectedCategory
    
    if let transaction = transaction { // editing mode
      transaction.amount = amount
      transaction.category = category
      transaction.date = dateTimePicker.date
      delegate?.update(transaction: transaction)
    } else { // adding new transaction
      let transaction = Transaction(amount: amount, category: category, authorName: Settings.main.syncName, transactionDate: dateTimePicker.date)
      delegate?.add(transaction: transaction)
      
      composer.set(mode: .table)
      let yShiftFlyAway = -(composer.frame.maxY + 30)
      let animator = UIViewPropertyAnimator(duration: Animation.duration, curve: .easeOut) { [unowned self] in
        self.composer.transform = CGAffineTransform(translationX: 0, y: yShiftFlyAway).scaledBy(x: 0.1, y: 0.1)
      }
      animator.addCompletion { [unowned self] _ in
        self.composer.reset(animated: false)
        self.composer.transform = .identity
      }
      animator.startAnimation(afterDelay: 0.3)
    }
  }
}

extension TransactionViewController: GuillotineBladeUpdateDelegate {
  func didUpdate(bladeVC: UIViewController, infoProvider: GuillotineInfoProvider) {
    guard let transactionsListVC = bladeVC as? HistorySummaryViewController else { return }
    delegate = transactionsListVC.dataProvider
    guillotineInfoProvider = infoProvider
  }
}

extension TransactionViewController: CategorySelectionDelegate {
  func didSelect(category: TransactionCategory) {
    composer.set(category: category)
  }
}

extension TransactionViewController: GuilliotineSlideProgressDelegate {
  func didUpdateProgress(to progress: CGFloat) {
    let restrictedProgress = min(1, max(0, progress))
    let targetTransform = CGAffineTransform(translationX: 0, y: keyboardView.frame.height * restrictedProgress)
    for control in [keyboardView, categoryCollectionView, dateTimePicker, composer] {
      control?.transform = targetTransform
      control?.alpha = 1 - restrictedProgress
    }
    addButton.transform = targetTransform
    if composer.mode != .waitingForInput {
      addButton.alpha = 1 - restrictedProgress
    }
  }
  
  func willSwitch(toState bladeState: BladeState, withDuration duration: Double, andTimingProvider timing: UITimingCurveProvider) {
    let animator = UIViewPropertyAnimator(duration: duration, timingParameters: timing)
    let progress: CGFloat = bladeState == .collapsed ? 0 : 1
    animator.addAnimations { [unowned self] in
      self.didUpdateProgress(to: progress)
    }
    animator.startAnimation()
  }
}

extension TransactionViewController: TransactionComposerDelegate {
  func didSwitch(toMode mode: TransactionComposerMode, animated: Bool = false) {
    keyboardView.isHidden = mode != .amount && mode != .waitingForInput
    dateTimePicker.isHidden = mode != .date
    categoryCollectionView.isHidden = mode != .category
    
    let animation = { [unowned self] in
      let isHidden = mode == .waitingForInput
      self.addButton.alpha = isHidden ? 0 : 1
      self.addButton.transform = isHidden ? CGAffineTransform(translationX: 0, y: Animation.appearceWithShfit) : .identity
    }
    if animated {
      UIViewPropertyAnimator(duration: Animation.duration, curve: .easeOut, animations: animation).startAnimation()
    } else {
      animation()
    }
  }
  
  func amountChangedValidity(isValid amountIsValid: Bool) {
    addButton.isEnabled = amountIsValid
  }
}
