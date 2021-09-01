import Foundation

public class SCSoftKycAdditionalPersonDetails: Codable {
    var custodyInformation:String?
    var fullDateOfBirth:String?
    var nameOfHolder:String?
    var otherNames:[String]?
    var otherValidTDNumbers:[String]?
    var permanentAddress:[String]?
    var personalNumber:String?
    var personalSummary:String?
    var placeOfBirth:[String]?
    var profession:String?
    var proofOfCitizenship:String?
    var tag:String?
    var tagPresenceList:[String]?
    var telephone:String?
    var title:String?
    
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
