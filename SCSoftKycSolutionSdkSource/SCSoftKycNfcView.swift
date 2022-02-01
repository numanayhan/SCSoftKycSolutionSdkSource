import Foundation
import UIKit
import CoreNFC

@available(iOS 13, *)
public protocol SCSoftKycNfcViewDelegate: AnyObject {
    
    func didReadNfc(_ kycNfcView : SCSoftKycNfcView , didRead nfcInformation : SCSoftKycNFCInformation)
    
    func didClose(_ kycNfcView: SCSoftKycNfcView)
    
    func getNfcAvailable(_ kycNfcView: SCSoftKycNfcView, hasNfc : Bool)
    
}

@available(iOS 13, *)
@IBDesignable
public class SCSoftKycNfcView: UIView {
    
    // Public variables
    
    public var nfcErrorLimit = 3
    public var buttonBackgroundColor = UIColor(red: 27.0 / 255.0, green: 170.0 / 255.0, blue: 194.0 / 255.0, alpha: 1.0)
    public var buttonTitleColor = UIColor.white
    public var buttonFont = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
    public var buttonRadius : CGFloat = 8
    
    public var labelTextColor = UIColor.white
    public var labelFont = UIFont.boldSystemFont(ofSize: 16)
    
    public var nfcRequestText = "IPhone'unuzu NFC özellikli bir Kimlik Kartının yakınında tutun."
    public var nfcSuccessfulText = "Kimlik Kartı Başarıyla okundu."
    public var nfcReadingDataGroupText = "Yükleniyor lütfen bekleyiniz...\n"
    public var nfcAuthenticatingWithPassportText = "Kimlik kartı doğrulama.....\n"
    public var noMrzDataText = "Kimlik mrz bilgisi bulunamamıştır veya hatalı gönderilmiştir."
    public var nfcErrorText = "Kimlik bilgileri okunurken hata oluştu. Lütfen kimlik kartınızı telefonunuza yaklaştırarak tekrar deneyiniz."
    public var infoNfcText = "Kimlik kartınızı telefonun arka üst kısmına yaklaştırın ve Tara butonuna basın."
    public var infoNoNfcText = "Cihazınızda Nfc desteği bulunmamaktadır."
    public var buttonNfcText = "Tara"
    public var buttonNoNfcText = "Çıkış"
    
    public var buttonCloseImage : UIImage?
    
    public var isHiddenCloseButton = true
    public var isHiddenNfcInfo = false
    public var isHiddenNfcButton = false
    
    public var forceNfc = false
    
    var documentNumber = ""
    var birthDate =  ""
    var expiryDate = ""
    
    var nfcCancel = false
    
    //View outlets
    
    private var nfcReadLabel = StatementLabel()
    private let nfcReadButton = UIButton()
    private let closeButton = UIButton()
    
    public weak var delegate: SCSoftKycNfcViewDelegate?
    
    lazy var idCardReader = PassportReader()
    
    //private var activeColor = UIColor(red: 33.0 / 255.0, green: 209.0 / 255.0, blue: 144.0 / 255.0, alpha: 1.0)
    
    
    private var hasNfc = false
    var nfcErrorCount = 0
    private var captureImageStatus = 0
    private var noCameraText = ""
    
    // MARK: Initializers
    override public init(frame: CGRect) {
        super.init(frame: frame)
        initialize()
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initialize()
    }
    
    // MARK: Init methods
    public func initialize() {
        if NFCNDEFReaderSession.readingAvailable{
            hasNfc = true
        }
        setViewStyle()
    }
    
    fileprivate func setViewStyle() {
        backgroundColor = .clear
    }
    
    public func initiateScreen(documentNumber: String , birthDate: String, expiryDate : String){
        self.documentNumber = documentNumber
        self.birthDate = birthDate
        self.expiryDate = expiryDate
        
        self.initiateNfcReadLabel(forceText: "")
        self.initiateNfcReadButton()
        self.initiateCloseButton()
        self.viewChange()
        
        self.delegate?.getNfcAvailable(self, hasNfc: self.hasNfc)
    }
    
    public func getMyImage(named : String) -> UIImage? {
        let bundle = Bundle(for: SCSoftKycNfcView.self)
        return UIImage(named: named, in: bundle, compatibleWith: nil)
    }
    
    fileprivate func viewChange(){
        // REMOVE VIEW
        add_removeCloseButton(isAdd: true)
        
        //nfc
        add_removeNfcViews(isAdd: true)
        
    }
    
