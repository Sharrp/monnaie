//
//  AddTransactionViewController.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/03.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol TransactionAdditionDelegate {
  func add(transaction: Transaction)
}

class AddTransactionViewController: UIViewController {
  @IBOutlet var amountTextField: UITextField!
  @IBOutlet var saveButton: UIBarButtonItem!
  @IBOutlet var categoryPicker: UISegmentedControl!
  @IBOutlet var dateTimePicker: UIDatePicker!
  @IBOutlet var commentTextField: UITextField!
  var delegate: TransactionAdditionDelegate?
  
  override func viewDidLoad() {
    super.viewDidLoad()

    amountTextField.becomeFirstResponder()
  }

  @IBAction func cancel() {
    amountTextField.resignFirstResponder()
    self.dismiss(animated: true, completion: nil)
  }
  
  @IBAction func save() {
    let amount = Float(amountTextField.text ?? "0")!
    let category = TransactionCategory(rawValue: categoryPicker.selectedSegmentIndex)!
    let transaction = Transaction(amount: amount, category: category, author: UIDevice.current.name, date: dateTimePicker.date, comment: commentTextField.text)
    delegate?.add(transaction: transaction)
    self.dismiss(animated: true, completion: nil)
  }
  
  @IBAction func amountTextChanged() {
    let value = (amountTextField.text as NSString?)?.floatValue
    saveButton.isEnabled = value != nil && value! > 0
  }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
