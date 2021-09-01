import Foundation

public class SCSoftKycPersonDetails: Codable {
    public var name:String?
    public var surname:String?
    public var personalNumber:String?
    public var gender:String?
    public var birthDate:String?
    public var expiryDate:String?
    public var serialNumber:String?
    public var nationality:String?
    public var issuerAuthority:String?
    public var faceImageBase64:String?
    public var portraitImageBase64:String?
    public var signatureBase64:String?
    public var fingerPrints:[String]?
    
    
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
