//
//  RoundedButton.swift
//  SCSoftKycSolutionSdk
//
//  Created by samiozakyol on 28.07.2021.
//

import UIKit

class RoundedButton: UIButton {

    override func awakeFromNib() {
        super.awakeFromNib()
        
        shapeButton()
    }

    private func shapeButton() {
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 15.0
    }
}
