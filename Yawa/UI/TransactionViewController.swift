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
  @IBOutlet weak var amountTextField: UITextField!
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
    case Amount
    case Date
    case Category
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: Notification.Name.UIApplicationDidBecomeActive, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
    
    if let transaction = transaction {
      amountTextField.text = formatMoney(amount: transaction.amount, currency: .JPY, symbolEnabled: false)
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
    amountTextField.becomeFirstResponder()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    let transactionsListVC = self.pulleyViewController!.drawerContentViewController as! TransactionsListViewController
    delegate = transactionsListVC.dataProvider
  }
  
  @objc func appDidBecomeActive() {
    resetStateAfterBackground()
  }
  
  private func resetStateAfterBackground() {
    guard amountTextField.text?.count == 0 else { return }
    resetDate()
    clearCategory()
    userSetCategoryManually = false
    
    if pulleyViewController?.drawerPosition == .open {
      amountTextField.becomeFirstResponder()
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
  
  private func switchTo(editingMode: EditingMode) {
    dateTimePicker.isHidden = editingMode != .Date
    categoryPicker.isHidden = editingMode != .Category
    if editingMode == .Amount {
      amountTextField.becomeFirstResponder()
    } else {
      amountTextField.resignFirstResponder()
    }
  }
  
  // MARK: Amount
  
  private func clearAmount() {
    amountTextField.text = ""
    addButton.isEnabled = false
  }
  
  @IBAction func amountTextChanged() {
    let value = (amountTextField.text as NSString?)?.floatValue
    let hasValidValue = value != nil && value! > 0
    addButton.isEnabled = hasValidValue
    if !userSetCategoryManually {
      if hasValidValue {
        setDefaultCategory()
      } else {
        clearCategory()
      }
    }
  }
  
  // MARK: Category
  
  private func clearCategory() {
    categoryPicker.selectedSegmentIndex = UISegmentedControlNoSegment
    inputFlowButton.setTitle("Category", for: .normal)
  }
  
  private func setDefaultCategory() {
    let defaultCategory = categoryPicker.titleForSegment(at: 0)!
    categoryPicker.selectedSegmentIndex = 0
    inputFlowButton.setTitle(defaultCategory, for: .normal)
  }
  
  @IBAction func categoryChanged(sender: UISegmentedControl) {
    guard let selectedCategoryName = sender.titleForSegment(at: sender.selectedSegmentIndex) else { return }
    inputFlowButton.setTitle(selectedCategoryName, for: .normal)
    userSetCategoryManually = true
  }
  
  @IBAction func categoryTapped() {
    switchTo(editingMode: .Category)
  }
  
  // MARK: Date & time
  
  private func updateDateButton(forDate date: Date) {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "MMM"
    let month = dateFormatter.string(from: date).uppercased()
    let dayOfMonth = Calendar.current.component(.day, from: date)
    
    let formattedTitle = NSMutableAttributedString(string: "\(dayOfMonth)\n\(month)")
    let font = UIFont.systemFont(ofSize: 11, weight: .medium)
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
    switchTo(editingMode: .Date)
  }
  
  // MARK: Add transaction
  
  @IBAction func addTapped() {
    let amount = Float(amountTextField.text ?? "0")!
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
    amountTextField.becomeFirstResponder()
  }
}

extension TransactionViewController: PulleyPrimaryContentControllerDelegate {
  func didSwitchTo(drawerPosition: PulleyPosition) {
    switch drawerPosition {
    case .open:
      if keyboardWasOpenWhenDrawerOpened {
        amountTextField.becomeFirstResponder()
      }
    case .collapsed:
      keyboardWasOpenWhenDrawerOpened = amountTextField.isFirstResponder
      amountTextField.resignFirstResponder()
    }
  }
}

