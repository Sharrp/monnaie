//
//  TransactionCell.swift
//  Yawa
//
//  Created by Anton Vronskii on 2018/05/09.
//  Copyright © 2018 Anton Vronskii. All rights reserved.
//

import UIKit

class TransactionCell: UITableViewCell {
  @IBOutlet var amountLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
    } 

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
