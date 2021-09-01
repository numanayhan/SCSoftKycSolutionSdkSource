import Foundation

public class SCSoftKycNFCInformation: Codable {
    
    var docType: Int?
    var personDetails:SCSoftKycPersonDetails?
    var additionalPersonDetails:SCSoftKycAdditionalPersonDetails?
    var mrzText : String?
    
    public init(){
        self.docType = -1
        self.personDetails = SCSoftKycPersonDetails()
        self.additionalPersonDetails = SCSoftKycAdditionalPersonDetails()
        mrzText = ""
    }
}