    @objc private func closeButtonInput(){
        self.delegate?.didClose(self)
    }
    
    
    @objc public func nfcReadInput(){
        if !hasNfc {
            closeButtonInput()
            return
        }
        
        if !documentNumber.isEmpty && !birthDate.isEmpty && !expiryDate.isEmpty && isMrzValid() {
            if nfcErrorCount >= nfcErrorLimit {
                closeButtonInput()
            }
            else {
                let idCardModel = IDCardModel(documentNumber: documentNumber, birthDate: convertToDate(value: birthDate), expiryDate:convertToDate(value: expiryDate))
                readCard(idCardModel)
            }
        }else {
            initiateNfcReadLabel(forceText: noMrzDataText)
        }
    }
    
    func convertToDate(value : String) -> Date{
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyMMdd"
        return inputFormatter.date(from: value)!
    }
    
}

@available(iOS 13, *)
extension SCSoftKycNfcView{
    
    fileprivate func add_removeNfcViews(isAdd : Bool){
        if isAdd {
            addSubview(nfcReadLabel)
            addSubview(nfcReadButton)
            
            nfcReadLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                nfcReadLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                nfcReadLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
            ])
            nfcReadLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            nfcReadLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            
            nfcReadButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                nfcReadButton.heightAnchor.constraint(equalToConstant: 50),
                nfcReadButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30),
                nfcReadButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
                nfcReadButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30)
            ])
        }
        else{
            nfcReadLabel.removeFromSuperview()
            nfcReadButton.removeFromSuperview()
        }
    }
    
    fileprivate func add_removeCloseButton(isAdd : Bool){
        if isAdd {
            addSubview(closeButton)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: topAnchor,constant: 20),
                closeButton.heightAnchor.constraint(equalToConstant: 24),
                closeButton.widthAnchor.constraint(equalToConstant: 24),
                closeButton.trailingAnchor.constraint(equalTo: trailingAnchor,constant: -20)
            ])
        }
        else{
            closeButton.removeFromSuperview()
        }
    }
    
    fileprivate func initiateNfcReadLabel(forceText : String) {
        nfcReadLabel.numberOfLines = 0
        var text = infoNfcText
        if !hasNfc {
            text = infoNoNfcText
        }
        if !forceText.isEmpty {
            text = forceText
        }
        nfcReadLabel.shape(text, font: labelFont)
        nfcReadLabel.textColor = labelTextColor
        nfcReadLabel.isHidden = isHiddenNfcInfo
    }
    
    private func initiateNfcReadButton() {
        var text = buttonNfcText
        if !hasNfc {
            text = buttonNoNfcText
        }
        nfcReadButton.setTitle(text, for: .normal)
        nfcReadButton.setTitleColor(buttonTitleColor, for: .normal)
        nfcReadButton.backgroundColor = buttonBackgroundColor
        nfcReadButton.titleLabel?.font = buttonFont
        nfcReadButton.addTarget(self, action: #selector(self.nfcReadInput), for:.touchUpInside)
        nfcReadButton.layer.cornerRadius = buttonRadius
        nfcReadButton.layer.masksToBounds = true
        nfcReadButton.isHidden = isHiddenNfcButton
        //nfcReadButton.layoutIfNeeded()
    }
    
    private func initiateCloseButton() {
        if self.buttonCloseImage != nil {
            self.closeButton.setBackgroundImage(buttonCloseImage, for: .normal)
        }
        else {
            closeButton.setBackgroundImage(getMyImage(named: "cancel"), for: .normal)
        }
        
        
        closeButton.setImage(nil, for: .normal)
        closeButton.addTarget(self, action: #selector(self.closeButtonInput), for:.touchUpInside)
        closeButton.isHidden = isHiddenCloseButton
    }
    
    private func readCard(_ idCardModel: IDCardModel?) {
        let idCardUtil = IDCardUtil()
        if idCardModel == nil {
            
            //s
            //idCardUtil.passportNumber =  "A03K87112"//idCardModel.documentNumber
            //idCardUtil.dateOfBirth = "921207"//idCardModel.birthDate!.toString()
            //idCardUtil.expiryDate = "270618"//idCardModel.expiryDate!.toString()
        }
        else {
            idCardUtil.passportNumber =  idCardModel!.documentNumber
            idCardUtil.dateOfBirth = idCardModel!.birthDate!.toString()
            idCardUtil.expiryDate = idCardModel!.expiryDate!.toString()
        }
        
        let mrzKey = idCardUtil.getMRZKey()
        
        
        // Set the masterListURL on the Passport Reader to allow auto passport verification
        //let masterListURL = Bundle.main.url(forResource: "masterList", withExtension: ".pem")!
        //let masterListURL = Bundle(for: SCSoftkycNfcView.self).url(forResource: "CSCA_TR", withExtension: ".pem")
        //if masterListURL != nil {
        //    idCardReader.setMasterListURL( masterListURL! )
        //}
        
        // If we want to read only specific data groups we can using:
        // let dataGroups : [DataGroupId] = [.COM, .SOD, .DG1, .DG2, .DG7, .DG11, .DG12, .DG14, .DG15]
        // passportReader.readPassport(mrzKey: mrzKey, tags:dataGroups, completed: { (passport, error) in
        
        //setMRZInfo(idCardUtil)
        
        idCardReader.readPassport(mrzKey: mrzKey, customDisplayMessage: { (displayMessage) in
            switch displayMessage {
            case .requestPresentPassport:
                return self.nfcRequestText
            case .successfulRead:
                return self.nfcSuccessfulText
            case .readingDataGroupProgress( _, let progress):
                let progressString = self.handleProgress(percentualProgress: progress)
                return self.nfcReadingDataGroupText + progressString
            case .authenticatingWithPassport(let progress):
                let progressString = self.handleProgress(percentualProgress: progress)
                return self.nfcAuthenticatingWithPassportText + progressString
            case .error(let tagError):
                self.nfcErrorCount += 1
                
                switch tagError {
                case .TagNotValid:
                    return self.nfcErrorText//"TagNotValid"
                case .MoreThanOneTagFound:
                    return self.nfcErrorText//"TagNotValid"
                case .ConnectionError:
                    return self.nfcErrorText//"ConnectionError"
                case .InvalidMRZKey:
                    return self.nfcErrorText//"MRZ bilgisi geçersiz.Tekrar kimliğin arka yüzünü okutunuz."
                case .ResponseError(_, _, _):
                    return self.nfcErrorText//"ResponseError"
                case .UserCanceled:
                    self.nfcCancel = true
                    return self.nfcErrorText//""
                case .UnexpectedError:
                    self.nfcCancel = true
                    return self.nfcErrorText//""
                default:
                    return self.nfcErrorText//"Beklenmeyen bir hata oluşmuştur."
                }
            }
        }, completed: { (passport, error) in
            if let passport = passport {
                // All good, we got a passport
                DispatchQueue.main.async {
                    idCardUtil.passport = passport
                    self.delegate?.didReadNfc(self, didRead: self.setIDCard(idCardUtil))
                }
            } else {
                //if error?.localizedDescription == .UserCanceled.localizedDescription || error?.localizedDescription == .UnexpectedError.localizedDescription {
                //    DispatchQueue.main.async {
                //self.goBack()
                //    }
                //}
                print("Hata: ", error.debugDescription)
            }
        })
    }
    
    func getDateFromString(value : String) -> Date{
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyMMdd"
        return inputFormatter.date(from: value)!
    }
    
    fileprivate func handleProgress(percentualProgress: Int) -> String {
        let p = (percentualProgress/20)
        let full = String(repeating: "🟢 ", count: p)
        let empty = String(repeating: "⚪️ ", count: 5-p)
        return "\(full)\(empty)"
    }
    
    // MARK: MRZ
    fileprivate func isMrzValid() -> Bool {
        var result = false
        if (documentNumber.count >= 8 &&
                birthDate.count == 6 &&
                expiryDate.count == 6) {
            
            let text = documentNumber
            
            let firstCharDocumentNumber = text[0]
            let numberCharDocumentNumber = text[1..<3]
            let secondCharDocumentNumber = text[3]
            
            let dateOfBirth = Int(birthDate) ?? -1
            let dateOfExpiry = Int(expiryDate) ?? -1
            let serialNo = Int(numberCharDocumentNumber) ?? -1
            
            result = true
            if dateOfBirth == -1 || dateOfExpiry == -1 || serialNo == -1 {
                result = false
            }
            
            if !firstCharDocumentNumber.isLetter || !secondCharDocumentNumber.isLetter {
                result = false
            }
        }
        return result
    }
    
    func setIDCard(_ idCardUtil:IDCardUtil) -> SCSoftKycNFCInformation{
        let nfcInformation = SCSoftKycNFCInformation()
        
        nfcInformation.mrzText = idCardUtil.getMRZKey()
        nfcInformation.docType = 1
        nfcInformation.personDetails?.name = idCardUtil.passport?.firstName
        nfcInformation.personDetails?.surname = idCardUtil.passport?.lastName
        nfcInformation.personDetails?.personalNumber = idCardUtil.passport?.personalNumber
        var gender = "N/A"
        if idCardUtil.passport?.gender == "F" {
            gender = "FEMALE"
        } else if idCardUtil.passport?.gender == "M" {
            gender = "MALE"
        }
        nfcInformation.personDetails?.gender = gender
        nfcInformation.personDetails?.birthDate = idCardUtil.passport?.dateOfBirth ?? ""
        nfcInformation.personDetails?.expiryDate = idCardUtil.passport?.documentExpiryDate ?? ""
        nfcInformation.personDetails?.serialNumber = idCardUtil.passport?.documentNumber
        nfcInformation.personDetails?.nationality = idCardUtil.passport?.nationality
        nfcInformation.personDetails?.issuerAuthority = idCardUtil.passport?.issuingAuthority
        
        let faceImage = idCardUtil.passport?.passportImage
        if faceImage != nil {
            nfcInformation.personDetails?.faceImageBase64 = faceImage!.toBase64(format: .jpeg(100)) ?? ""
            nfcInformation.personDetails?.portraitImageBase64 = faceImage!.toBase64(format: .jpeg(100)) ?? ""
        }
        
        let signatureImage = idCardUtil.passport?.signatureImage
        if signatureImage != nil {
            nfcInformation.personDetails?.signatureBase64  = signatureImage!.toBase64(format: .jpeg(100)) ?? ""
        }
        
        nfcInformation.personDetails?.fingerPrints = ["",""]
        
        //AdditionalPersonDetails
        var placeofBirth : [String] = []
        
        var permanetAddress : [String] = []
        
        let dg11 = idCardUtil.passport?.getDataGroup(.DG11) as? DataGroup11
        let placeBirth = dg11?.placeOfBirth ?? ""
        placeofBirth.append(placeBirth)
        let resAddress = dg11?.address ?? ""
        permanetAddress.append(resAddress)
        let phone = dg11?.telephone ?? ""
        let fullName = dg11?.fullName ?? ""
        let custodyInfo = dg11?.custodyInfo ?? ""
       // let fulldateOfBirth = idCardUtil.passport?.dateOfBirth ?? ""
        let fulldateOfBirth = dg11?.dateOfBirth ?? nfcInformation.personDetails?.birthDate
        let title = dg11?.title ?? ""
        let profession = dg11?.profession ?? ""
        let proofOfCitizenship = dg11?.proofOfCitizenship ?? ""
        let personalNumber = dg11?.personalNumber ?? ""
        let personalSummary = dg11?.personalSummary ?? ""
        let tdNumber = dg11?.tdNumbers ?? ""
        var tdNumbers : [String] = []
        tdNumbers.append(tdNumber)
        
        nfcInformation.additionalPersonDetails?.telephone = phone
        nfcInformation.additionalPersonDetails?.permanentAddress = permanetAddress
        nfcInformation.additionalPersonDetails?.placeOfBirth = placeofBirth
        nfcInformation.additionalPersonDetails?.custodyInformation = custodyInfo
        nfcInformation.additionalPersonDetails?.fullDateOfBirth = fulldateOfBirth
        nfcInformation.additionalPersonDetails?.nameOfHolder = fullName
        nfcInformation.additionalPersonDetails?.proofOfCitizenship = proofOfCitizenship
        nfcInformation.additionalPersonDetails?.profession = profession
        nfcInformation.additionalPersonDetails?.proofOfCitizenship = proofOfCitizenship
        nfcInformation.additionalPersonDetails?.personalNumber = personalNumber
        nfcInformation.additionalPersonDetails?.personalSummary = personalSummary
        nfcInformation.additionalPersonDetails?.otherValidTDNumbers = tdNumbers
        nfcInformation.additionalPersonDetails?.title = title
        
        let certByteArray = idCardUtil.passport?.dataGroupsRead[.SOD]?.body
        
        if certByteArray != nil {
            let certData =  Data(certByteArray!)
            nfcInformation.certificateBase64 = certData.base64EncodedString()
        }
        
        return nfcInformation
        
    }
}
