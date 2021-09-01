import Foundation

public class SCSoftKycPersonDetails: Codable {
    var name:String?
    var surname:String?
    var personalNumber:String?
    var gender:String?
    var birthDate:String?
    var expiryDate:String?
    var serialNumber:String?
    var nationality:String?
    var issuerAuthority:String?
    var faceImageBase64:String?
    var portraitImageBase64:String?
    var signatureBase64:String?
    var fingerPrints:[String]?
    
    
    public init(){
        self.name = ""
        self.surname = ""
        self.personalNumber = ""
        self.gender = ""
        self.birthDate = ""
        self.expiryDate = ""
        self.serialNumber = ""
        self.nationality = ""
        self.issuerAuthority = ""
        self.faceImageBase64 = ""
        self.portraitImageBase64 = ""
        self.signatureBase64 = ""
        self.fingerPrints = [""]
    }
}
