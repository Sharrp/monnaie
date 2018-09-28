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
  @IBOutlet weak var amountInput: UITextField!
  
  private var inputFocused: Bool {
    return amountInput.isFirstResponder
  }
  private var inputHasValidContent: Bool {
    let value = (amountInput.text as NSString?)?.floatValue
    return value != nil && value! > 0
  }
  
  @IBOutlet weak var addButton: UIButton!
  @IBOutlet weak var dateButton: UIButton!
  @IBOutlet weak var inputFlowButton: UIButton!
  
  @IBOutlet weak var keyboardHeightConstraint: NSLayoutConstraint!
  @IBOutlet weak var keyboardView: DigitKeyboardView!
  
  @IBOutlet weak var dateButtonBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var inputFlowBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var addButtonBottomConstraint: NSLayoutConstraint!
  
  @IBOutlet weak var categoryCollectionView: UICollectionView!
  private let categoriesProvider = CategoriesProvider()
  private var userSetCategoryManually = false
  
  @IBOutlet weak var dateTimePicker: UIDatePicker!
  
  weak var delegate: TransactionUpdateDelegate?
  var transaction: Transaction?
  private var guillotineInfoProvider: GuillotineInfoProvider?
  
  enum EditingMode {
    case amount
    case date
    case category
  }
  
  private var editingMode = EditingMode.amount {
    didSet {
      dateTimePicker.isHidden = editingMode != .date
      categoryCollectionView.isHidden = editingMode != .category
      if editingMode == .amount {
        setFocusOnAmount()
      } else {
        removeFocusFromAmount()
      }
      updateCategoryButtonTitle()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: Notification.Name.UIApplicationDidBecomeActive, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(syncDidDismiss), name: .syncDidDismiss, object: nil)
    
    if let transaction = transaction {
      amountInput.text = formatMoney(amount: transaction.amount, currency: .JPY, symbolEnabled: false)
      selectCategory(atIndex: transaction.category.rawValue)
      dateTimePicker.date = transaction.date
      addButton.isEnabled = true
    }
    
    for button in [dateButton, inputFlowButton, addButton] {
      button!.layer.cornerRadius = 8
      button!.clipsToBounds = true
      button!.setBackgroundColor(color: UIColor(white: 0.4, alpha: 1.0), forState: .normal)
      button!.setBackgroundColor(color: UIColor(white: 0.7, alpha: 1.0), forState: .highlighted)
    }
    dateButton.titleLabel?.numberOfLines = 2
    dateButton.titleLabel?.textAlignment = .center
    
    keyboardView.delegate = self
    keyboardView.textField = amountInput
    keyboardView.heightContraint = keyboardHeightConstraint
    
    categoryCollectionView.dataSource = categoriesProvider
    categoryCollectionView.delegate = categoriesProvider
    categoriesProvider.delegate = self

    updateDateButton(forDate: Date())
    clearCategory()
    setFocusOnAmount()
    
    updateAppIconToSelectedOrLocaleCurrency()
  }
  
  @objc func appDidBecomeActive() {
    resetStateAfterBackground()
  }
  
  private func resetStateAfterBackground() {
    guard amountInput.text?.count == 0 else { return }
    resetDate()
    clearCategory()
    userSetCategoryManually = false
    
    if guillotineInfoProvider?.bladeState == .collapsed {
      setFocusOnAmount()
    }
  }
  
  @objc func syncDidDismiss() {
    if editingMode == .amount {
      setFocusOnAmount()
    }
  }
  
  // MARK: Amount
  
  private func clearAmount() {
    amountInput.text = ""
    addButton.isEnabled = false
  }
  
  @IBAction func amountTextChanged() {
    addButton.isEnabled = inputHasValidContent
    updateCategoryButtonTitle()
  }
  
  @IBAction func editingDidBegin() {
    editingMode = .amount
  }
  
  private func setFocusOnAmount() {
    amountInput.becomeFirstResponder()
    keyboardView.isHidden = false
  }
  
  private func removeFocusFromAmount() {
    amountInput.resignFirstResponder()
    keyboardView.isHidden = true
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
    inputFlowButton.setTitle("Category", for: .normal)
  }
  
  private func updateCategoryButtonTitle() {
    let title: String
    if !inputFocused && !inputHasValidContent {
      title = "Back to amount"
    } else if userSetCategoryManually {
      let category = categoriesProvider.selectedCategory
      title = "\(category.emoji) \(category.name)"
    } else if inputHasValidContent { // set default category
      let category = TransactionCategory.defaultCategory
      selectCategory(atIndex: category.rawValue)
      title = "\(category.emoji) \(category.name)"
    } else {
      title = "Category"
    }
    inputFlowButton.setTitle(title, for: .normal)
  }
  
  @IBAction func categoryTapped() {
    let mode: EditingMode = !inputFocused && !inputHasValidContent ? .amount : .category
    editingMode = mode
  }
  
  // MARK: Date & time
  
  private func updateDateButton(forDate date: Date) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM"
    let month = dateFormatter.string(from: date).uppercased()
    let dayOfMonth = Calendar.current.component(.day, from: date)
    
    let formattedTitle = NSMutableAttributedString(string: "\(dayOfMonth)\n\(month)")
    let font = UIFont.systemFont(ofSize: 11, weight: .regular)
    let range = NSRange(location: formattedTitle.length - 3, length: 3)
    formattedTitle.addAttribute(.font, value: font, range: range)
    dateButton.setAttributedTitle(formattedTitle, for: .normal)
  }
  
  private func resetDate() {
    let today = Date()
    dateTimePicker.date = today
    updateDateButton(forDate: today)
  }
  
  @IBAction func dateChanged(sender: UIDatePicker) {
    updateDateButton(forDate: sender.date)
  }
  
  @IBAction func dateTapped() {
    editingMode = .date
  }
  
  // MARK: Add transaction
  
  @IBAction func addTapped() {
    let amount = Float(amountInput.text ?? "0")!
    let category = categoriesProvider.selectedCategory
    
    if let transaction = transaction { // editing mode
      transaction.amount = amount
      transaction.category = category
      transaction.date = dateTimePicker.date
      transaction.modifiedDate = Date()
      delegate?.update(transaction: transaction)
    } else { // adding new transaction
      let transaction = Transaction(amount: amount, category: category, authorName: Settings.main.syncName, date: dateTimePicker.date)
      delegate?.add(transaction: transaction)
    }
    
    clearAmount()
    setFocusOnAmount()
  }
}

