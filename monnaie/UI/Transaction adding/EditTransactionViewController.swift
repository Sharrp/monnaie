//
//  EditTransactionViewController.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol TransactionEditorDelegate: AnyObject {
  func didSwitch(toMode: TransactionComposerMode)
  func commit(amount: Double, category: TransactionCategory, date: Date)
}

class EditTransactionViewController: UIViewController {
  private enum Mode {
    case adding
    case editing
  }
  
  private var mode = Mode.adding
  @IBOutlet weak var blurView: UIVisualEffectView!
  @IBOutlet weak var commitButton: UIButton!
  @IBOutlet weak var composer: TransactionComponserView!
  
  @IBOutlet weak var keyboardHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var keyboardView: DigitKeyboardView!
  
  @IBOutlet weak var categoryCollectionView: UICollectionView!
  private let categoriesProvider = CategoriesProvider()
  
  @IBOutlet weak var dateTimePicker: UIDatePicker!
  
  weak var delegate: TransactionEditorDelegate?
  weak var settings: Settings? {
    didSet {
      currencyChanged()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
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
  
  lazy var bladeScroll: GuillotineScrollCallback? = { [weak self] progress in
    let restrictedProgress = min(1, max(0, progress))
    self?.hideControls(withProgress: restrictedProgress)
  }
  
  lazy var bladeStateSwitch: GuillotineBladeStateCallback? = { bladeState in
    let progress: CGFloat = bladeState == .collapsed ? 0 : 1
    let animator = UIViewPropertyAnimator(duration: Animation.duration, timingParameters: Animation.springTiming)
    animator.addAnimations { [weak self] in
      self?.bladeScroll?(progress)
    }
    animator.startAnimation()
  }
  
  lazy var currencyChanged: SettingUpdateCallback = { [weak self] in
    guard let currency = self?.settings?.userCurrency else { return }
    self?.composer.currency = currency
    self?.keyboardView.dotAvailable = currency.decimalsAllowed
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
  
  func set(category: TransactionCategory) {
    selectCategory(atIndex: category.rawValue)
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
  
  func set(date: Date) {
    dateTimePicker.date = date
  }
  
  // MARK: Add transaction
  
  func setCommitButton(enabled: Bool) {
    commitButton.isEnabled = enabled
  }
  
  func setCommitButton(title: String) {
    commitButton.setTitle(title, for: .normal)
  }
  
  @IBAction func commitTapped() {
    guard let amount = composer.amount else { return }
    let category = categoriesProvider.selectedCategory
    delegate?.commit(amount: amount, category: category, date: dateTimePicker.date)
  }

  func animateComposerFlyAway() {
    composer.set(mode: .table, animated: true)
    adjustControls(toMode: .waitingForInput, animated: false)
    let yShiftFlyAway = -(composer.frame.maxY + 30)
    let animator = UIViewPropertyAnimator(duration: Animation.duration, curve: Animation.curve) { [weak self] in
      self?.composer.transform = CGAffineTransform(translationX: 0, y: yShiftFlyAway).scaledBy(x: 0.1, y: 0.1)
    }
    animator.addCompletion { [weak self] _ in
      self?.composer.reset(animated: false)
      self?.composer.transform = .identity
    }
    animator.startAnimation(afterDelay: 0.3)
  }
  
  func switchTo(mode: TransactionComposerMode, animated: Bool) {
    // Only internal changes should trigger delegate calls so delegationEnabled = false
    adjustControls(toMode: mode, animated: animated)
    composer.set(mode: mode, animated: animated)
  }
  
  func hideControls(withProgress progress: CGFloat, includingComposer: Bool = true) {
    var controls = [keyboardView, categoryCollectionView, dateTimePicker]
    if includingComposer {
      controls.append(composer)
    }
    let targetTransform = CGAffineTransform(translationX: 0, y: keyboardView.frame.height * progress)
    for control in controls {
      control?.transform = targetTransform
      control?.alpha = 1 - progress
    }
    commitButton.transform = targetTransform
    if composer.mode != .waitingForInput {
      commitButton.alpha = 1 - progress
    }
  }
  
  private func adjustControls(toMode mode: TransactionComposerMode, animated: Bool, delegationEnabled: Bool = false) {
    keyboardView.backspaceEnabled = mode != .waitingForInput
    keyboardView.isHidden = mode == .date || mode == .category
    dateTimePicker.isHidden = mode != .date
    categoryCollectionView.isHidden = mode != .category
    
    let addHidden = mode == .waitingForInput
    let animation = { [weak self] in
      self?.commitButton.alpha = addHidden ? 0 : 1
      self?.commitButton.transform = addHidden ? CGAffineTransform(translationX: 0, y: Animation.appearceWithShfit) : .identity
    }
    if animated {
      UIViewPropertyAnimator(duration: Animation.duration, curve: Animation.curve, animations: animation).startAnimation()
    } else {
      animation()
    }
    
    if delegationEnabled {
      delegate?.didSwitch(toMode: mode)
    }
  }
}

extension EditTransactionViewController: CategorySelectionDelegate {
  func didSelect(category: TransactionCategory) {
    composer.set(category: category)
  }
}

extension EditTransactionViewController: TransactionComposerDelegate {
  func didSwitch(toMode mode: TransactionComposerMode, animated: Bool = false) {
    adjustControls(toMode: mode, animated: true, delegationEnabled: true)
  }
  
  func amountChangedValidity(isValid amountIsValid: Bool) {
    commitButton.isEnabled = amountIsValid
  }
  
  func setDateToToday() {
    dateTimePicker.setDate(Date.now, animated: true)
  }
}
