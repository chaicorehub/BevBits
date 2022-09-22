//
//  StyledButton.swift
//  Nudge
//
//  Created by Shayne Guiliano on 9/11/17.
//  Copyright © 2017 Shayne Guiliano. All rights reserved.
//

import UIKit

class StyledButton: UIButton {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    override func awakeFromNib() {
        super.awakeFromNib()
        layer.borderColor = UIColor(red: 51.0/255.0, green: 123.0/255.0, blue: 246.0/255.0, alpha: 1).cgColor
        layer.borderWidth = 1.5
        layer.cornerRadius = frame.size.height/2
        layer.shadowOffset = CGSize(width: 2, height: 2)
        layer.shadowColor = UIColor.black.cgColor
    }
}
