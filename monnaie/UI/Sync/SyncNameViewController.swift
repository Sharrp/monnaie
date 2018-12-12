//
//  SyncNameViewController.swift
//  monnaie
//
//  Created by Anton Vronskii on 2018/05/15.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

protocol SyncNameUpdateDelegate: AnyObject {
  func nameUpdated(to name: String)
}

class SyncNameViewController: UIViewController {
  @IBOutlet weak var nameTextField: UITextField!
  @IBOutlet weak var saveButton: UIButton!
  weak var delegate: SyncNameUpdateDelegate?
  var currentName: String?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    nameTextField.text = currentName ?? ""
    nameTextField.becomeFirstResponder()
  }
  
  private func dismiss() {
    nameTextField.resignFirstResponder()
    navigationController?.popViewController(animated: true)
  }
  
  @IBAction func savePressed() {
    if let newName = nameTextField.text {
      delegate?.nameUpdated(to: newName)
    }
    dismiss()
  }
  
  @IBAction func cancelPressed() {
    dismiss()
  }
  
  @IBAction func nameEditingChanged(textField: UITextField) {
    if let newName = textField.text,
      newName.count > 0 {
      saveButton.isEnabled = true
    } else {
      saveButton.isEnabled = false
    }
  }
}
