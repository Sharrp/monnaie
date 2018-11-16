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
  func isEmpty() -> Bool
}

protocol ManagedTransactionEditor {
  func startEditing(transaction: Transaction, byReplacingView: UIView)
}

class TransactionViewController: UIViewController {
  private enum Mode {
    case adding
    case editing
  }
  
  private var mode = Mode.adding
  @IBOutlet weak var blurView: UIVisualEffectView!
  @IBOutlet weak var commitButton: UIButton!
  @IBOutlet weak var composer: TransactionComponserView!
  private var composerTransformBeforeEditing = CGAffineTransform.identity
  private var composerTransformToMatchCell = CGAffineTransform.identity
  private weak var replacedView: UIView?
  private var editingTransaction: Transaction?
  
  @IBOutlet weak var navBarContainer: UIView!
  @IBOutlet weak var navigationBar: UINavigationBar!
  @IBOutlet weak var navBarCancel: UIBarButtonItem!
  private var isNavigationBarVisible: Bool {
    // FIX: should reflect real visibility through frame intersection
    return navBarContainer.transform == .identity
  }
  
  @IBOutlet weak var keyboardHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var keyboardView: DigitKeyboardView!
  
  @IBOutlet weak var categoryCollectionView: UICollectionView!
  private let categoriesProvider = CategoriesProvider()
  
  @IBOutlet weak var dateTimePicker: UIDatePicker!
  
  weak var delegate: TransactionUpdateDelegate?
  var transaction: Transaction?
  private var guillotine: GuillotineInfo?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(syncDidDismiss), name: .syncDidDismiss, object: nil)
    
    keyboardView.textField = composer.amountInput
    keyboardView.heightContraint = keyboardHeightConstraint
    
    categoryCollectionView.dataSource = categoriesProvider
    categoryCollectionView.delegate = categoriesProvider
    categoriesProvider.delegate = self
    clearCategory()
    
    dateTimePicker.setValue(UIColor(white: 0.6, alpha: 1), forKey: "textColor")

    composer.set(date: Date.now)
    composer.set(category: .defaultCategory)
    composer.set(mode: .waitingForInput, animated: false) // should be before delegate is set so callback is not called on launch
    composer.delegate = self
    
    blurView.effect = nil
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
    switch mode {
    case .adding:
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
    case .editing:
      editingTransaction?.amount = amount
      editingTransaction?.category = category
      editingTransaction?.date = dateTimePicker.date
      finishEditingAndCommit(transaction: editingTransaction!)
    }
  }
  
  @IBAction func cancelAdding() {
    composer.reset()
  }
  
  private func setNavigationBar(visible: Bool) {
    if isNavigationBarVisible == visible {
      return
    }
    
    if isNavigationBarVisible {
      navBarContainer.transform = CGAffineTransform(translationX: 0, y: -navBarContainer.frame.height)
    } else {
      navBarContainer.transform = .identity
    }
  }
  
  private func adjustControls(toMode mode: TransactionComposerMode, animated: Bool) {
    keyboardView.isHidden = mode != .amount && mode != .waitingForInput
    dateTimePicker.isHidden = mode != .date
    categoryCollectionView.isHidden = mode != .category
    
    let hasNoTransactions = delegate?.isEmpty() ?? true
    let bladeHidden = hasNoTransactions || mode != .waitingForInput
    let addHidden = mode == .waitingForInput
    
    let animation = { [unowned self] in
      self.commitButton.alpha = addHidden ? 0 : 1
      self.commitButton.transform = addHidden ? CGAffineTransform(translationX: 0, y: Animation.appearceWithShfit) : .identity
      self.setNavigationBar(visible: !addHidden)
      
      if self.mode == .adding {
        self.guillotine?.setBlade(hidden: bladeHidden, animated: animated)
      }
    }
    if animated {
      UIViewPropertyAnimator(duration: Animation.duration, curve: .easeOut, animations: animation).startAnimation()
    } else {
      animation()
    }
  }
}

