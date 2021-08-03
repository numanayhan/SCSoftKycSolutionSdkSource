//
//  ScanView.swift
//  SCSoftKycSolutionSdk
//
//  Created by samiozakyol on 28.07.2021.
//

import UIKit

class ScanView: UIView {

    public func shape() {
        self.backgroundColor = UIColor.clear
        self.layer.masksToBounds = true
        self.layer.cornerRadius = 5.0
        self.layer.borderWidth = 3.0
        self.layer.borderColor = UIColor.white.cgColor
    }
}
