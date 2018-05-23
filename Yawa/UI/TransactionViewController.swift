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

class TransactionViewController: CardViewController {
  @IBOutlet weak var amountTextField: UITextField!
  @IBOutlet weak var saveButton: UIButton!
  @IBOutlet weak var categoryPicker: UISegmentedControl!
  @IBOutlet weak var dateTimePicker: UIDatePicker!
  @IBOutlet weak var commentTextField: UITextField!
  
  weak var delegate: TransactionUpdateDelegate?
  var transaction: Transaction?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    if let transaction = transaction {
      amountTextField.text = formatMoney(amount: transaction.amount, currency: .JPY, symbolEnabled: false)
      categoryPicker.selectedSegmentIndex = transaction.category.rawValue
      dateTimePicker.date = transaction.date
      commentTextField.text = transaction.comment
      saveButton.isEnabled = true
    }

    amountTextField.becomeFirstResponder()
  }

  @IBAction func cancel() {
    amountTextField.resignFirstResponder()
    self.dismiss(animated: true, completion: nil)
  }
  
  @IBAction func save() {
    let amount = Float(amountTextField.text ?? "0")!
    let category = TransactionCategory(rawValue: categoryPicker.selectedSegmentIndex)!
    
    if let transaction = transaction { // editing mode
      transaction.amount = amount
      transaction.category = category
      transaction.comment = commentTextField.text
      transaction.date = dateTimePicker.date
      transaction.modifiedDate = Date()
      delegate?.update(transaction: transaction)
    } else { // adding new transaction
      let transaction = Transaction(amount: amount, category: category, author: Settings.main.syncName, date: dateTimePicker.date, comment: commentTextField.text)
      delegate?.add(transaction: transaction)
    }
    self.dismiss(animated: true, completion: nil)
  }
  
  @IBAction func amountTextChanged() {
    let value = (amountTextField.text as NSString?)?.floatValue
    saveButton.isEnabled = value != nil && value! > 0
  }
}
