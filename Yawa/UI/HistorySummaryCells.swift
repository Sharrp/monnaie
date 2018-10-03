//
//  TransactionCell.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/09.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class TransactionCell: UITableViewCell {
  @IBOutlet weak var emojiLabel: UILabel!
  @IBOutlet weak var categoryLabel: UILabel!
  @IBOutlet weak var authorLabel: UILabel!
  @IBOutlet weak var topMarginConstraint: NSLayoutConstraint!
  @IBOutlet var amountLabel: UILabel!
}

class SummaryCell: UITableViewCell {
  @IBOutlet weak var emojiLabel: UILabel!
  @IBOutlet weak var categoryLabel: UILabel!
  @IBOutlet weak var chartBarWidth: NSLayoutConstraint!
  @IBOutlet weak var valueLabel: UILabel! // amount or percentage
}