extension TransactionViewController: GuillotineBladeUpdateDelegate {
  func didUpdate(bladeVC: UIViewController, infoProvider: GuillotineInfoProvider) {
    guard let transactionsListVC = bladeVC as? HistorySummaryViewController else { return }
    delegate = transactionsListVC.dataProvider
    guillotineInfoProvider = infoProvider
  }
}

extension TransactionViewController: DigitKeyboardDelegate {
  func keyboardHeightChanged(to keyboardHeight: CGFloat) {
    // Say hello to iPhone X
    var bottomInset: CGFloat = 0
    if let safeAreBottomInset = UIApplication.shared.keyWindow?.safeAreaInsets.bottom {
      bottomInset = safeAreBottomInset
    }
    
    let bottomConstraint = keyboardHeight - bottomInset
    dateButtonBottomConstraint.constant = bottomConstraint
    inputFlowBottomConstraint.constant = bottomConstraint
    addButtonBottomConstraint.constant = bottomConstraint
  }
}

extension TransactionViewController {
  func updateAppIconToSelectedOrLocaleCurrency() {
    guard UIApplication.shared.supportsAlternateIcons else { return }
    guard !Settings.main.didChangeDefaultIcon else { return }
    guard let currencyCode = Locale.current.currencyCode else { return }
    
    var currenciesWithCustomIcons = [String]()
    if let bundleIcons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
      let alternateIcons = bundleIcons["CFBundleAlternateIcons"] as? [String: Any] {
      currenciesWithCustomIcons = [String](alternateIcons.keys)
    }
    guard currenciesWithCustomIcons.contains(currencyCode) else { return }
    
    // Doesn't work in viewDidLoad without a small delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [unowned self] in
      UIApplication.shared.setAlternateIconName(currencyCode) { (error) in
        if let error = error {
          print("\nICON ERROR: \(error)\n")
          Settings.main.didChangeDefaultIcon = false // sorry, but callback isn't called in case of success
          return
        }
      }
      Settings.main.didChangeDefaultIcon = true
      
      // Ugly hack to not show "You changed app icon" alert
      // We make a subtle change
      let tempViewController = UIViewController()
      self.present(tempViewController, animated: false, completion: {
        tempViewController.dismiss(animated: false) {
          self.amountInput.becomeFirstResponder() // show/dismissing controller removes focus from text field
        }
      })
    }
  }
}

extension TransactionViewController: CategorySelectionDelegate {
  func didSelect(category: TransactionCategory) {
    userSetCategoryManually = true
    updateCategoryButtonTitle()
  }
}
