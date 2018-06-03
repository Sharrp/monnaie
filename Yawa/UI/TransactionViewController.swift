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
  @IBOutlet weak var categoryButton: UIButton!
  
  @IBOutlet weak var categoryPicker: UISegmentedControl!
  @IBOutlet weak var dateTimePicker: UIDatePicker!
  
  weak var delegate: TransactionUpdateDelegate?
  var transaction: Transaction?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let transaction = transaction {
      amountTextField.text = formatMoney(amount: transaction.amount, currency: .JPY, symbolEnabled: false)
      categoryPicker.selectedSegmentIndex = transaction.category.rawValue
      dateTimePicker.date = transaction.date
      addButton.isEnabled = true
    }

    amountTextField.becomeFirstResponder()
    let defaultCategory = categoryPicker.titleForSegment(at: 0)!
    categoryButton.setTitle(defaultCategory, for: .normal)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    let vc = self.pulleyViewController!.drawerContentViewController as! ViewController
    delegate = vc.dataProvider
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
  }
  
  private func clearAmount() {
    amountTextField.text = ""
    addButton.isEnabled = false
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
    categoryButton.setTitle(selectedCategoryName, for: .normal)
  }
  
  @IBAction func categoryTapped() {
    switchTo(editingMode: .Category)
  }
  
  @IBAction func amountTextChanged() {
    let value = (amountTextField.text as NSString?)?.floatValue
    addButton.isEnabled = value != nil && value! > 0
  }
}
