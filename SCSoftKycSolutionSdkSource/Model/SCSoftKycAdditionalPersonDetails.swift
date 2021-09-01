import Foundation

public class SCSoftKycAdditionalPersonDetails: Codable {
    public var custodyInformation:String?
    public var fullDateOfBirth:String?
    public var nameOfHolder:String?
    public var otherNames:[String]?
    public var otherValidTDNumbers:[String]?
    public var permanentAddress:[String]?
    public var personalNumber:String?
    public var personalSummary:String?
    public var placeOfBirth:[String]?
    public var profession:String?
    public var proofOfCitizenship:String?
    public var tag:String?
    public var tagPresenceList:[String]?
    public var telephone:String?
    public var title:String?
    
    public init(){
        self.custodyInformation = ""
        self.fullDateOfBirth = ""
        self.nameOfHolder = ""
        self.otherNames = [""]
        self.otherValidTDNumbers = [""]
        self.permanentAddress = [""]
        self.personalNumber = ""
        self.personalSummary = ""
        self.placeOfBirth = [""]
        self.profession = ""
        self.proofOfCitizenship = ""
        self.tag = ""
        self.tagPresenceList = [""]
        self.telephone = ""
        self.title = ""
    }
}
