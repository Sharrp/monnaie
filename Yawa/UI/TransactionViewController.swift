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
  
  private let gapToKeyboard: CGFloat = 8
  @IBOutlet weak var dateButtonBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var inputFlowBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var addButtonBottomConstraint: NSLayoutConstraint!
  private var keyboardWasOpenWhenDrawerOpened = false
  
  @IBOutlet weak var categoryPicker: UISegmentedControl!
  @IBOutlet weak var dateTimePicker: UIDatePicker!
  
  private var userSetCategoryManually = false
  
  weak var delegate: TransactionUpdateDelegate?
  var transaction: Transaction?
  
  enum EditingMode {
    case amount
    case date
    case category
  }
  
  private var editingMode = EditingMode.amount {
    didSet {
      dateTimePicker.isHidden = editingMode != .date
      categoryPicker.isHidden = editingMode != .category
      if editingMode == .amount {
        amountInput.becomeFirstResponder()
      } else {
        amountInput.resignFirstResponder()
      }
      updateCategoryButtonTitle()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: Notification.Name.UIApplicationDidBecomeActive, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(syncDidDismiss), name: .syncDidDismiss, object: nil)
    
    if let transaction = transaction {
      amountInput.text = formatMoney(amount: transaction.amount, currency: .JPY, symbolEnabled: false)
      categoryPicker.selectedSegmentIndex = transaction.category.rawValue
      dateTimePicker.date = transaction.date
      addButton.isEnabled = true
    }
    
    for button in [dateButton, inputFlowButton, addButton] {
      button!.layer.cornerRadius = 28
      button!.clipsToBounds = true
      button!.setBackgroundColor(color: UIColor(white: 0.4, alpha: 1.0), forState: .normal)
      button!.setBackgroundColor(color: UIColor(white: 0.7, alpha: 1.0), forState: .highlighted)
    }
    dateButton.titleLabel?.numberOfLines = 2
    dateButton.titleLabel?.textAlignment = .center

    updateDateButton(forDate: Date())
    clearCategory()
    amountInput.becomeFirstResponder()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    let transactionsListVC = self.pulleyViewController!.drawerContentViewController as! TransactionsListViewController
    delegate = transactionsListVC.dataProvider
  }
  
  @objc func appDidBecomeActive() {
    resetStateAfterBackground()
  }
  
  private func resetStateAfterBackground() {
    guard amountInput.text?.count == 0 else { return }
    resetDate()
    clearCategory()
    userSetCategoryManually = false
    
    if pulleyViewController?.drawerPosition == .open {
      amountInput.becomeFirstResponder()
    }
  }
  
  @objc func keyboardWillShow(_ notification: Notification) {
    if let info = notification.userInfo as? [String: AnyObject],
      let sizeValue = info[UIKeyboardFrameEndUserInfoKey] as? NSValue {
      let keyboardHeight = sizeValue.cgRectValue.size.height
      
      // Say hello to iPhone X
      var bottomInset: CGFloat = 0
      if let safeAreBottomInset = UIApplication.shared.keyWindow?.safeAreaInsets.bottom {
        bottomInset = safeAreBottomInset
      }
      let bottomConstraint = keyboardHeight + gapToKeyboard - bottomInset
      dateButtonBottomConstraint.constant = bottomConstraint
      inputFlowBottomConstraint.constant = bottomConstraint
      addButtonBottomConstraint.constant = bottomConstraint
    }
  }
  
  @objc func syncDidDismiss() {
    if editingMode == .amount {
      amountInput.becomeFirstResponder()
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
    updateCategoryButtonTitle()
  }
  
  // MARK: Category
  
  private func clearCategory() {
    categoryPicker.selectedSegmentIndex = UISegmentedControlNoSegment
    inputFlowButton.setTitle("Category", for: .normal)
  }
  
  private func updateCategoryButtonTitle() {
    let title: String
    if !inputFocused && !inputHasValidContent {
      title = "Back to amount"
    } else if userSetCategoryManually {
      let category = TransactionCategory(rawValue: categoryPicker.selectedSegmentIndex)!
      let name = categoryPicker.titleForSegment(at: categoryPicker.selectedSegmentIndex)!
      title = "\(category.emoji) \(name)"
    } else if inputHasValidContent { // set default category
      let category = TransactionCategory(rawValue: 0)!
      let name = categoryPicker.titleForSegment(at: 0)!
      title = "\(category.emoji) \(name)"
    } else {
      title = "Category"
    }
    inputFlowButton.setTitle(title, for: .normal)
  }
  
  @IBAction func categoryChanged(sender: UISegmentedControl) {
    userSetCategoryManually = true
    updateCategoryButtonTitle()
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
    let category = TransactionCategory(rawValue: categoryPicker.selectedSegmentIndex)!
    
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
    amountInput.becomeFirstResponder()
  }
}

extension TransactionViewController: PulleyPrimaryContentControllerDelegate {
  func didSwitchTo(drawerPosition: PulleyPosition) {
    switch drawerPosition {
    case .open:
      if keyboardWasOpenWhenDrawerOpened {
        amountInput.becomeFirstResponder()
      }
    case .collapsed:
      keyboardWasOpenWhenDrawerOpened = amountInput.isFirstResponder
      amountInput.resignFirstResponder()
    }
  }
}

