import Foundation

public class SCSoftKycMRZInformation: Codable {
    
    public var documentNumber: String?
    public var expiryDate:String?
    public var birthDate:String?
    public var documentType:String?
    public var countryCode:String?
    public var surnames:String?
    public var givenNames:String?
    public var nationality:String?
    public var gender:String?
    public var personalNumber:String?
    public var personalNumber2:String?
    
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
