//
//  IDCardModel.swift
//  SCSoftKycSolutionSdk
//
//  Created by samiozakyol on 28.07.2021.
//

import Foundation
import UIKit

struct IDCardModel {
    
    var documentImage: UIImage = UIImage()
    var documentType: String = ""
    var countryCode: String = ""
    var surnames: String = ""
    var givenNames: String = ""
    var documentNumber: String = ""
    var nationality: String = ""
    var birthDate: Date? = Date()
    var gender: String = ""
    var expiryDate: Date? = Date()
    var personalNumber: String = ""
    
    
    init(documentNumber: String, birthDate: Date, expiryDate: Date) {
        self.documentNumber = documentNumber
        self.birthDate = birthDate
        self.expiryDate = expiryDate
    }
    
}
