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
  @IBOutlet weak var inputFlowBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var addButtonBottomConstraint: NSLayoutConstraint!
  private var keyboardWasOpenWHenDrawerOpened = false
  
  @IBOutlet weak var categoryPicker: UISegmentedControl!
  @IBOutlet weak var dateTimePicker: UIDatePicker!
  
  weak var delegate: TransactionUpdateDelegate?
  var transaction: Transaction?
  
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
    
    for button in [inputFlowButton, addButton, dateButton] {
      button!.layer.cornerRadius = 28
      if button == dateButton {
        button?.layer.cornerRadius = 20
      }
      button!.clipsToBounds = true
      button!.setBackgroundColor(color: UIColor(white: 0.4, alpha: 1.0), forState: .normal)
      button!.setBackgroundColor(color: UIColor(white: 0.7, alpha: 1.0), forState: .highlighted)
    }

    resetCategory()
    amountTextField.becomeFirstResponder()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    let transactionsListVC = self.pulleyViewController!.drawerContentViewController as! TransactionsListViewController
    delegate = transactionsListVC.dataProvider
  }
  
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
  
  @objc func appDidBecomeActive() {
    resetStateAfterBackground()
  }
  
  private func resetStateAfterBackground() {
    guard amountTextField.text?.count == 0 else { return }
    dateTimePicker.date = Date()
    resetCategory()
    
    if pulleyViewController?.drawerPosition == .open {
      amountTextField.becomeFirstResponder()
    }
  }
  
  private func clearAmount() {
    amountTextField.text = ""
    addButton.isEnabled = false
  }
  
  private func resetCategory() {
    let defaultCategory = categoryPicker.titleForSegment(at: 0)!
    categoryPicker.selectedSegmentIndex = 0
    inputFlowButton.setTitle(defaultCategory, for: .normal)
  }
  
  @objc func keyboardWillShow(_ notification: Notification) {
    if let info = notification.userInfo as? [String: AnyObject],
      let sizeValue = info[UIKeyboardFrameEndUserInfoKey] as? NSValue {
      let keyboardHeight = sizeValue.cgRectValue.size.height
      
      // Say hello to iPhone X
      var bottomInset: CGFloat = 0
      if #available(iOS 11.0, *) {
        if let safeAreBottomInset = UIApplication.shared.keyWindow?.safeAreaInsets.bottom {
          bottomInset = safeAreBottomInset
        }
      }
      inputFlowBottomConstraint.constant = keyboardHeight + gapToKeyboard - bottomInset
      addButtonBottomConstraint.constant = keyboardHeight + gapToKeyboard - bottomInset
    }
  }
  
  enum EditingMode {
    case Amount
    case Date
    case Category
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
  
  @IBAction func dateTapped() {
    switchTo(editingMode: .Date)
  }
  
  @IBAction func dateChanged(sender: UIDatePicker) {
    if Calendar.current.isDate(sender.date, inSameDayAs: Date()) {
      dateButton.setTitle("Today", for: .normal)
    } else {
      let dateFormatter = DateFormatter()
      dateFormatter.dateStyle = .short
      dateFormatter.timeStyle = .none
      let title = dateFormatter.string(from: sender.date)
      dateButton.setTitle(title, for: .normal)
    }
  }
  
  @IBAction func categoryChanged(sender: UISegmentedControl) {
    guard let selectedCategoryName = sender.titleForSegment(at: sender.selectedSegmentIndex) else { return }
    inputFlowButton.setTitle(selectedCategoryName, for: .normal)
  }
  
  @IBAction func categoryTapped() {
    switchTo(editingMode: .Category)
  }
  
  @IBAction func amountTextChanged() {
    let value = (amountTextField.text as NSString?)?.floatValue
    addButton.isEnabled = value != nil && value! > 0
  }
}

extension TransactionViewController: PulleyPrimaryContentControllerDelegate {
  func didSwitchTo(drawerPosition: PulleyPosition) {
    switch drawerPosition {
    case .open:
      if keyboardWasOpenWHenDrawerOpened {
        amountTextField.becomeFirstResponder()
      }
    case .collapsed:
      keyboardWasOpenWHenDrawerOpened = amountTextField.isFirstResponder
      amountTextField.resignFirstResponder()
    }
  }
  
  func drawerChangedDistanceFromBottom(drawer: PulleyViewController, distance: CGFloat, bottomSafeArea: CGFloat) {
    print("TO BOTTOM: \(distance)")
  }
}

