import Foundation

public class SCSoftKycMRZInformation: Codable {
    
    var documentNumber: String?
    var expiryDate:String?
    var birthDate:String?
    var documentType:String?
    var countryCode:String?
    var surnames:String?
    var givenNames:String?
    var nationality:String?
    var gender:String?
    var personalNumber:String?
    var personalNumber2:String?
    
    public init(){
        self.documentNumber = ""
        self.expiryDate = ""
        self.birthDate = ""
        self.documentType = ""
        self.countryCode = ""
        self.surnames = ""
        self.givenNames = ""
        self.nationality = ""
        self.gender = ""
        self.personalNumber = ""
        self.personalNumber2 = ""
        
    }
}
