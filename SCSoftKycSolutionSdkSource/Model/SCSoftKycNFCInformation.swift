import Foundation

public class SCSoftKycNFCInformation: Codable {
    
    public var docType: Int?
    public var personDetails:SCSoftKycPersonDetails?
    public var additionalPersonDetails:SCSoftKycAdditionalPersonDetails?
    public var mrzText : String?
    public var certificateBase64 : String?
    
    public init(){
        self.docType = -1
        self.personDetails = SCSoftKycPersonDetails()
        self.additionalPersonDetails = SCSoftKycAdditionalPersonDetails()
        self.mrzText = ""
        self.certificateBase64 = ""
    }
}