extension TransactionViewController: GuillotineDelegate {
  func finishedSetup(ofGuillotine guillotineInfo: GuillotineInfo) {
    guillotine = guillotineInfo
    guard let historySummaryVC = guillotine?.bladeViewController as? HistorySummaryViewController else { return }
    delegate = historySummaryVC.dataProvider
    historySummaryVC.editor = self
    
    // Now we have guillotine required to set proper blade state
    adjustControls(toMode: .waitingForInput, animated: false)
  }
}

extension TransactionViewController: CategorySelectionDelegate {
  func didSelect(category: TransactionCategory) {
    composer.set(category: category)
  }
}

extension TransactionViewController: GuilliotineStateDelegate {
  func didUpdateProgress(to progress: CGFloat) {
    let restrictedProgress = min(1, max(0, progress))
    let targetTransform = CGAffineTransform(translationX: 0, y: keyboardView.frame.height * restrictedProgress)
    for control in [keyboardView, categoryCollectionView, dateTimePicker, composer] {
      control?.transform = targetTransform
      control?.alpha = 1 - restrictedProgress
    }
    commitButton.transform = targetTransform
    if composer.mode != .waitingForInput {
      commitButton.alpha = 1 - restrictedProgress
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
    adjustControls(toMode: mode, animated: true)
  }
  
  func amountChangedValidity(isValid amountIsValid: Bool) {
    commitButton.isEnabled = amountIsValid
  }
}

extension TransactionViewController: ManagedTransactionEditor {
  private func setNavBarCancel(hidden: Bool) {
    navBarCancel.tintColor = hidden ? .clear : nil
    navBarCancel.isEnabled = !hidden
  }
  
  func startEditing(transaction: Transaction, byReplacingView viewToReplace: UIView) {
    guard let viewToReplaceSuperview = viewToReplace.superview else { return }
    replacedView = viewToReplace
    replacedView?.isHidden = true
    editingTransaction = transaction
    
    mode = .editing
    guillotine?.bringBaseToFront()
    
    let newPosition = viewToReplaceSuperview.convert(viewToReplace.frame.origin, to: nil)
    composerTransformBeforeEditing = composer.transform
    composer.transform = .identity // to properly calculate transform to match cell
    let currentPosition = view.convert(composer.frame.origin, to: nil)
    composerTransformToMatchCell = CGAffineTransform(translationX: 0, y: newPosition.y - currentPosition.y - composer.padding)
    composer.transform = composerTransformToMatchCell
    
    composer.alpha = 1
    composer.set(mode: .table, animated: false, disableDelegation: true)
    composer.display(transaction: transaction)
    dateTimePicker.date = transaction.date
    categoriesProvider.selectedCategory = transaction.category
    
    navigationBar.topItem?.title = "Editing"
    setNavBarCancel(hidden: true)
    commitButton.setTitle("Save", for: .normal)
    commitButton.isEnabled = true
    
    UIViewPropertyAnimator(duration: Animation.duration, curve: .easeOut) { [unowned self] in
      self.blurView.effect = UIBlurEffect(style: .light)
      self.setNavigationBar(visible: true)
    }.startAnimation()
    
    let timingProvider = UISpringTimingParameters(dampingRatio: Animation.dampingRatio)
    willSwitch(toState: .collapsed, withDuration: 2*Animation.duration, andTimingProvider: timingProvider)
    composer.set(mode: .amount, animated: true, disableDelegation: true)
  }
  
  private func finishEditingAndCommit(transaction: Transaction) {
    let animator = UIViewPropertyAnimator(duration: Animation.duration, curve: .easeInOut) { [unowned self] in
      self.blurView.effect = nil
      self.setNavigationBar(visible: false)
      self.composer.transform = self.composerTransformToMatchCell
    }
    animator.addCompletion { [unowned self] _ in
      self.composer.reset()
      self.composer.transform = self.composerTransformBeforeEditing
      self.commitButton.isEnabled = false
      self.commitButton.setTitle("Add", for: .normal)
      self.navigationBar.topItem?.title = "Adding"
      self.replacedView?.isHidden = false
      self.guillotine?.sendBaseToBack()
      self.didUpdateProgress(to: 1)
      
      self.delegate?.update(transaction: transaction)
    }
    animator.startAnimation()
    composer.set(mode: .table, animated: true, disableDelegation: true)
    
    mode = .adding
  }
}
