//
//  StatementLabel.swift
//  SCSoftKycSolutionSdk
//
//  Created by samiozakyol on 28.07.2021.
//

import UIKit

class StatementLabel: UILabel {

    public func shape(_ txt: String, font: UIFont) {
        self.adjustsFontSizeToFitWidth = false
        self.font = font
        self.text = txt
        self.textColor = UIColor.white
        self.textAlignment = .center
    }

}
