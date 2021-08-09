import Foundation
import UIKit
import AVFoundation
import Vision
import CoreNFC
import JitsiMeetSDK
import NFCPassportReader
import SwiftyTesseract
import QKMRZParser

public enum ViewType {
    case idFrontPhoto
    case idBackPhoto
    case selfie
    case nfcRead
    case jitsi
}

public protocol SCSoftKycViewDelegate: class {
    func didDetectSdkDataBeforeJitsi(_ kycView: SCSoftKycView, didDetect sdkModel: SCSoftKycModel)
    
    func didCaptureIdFrontPhoto(_ kycView : SCSoftKycView, image : UIImage , imageBase64 : String, cropImage : UIImage , cropImageBase64 : String)
    
    func didCaptureIdBackPhoto(_ kycView : SCSoftKycView, image : UIImage , imageBase64 : String, cropImage : UIImage , cropImageBase64 : String)
    
    func didCaptureSelfiePhoto(_ kycView : SCSoftKycView, image : UIImage , imageBase64 : String, cropImage : UIImage , cropImageBase64 : String)
    
    func didCaptureIdFrontFacePhoto(_ kycView : SCSoftKycView, image : UIImage , imageBase64 : String)
    
    //@available(iOS 13, *)
    func didReadNfc(_ kycView : SCSoftKycView , didRead nfcData : IDCardUtil)
    
    func didClose(_ kycView: SCSoftKycView, didDetect sdkModel: SCSoftKycModel)
    
    func getNfcAvailable(_ kycView: SCSoftKycView, hasNfc : Bool)
    
    func didAgeControlOver18(status : Bool)
    
    func didReadMrz(_ kycView : SCSoftKycView, didRead mrzInfo : QKMRZScanResult)
}

@IBDesignable
public class SCSoftKycView: UIView {
    
    // Public variables
    
    public var nfcErrorLimit = 3
    public var activeColor = UIColor(red: 27.0 / 255.0, green: 170.0 / 255.0, blue: 194.0 / 255.0, alpha: 1.0)
    public var passiveColor = UIColor.white
    public var buttonBackgroundColor = UIColor(red: 27.0 / 255.0, green: 170.0 / 255.0, blue: 194.0 / 255.0, alpha: 1.0)
    public var buttonTitleColor = UIColor.white
    public var buttonFont = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
    public var buttonRadius : CGFloat = 8
    
    public var labelTextColor = UIColor.white
    public var labelFont = UIFont.boldSystemFont(ofSize: 16)
    
    public var infoIdFrontText = "Kimlik kartınızın ön yüzünü belirtilen kare içerisine alarak fotoğraf çekme butonuna basınız."
    public var infoIdBackText = "Kimlik kartınızın arka yüzünü belirtilen kare içerisine alarak fotoğraf çekme butonuna basınız."
    public var infoNfcText = "Kimlik kartınızı telefonun arka üst kısmına yaklaştırın ve Tara butonuna basın."
    public var infoNoNfcText = "Cihazınızda Nfc desteği bulunmamaktadır. Devam butonuna basarak sürece devam edebilirsiniz."
    public var infoJitsiText = "Birazdan müşteri temsilcisine bağlanacaksınız. \nLütfen bekleyiniz."
    public var buttonJitsiText = "İptal Et"
    public var buttonNfcText = "Tara"
    public var buttonNoNfcText = "Devam"
    public var buttonCameraActiveImage : UIImage?
    public var buttonCameraPassiveImage : UIImage?
    public var buttonCloseImage : UIImage?
    public var buttonFlashOnImage : UIImage?
    public var buttonFlashOffImage : UIImage?
    public var cameraFlashState = false
    
    public var isHiddenIdPhotoInfo = false
    public var isHiddenIdPhotoCameraButton = false
    public var isHiddenIdPhotoFlashButton = false
    public var isHiddenCloseButton = false
    
    public var isHiddenNfcInfo = false
    public var isHiddenNfcButton = false
    
    public var isHiddenJitsiInfo = false
    public var isHiddenJitsiButton = false
    
    public var forceNfc = false
    
    public weak var delegate: SCSoftKycViewDelegate?
    //public var _viewTypes = [ViewType]()
    var viewTypeLinkedList = LinkedListViewType<ViewType>()
    var _viewTypes = [ViewType]()
    public var viewTypes:[ViewType] {
        get {
            return _viewTypes
        }
        set (newVal) {
            _viewTypes = newVal
            viewTypeLinkedList = LinkedListViewType(array: newVal)
            if _viewTypes.count > 0 {
                selectedViewType = _viewTypes[0]
                showViewType(viewType: selectedViewType)
            }
        }
    }
    
    var nfcCancel = false
    var mrz_18_youngerCheck = false
    
    private var selectedViewType = ViewType.idFrontPhoto
    
    //Video Capture
    private var bufferSize: CGSize = .zero
    private let videoDataOutputQueue = DispatchQueue(label: "videoDataOutputQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var captureSession = AVCaptureSession()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    //View outlets
    private let takePhotoButton = CircleButton()
    private let cutoutView = QKCutoutView()
    private let cutoutSelfieView = OvalOverlayView()
    private var idPhotoLabel = StatementLabel()
    private let flashButton = ToggleButton()
    private var nfcReadLabel = StatementLabel()
    private var jitsiLabel = StatementLabel()
    private let jitsiButton = UIButton()
    private var informationLabel = StatementLabel()
    private let nfcReadButton = UIButton()
    private let informationNextButton = UIButton()
    private let closeButton = UIButton()
    //private var flipImageView = UIImageView()
    
    private var sdkModel = SCSoftKycModel()
    private var isFinish = false
    //private var isFront = true
    private var checkFace = false
    private var checkMrz = false
    private var checkRectangle = false
    
    private var backCamera : AVCaptureDevice?
    private var frontCamera : AVCaptureDevice?
    private var backInput : AVCaptureInput!
    private var frontInput : AVCaptureInput!
    
    fileprivate var observer: NSKeyValueObservation?
    @objc fileprivate dynamic var isScanning = false
    fileprivate var isScanningPaused = false
    
    //Capture result
    //private var capturedImage: UIImage!
    private var capturedFace: UIImage!
    private var capturedMrz: UIImage!
    
    fileprivate let tesseract = SwiftyTesseract(language: .custom("ocrb"), dataSource: Bundle(for: SCSoftKycView.self), engineMode: .tesseractOnly)
    fileprivate let mrzParser = QKMRZParser(ocrCorrection: true)
    
    fileprivate var inputCIImage: CIImage!
    fileprivate var inputCGImage: CGImage!
    
    @available(iOS 13, *)
    lazy var idCardReader = PassportReader()
    
    private var refreshTimer: Timer?
    
    // Jitsi config
    fileprivate var inJitsi : Bool = false
    fileprivate var jitsiMeetView = JitsiMeetView()
    
    //private var activeColor = UIColor(red: 33.0 / 255.0, green: 209.0 / 255.0, blue: 144.0 / 255.0, alpha: 1.0)
    
    
    private var hasNfc = false
    private var nfcErrorCount = 0
    private var captureImageStatus = 0
    private var noCameraText = ""
    
    fileprivate var cutoutRect: CGRect? {
        return cutoutView.cutoutRect
    }
    
    fileprivate var cutoutSelfieRect: CGRect? {
        return cutoutSelfieView.overlayFrame
    }
    
    private lazy var facesRequest: VNDetectFaceRectanglesRequest = {
        return VNDetectFaceRectanglesRequest(completionHandler: self.handleFacesRequest)
    }()
    
    private lazy var mrzRequest: VNDetectTextRectanglesRequest = {
        return VNDetectTextRectanglesRequest(completionHandler: self.handleMrzRequest)
    }()
    
    private lazy var rectanglesRequest: VNDetectRectanglesRequest = {
        let rectanglesRequest = VNDetectRectanglesRequest(completionHandler: self.handleRectanglesRequest)
        rectanglesRequest.minimumAspectRatio = VNAspectRatio(1.3)
        rectanglesRequest.maximumAspectRatio = VNAspectRatio(1.6)
        rectanglesRequest.minimumSize = Float(0.5)
        rectanglesRequest.maximumObservations = 1
        return rectanglesRequest
    }()
    
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
    fileprivate func initialize() {
        FilterVendor.registerFilters()
        //NFCReaderSession.readingAvailable
        
        if NFCNDEFReaderSession.readingAvailable{
            hasNfc = true
        }
        setupAndStartCaptureSession()
        setViewStyle()
        initiateScreen()
        
        refreshTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
        addAppObservers()
    }
    
    // MARK: UIApplication Observers
    @objc fileprivate func appWillEnterForeground() {
        if isScanningPaused {
            isScanningPaused = false
            startScanning()
        }
    }
    
    @objc fileprivate func appDidEnterBackground() {
        if isScanning {
            isScanningPaused = true
            stopScanning()
        }
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.frame = bounds
    }
    
    // MARK: Scanning
    public func startScanning() {
        guard !captureSession.inputs.isEmpty else {
            return
        }
        captureSession.startRunning()
    }
    
    public func stopScanning() {
        captureSession.stopRunning()
    }
    
    fileprivate func setViewStyle() {
        backgroundColor = .clear
    }
    
    @objc func runTimedCode(){
        self.checkFace = false
        self.checkRectangle = false
        updateScanArea()
    }
    
    private func initiateScreen(){
        DispatchQueue.main.async {
            self.initiateStatement()
            self.initiateFlashButton()
            self.initiateTakePhotoButton()
            self.initiateNfcReadLabel(forceText: "")
            self.initiateNfcReadButton()
            self.initiateInformationNextButton(stateIsEnd: false)
            self.initiateCloseButton()
            //self.initiateFlipImageView()
            self.initiateJitsiLabel()
            self.initiateJitsiButton()
            self.viewChange()
            self.delegate?.getNfcAvailable(self, hasNfc: self.hasNfc)
        }
    }
    
    private func updateScanArea() {
        var found = false
        
        if selectedViewType == .idFrontPhoto || selectedViewType == .idBackPhoto {
            if checkRectangle && ((selectedViewType == .idFrontPhoto && checkFace) || (selectedViewType == .idBackPhoto && checkMrz && !checkFace)){
                found = true
            }
            
            DispatchQueue.main.async {
                (self.cutoutView.layer.sublayers?.first as? CAShapeLayer)?.strokeColor = (found) ? self.activeColor.cgColor : self.passiveColor.cgColor
                self.cutoutView.layoutIfNeeded()
                
               
                if self.buttonCameraActiveImage != nil && self.buttonCameraPassiveImage  != nil{
                    let image = (found) ? self.buttonCameraActiveImage : self.buttonCameraPassiveImage
                    self.takePhotoButton.setBackgroundImage(image, for: .normal)
                }
                else {
                    let btnImage = (found) ? "camera_button_on" : "camera_button_off"
                    self.takePhotoButton.setBackgroundImage(self.getMyImage(named: btnImage), for: .normal)
                }
                self.takePhotoButton.isEnabled = found
            }
        }
        else if selectedViewType == .selfie{
            if checkFace{
                found = true
            }
            
            DispatchQueue.main.async {
                (self.cutoutSelfieView.layer.sublayers?.first as? CAShapeLayer)?.strokeColor = (found) ? self.activeColor.cgColor : self.passiveColor.cgColor
                self.cutoutSelfieView.layoutIfNeeded()
                
                if self.buttonCameraActiveImage != nil && self.buttonCameraPassiveImage  != nil{
                    let image = (found) ? self.buttonCameraActiveImage : self.buttonCameraPassiveImage
                    self.takePhotoButton.setBackgroundImage(image, for: .normal)
                }
                else {
                    let btnImage = (found) ? "camera_button_on" : "camera_button_off"
                    self.takePhotoButton.setBackgroundImage(self.getMyImage(named: btnImage), for: .normal)
                }
                self.takePhotoButton.isEnabled = found
            }
        }
    }
    
    public func getMyImage(named : String) -> UIImage? {
        let bundle = Bundle(for: SCSoftKycView.self)
        return UIImage(named: named, in: bundle, compatibleWith: nil)
    }
    
    // MARK: Document Image from Photo cropping
    fileprivate func cutoutRect(for cgImage: CGImage) -> CGRect {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let rect = videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: cutoutRect!)
        let videoOrientation = videoPreviewLayer.connection!.videoOrientation
        
        if videoOrientation == .portrait || videoOrientation == .portraitUpsideDown {
            return CGRect(x: (rect.minY * imageWidth), y: (rect.minX * imageHeight), width: (rect.height * imageWidth), height: (rect.width * imageHeight))
        }
        else {
            return CGRect(x: (rect.minX * imageWidth), y: (rect.minY * imageHeight), width: (rect.width * imageWidth), height: (rect.height * imageHeight))
        }
    }
    
    fileprivate func documentImage(from cgImage: CGImage) -> CGImage {
        let croppingRect = cutoutRect(for: cgImage)
        return cgImage.cropping(to: croppingRect) ?? cgImage
    }
    
    fileprivate func enlargedDocumentImage(from cgImage: CGImage) -> UIImage {
        var croppingRect = cutoutRect(for: cgImage)
        let margin = (0.05 * croppingRect.height) // 5% of the height
        croppingRect = CGRect(x: (croppingRect.minX - margin), y: (croppingRect.minY - margin), width: croppingRect.width + (margin * 2), height: croppingRect.height + (margin * 2))
        return UIImage(cgImage: cgImage.cropping(to: croppingRect)!)
    }
    
    fileprivate func selfieImage(from cgImage: CGImage) -> CGImage {
        let croppingRect = cutoutSelfieRect(for: cgImage)
        return cgImage.cropping(to: croppingRect) ?? cgImage
    }
    
    // MARK: Document Image from Photo cropping
    fileprivate func cutoutSelfieRect(for cgImage: CGImage) -> CGRect {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let rect = videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: cutoutSelfieRect!)
        let videoOrientation = videoPreviewLayer.connection!.videoOrientation
        
        if videoOrientation == .portrait || videoOrientation == .portraitUpsideDown {
            return CGRect(x: (rect.minY * imageWidth), y: (rect.minX * imageHeight), width: (rect.height * imageWidth), height: (rect.width * imageHeight))
        }
        else {
            return CGRect(x: (rect.minX * imageWidth), y: (rect.minY * imageHeight), width: (rect.width * imageWidth), height: (rect.height * imageHeight))
        }
    }
    
    fileprivate func enlargedSelfieImage(from cgImage: CGImage) -> UIImage {
        var croppingRect = cutoutSelfieRect(for: cgImage)
        let margin = (0.05 * croppingRect.height) // 5% of the height
        croppingRect = CGRect(x: (croppingRect.minX - margin), y: (croppingRect.minY - margin), width: croppingRect.width + (margin * 2), height: croppingRect.height + (margin * 2))
        return UIImage(cgImage: cgImage.cropping(to: croppingRect)!)
    }
    
    fileprivate func addAppObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    //MARK:- Camera Setup
    private func setupAndStartCaptureSession(){
        //get back camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            backCamera = device
        } else {
            //handle this appropriately for production purposes
            noCameraText = "no back camera"
            return
        }
        
        //get front camera
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
            frontCamera = device
        } else {
            noCameraText = "no front camera"
            return
        }
        
        //DispatchQueue.global(qos: .userInitiated).async{
        //init session
        self.captureSession = AVCaptureSession()
        //start configuration
        self.captureSession.beginConfiguration()
        
        //session specific configuration
        if self.captureSession.canSetSessionPreset(.photo) {
            self.captureSession.sessionPreset = .photo
        }
        self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
        
        observer = captureSession.observe(\.isRunning, options: [.new]) { [unowned self] (model, change) in
            // CaptureSession is started from the global queue (background). Change the `isScanning` on the main
            // queue to avoid triggering the change handler also from the global queue as it may affect the UI.
            DispatchQueue.main.async {
                [weak self] in self?.isScanning = change.newValue!
            }
        }
        
        //setup inputs
        self.setupInputs()
        
        //DispatchQueue.main.async {
        //setup preview layer
        self.setupPreviewLayer()
        //}
        
        //setup output
        self.setupOutput()
        
        //commit configuration
        self.captureSession.commitConfiguration()
        //start running it
        self.captureSession.startRunning()
        //}
    }
    
    private func setupInputs(){
        
        //now we need to create an input objects from our devices
        guard let bInput = try? AVCaptureDeviceInput(device: backCamera!) else {
            noCameraText = "could not create input device from back camera"
            return
        }
        backInput = bInput
        if !captureSession.canAddInput(backInput) {
            noCameraText = "could not add back camera input to capture session"
            return
        }
        
        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera!) else {
            noCameraText = "could not create input device from front camera"
            return
        }
        frontInput = fInput
        if !captureSession.canAddInput(frontInput) {
            noCameraText = "could not add front camera input to capture session"
            return
        }
        
        //connect back camera input to session
        captureSession.addInput(backInput)
    }
    
    private func setupOutput(){
        videoDataOutput = AVCaptureVideoDataOutput()
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA] as [String : Any]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        } else {
            noCameraText = "could not add video output"
            return
        }
        
        videoDataOutput.connections.first?.videoOrientation = .portrait
    }
    
    private func setupPreviewLayer(){
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.frame = bounds
    }
    
    public func getSelectedViewType() -> ViewType{
        return selectedViewType
    }
    
    public func approvedNextView(){
        // for save data
        getNextViewType()
    }
    
    public func rejectedNextView(){
        // for save data
        if selectedViewType == .idFrontPhoto {
            sdkModel.idFrontImage = nil
            sdkModel.autoCropped_idFrontImage = nil
            //checkFace = false
            //checkRectangle = false
        }
        else if selectedViewType == .idBackPhoto {
            sdkModel.idBackImage = nil
            sdkModel.autoCropped_idBackImage = nil
            sdkModel.mrzInfo = nil
            //checkFace = false
            //checkRectangle = false
            //checkMrz = false
        }
        else if selectedViewType == .selfie {
            sdkModel.selfieImage = nil
            sdkModel.autoCropped_selfieImage = nil
        }
        DispatchQueue.main.async {
            self.viewChange()
        }
    }
    
    public func showJitsiView(){
        // for save data
        delegate?.didDetectSdkDataBeforeJitsi(self, didDetect: sdkModel)
    }
    
    public func showNfcView(){
        selectedViewType = .nfcRead
        DispatchQueue.main.async {
            self.viewChange()
        }
    }
    
    public func showSelfieView(){
        /*if inJitsi{
         let seconds = 0.5
         DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
         self.showSelfieView()
         }
         return
         }*/
        selectedViewType = .selfie
        
        if noCameraText.isEmpty{
            captureSession.beginConfiguration()
            if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
                for input in inputs {
                    captureSession.removeInput(input)
                }
            }
            if captureSession.inputs.isEmpty {
                self.captureSession.addInput(frontInput)
            }
            
            //deal with the connection again for portrait mode
            videoDataOutput.connections.first?.videoOrientation = .portrait
            //mirror the video stream for front camera
            videoDataOutput.connections.first?.isVideoMirrored = true
            //commit config
            captureSession.commitConfiguration()
        }
        DispatchQueue.main.async {
            self.viewChange()
        }
    }
    
    public func showIdPhotoView(){
        //selectedViewType = .idFrontPhoto
        
        if noCameraText.isEmpty{
            captureSession.beginConfiguration()
            
            if let inputs = captureSession.inputs as? [AVCaptureDeviceInput] {
                for input in inputs {
                    captureSession.removeInput(input)
                }
            }
            if captureSession.inputs.isEmpty {
                self.captureSession.addInput(backInput)
            }
            
            //deal with the connection again for portrait mode
            videoDataOutput.connections.first?.videoOrientation = .portrait
            //mirror the video stream for front camera
            videoDataOutput.connections.first?.isVideoMirrored = false
            //commit config
            captureSession.commitConfiguration()
        }
        DispatchQueue.main.async {
            self.viewChange()
        }
    }
    
    fileprivate func viewChange(){
        // REMOVE VIEW
        //idPhoto
        add_removeInformationView(isAdd: false)
        //add_removeFlipImageView(isAdd: false)
        add_removeCloseButton(isAdd: false)
        add_removeCutoutView(isAdd: false)
        add_removeIdPhotoLabel(isAdd: false)
        add_removeFlashButton(isAdd: false)
        
        //share camera view
        add_removeTakePhotoButton(isAdd: false)
        
        //selfie
        add_removeCutoutSelfieView(isAdd: false)
        
        //nfc
        add_removeNfcViews(isAdd: false)
        videoPreviewLayer.removeFromSuperlayer()
        
        //jitsi
        add_removeJitsiView(isAdd: false)
        add_removeJitsiInfoViews(isAdd: false)
        
        if !noCameraText.isEmpty && frontCamera == nil && selectedViewType == .selfie {
            initiateInformationLabel(text: "Cihazınızda ön kamera bulunmamaktadır. Devam butonuna basarak sürece devam edebilirsiniz.")
            add_removeInformationView(isAdd: true)
            add_removeCloseButton(isAdd: true)
            return
        }
        
        if !noCameraText.isEmpty && backCamera == nil && (selectedViewType == .idBackPhoto || selectedViewType == .idFrontPhoto) {
            initiateInformationLabel(text: "Cihazınızda arka kamera bulunmamaktadır. Devam butonuna basarak sürece devam edebilirsiniz.")
            add_removeInformationView(isAdd: true)
            add_removeCloseButton(isAdd: true)
            return
        }
        
        //the end methods
        if forceNfc && !hasNfc {
            initiateInformationLabel(text: "Cihazınızda NFC desteği bulunmamaktadır. Bu kontrol zorunlu tutulduğu için ilerleme yapılamamaktadır.")
            initiateInformationNextButton(stateIsEnd: true)
            add_removeInformationView(isAdd: true)
            add_removeCloseButton(isAdd: true)
            return
        }
        
        if viewTypes.count == 0 {
            initiateInformationLabel(text: "Sdk içerisine işlem listesi boş gönderilmiştir.")
            initiateInformationNextButton(stateIsEnd: true)
            add_removeInformationView(isAdd: true)
            add_removeCloseButton(isAdd: true)
            return
        }
        
        if mrz_18_youngerCheck {
            initiateInformationLabel(text: "Müşteri olabilmeniz için 18 yaşından büyük olmanız gerekmektedir.")
            initiateInformationNextButton(stateIsEnd: true)
            add_removeInformationView(isAdd: true)
            add_removeCloseButton(isAdd: true)
            return
        }
        
        if isFinish {
            initiateInformationLabel(text: "Süreç tamamlanmıştır.")
            initiateInformationNextButton(stateIsEnd: true)
            add_removeInformationView(isAdd: true)
            add_removeCloseButton(isAdd: true)
            return
        }
        
        // ADD VIEW
        //share camera view
        if selectedViewType == .idFrontPhoto || selectedViewType == .idBackPhoto || selectedViewType == .selfie {
            layer.addSublayer(videoPreviewLayer)
        }
        
        if selectedViewType == .idFrontPhoto || selectedViewType == .idBackPhoto {
            add_removeCutoutView(isAdd: true)
            add_removeTakePhotoButton(isAdd: true)
            add_removeFlashButton(isAdd: true)
            add_removeIdPhotoLabel(isAdd: true)
            
            if selectedViewType == .idFrontPhoto {
                idPhotoLabel.shape(infoIdFrontText, font: labelFont)
            }
            else {
                idPhotoLabel.shape(infoIdBackText, font: labelFont)
            }
            idPhotoLabel.textColor = labelTextColor
            //add_removeFlipImageView(isAdd: true)
        }
        else if selectedViewType == .selfie {
            add_removeCutoutSelfieView(isAdd: true)
            add_removeTakePhotoButton(isAdd: true)
        }
        else if selectedViewType == .nfcRead {
            add_removeNfcViews(isAdd: true)
        }
        else if selectedViewType == .jitsi {
            add_removeJitsiInfoViews(isAdd: true)
        }
        add_removeCloseButton(isAdd: true)
    }
    
    public func setJitsiWaitingState(){
        selectedViewType = .jitsi
        DispatchQueue.main.async {
            self.viewChange()
        }
    }
    
    public func setJitsiConference(url : String, room : String, token : String){
        if selectedViewType == .jitsi {
            add_removeCloseButton(isAdd: false)
            add_removeJitsiInfoViews(isAdd: false)
            
            openJitsiMeet(url: url, room: room, token: token)
            
            add_removeJitsiView(isAdd: true)
            add_removeCloseButton(isAdd: true)
        }
    }
    
    private func getNextViewType(){
        if viewTypeLinkedList.isEmpty || viewTypeLinkedList.head == nil {
            return
        }
        var newViewType = selectedViewType
        var isNext = false
        var tempValue = viewTypeLinkedList.head
        while tempValue != nil {
            if isNext && tempValue != nil{
                newViewType = tempValue!.value
                break
            }
            
            if tempValue?.value == selectedViewType {
                isNext = true
            }
            if tempValue?.next == nil {
                isFinish = true
                DispatchQueue.main.async {
                    self.viewChange()
                }
                break
            }
            else{
                tempValue = tempValue?.next!
            }
        }
        if newViewType != selectedViewType{
            showViewType(viewType: newViewType)
        }
    }
    
    private func showViewType(viewType : ViewType){
        if viewType == .idFrontPhoto ||  viewType == .idBackPhoto{
            selectedViewType = viewType
            showIdPhotoView()
        }
        else if viewType == .selfie {
            showSelfieView()
        }
        else if viewType == .nfcRead {
            showNfcView()
        }
        else if viewType == .jitsi {
            showJitsiView()
        }
    }
    
    @objc private func closeButtonInput(){
        if selectedViewType == .jitsi {
            jitsiMeetView.leave()
            jitsiMeetView.removeFromSuperview()
        }
        refreshTimer?.invalidate()
        self.delegate?.didClose(self, didDetect: sdkModel)
    }
    
    //button onclick
    @objc private func analyzeCard() {
        if self.buttonCameraActiveImage != nil && self.buttonCameraPassiveImage  != nil{
            self.takePhotoButton.setBackgroundImage(self.buttonCameraPassiveImage, for: .normal)
        }
        else {
            takePhotoButton.setBackgroundImage(self.getMyImage(named: "camera_button_off"), for: .normal)
        }
        
        takePhotoButton.setImage(self.getMyImage(named: "loading_card"), for: .normal)
        takePhotoButton.rotateButton()
        
        if selectedViewType == .idFrontPhoto {
            /*self.flipImageView.alpha = 1
            let opt : UIView.AnimationOptions = [.curveLinear, .autoreverse]
            UIView.animate(withDuration: 1.7, delay: 0.4, options: opt, animations:
                            {
                                self.flipImageView.transform = CGAffineTransform(scaleX: -1, y: 1)
                            },
                           completion: {_ in
                            self.flipImageView.alpha = 0
                           })*/
            sdkModel.idFrontImage = UIImage(cgImage: self.inputCGImage)
            //sdkModel.autoCropped_idFrontImage = self.capturedImage
            sdkModel.base64_idFrontImage =  sdkModel.idFrontImage?.toBase64(format: .png)
            //isFront = false
            //self.delegate?.didDetectSdkData(self, didDetect: sdkModel)
        }
        else if selectedViewType == .idBackPhoto {
            //isFront = true
            sdkModel.idBackImage = UIImage(cgImage: self.inputCGImage)
            //sdkModel.autoCropped_idBackImage = self.capturedImage
            sdkModel.base64_idBackImage =  sdkModel.idBackImage?.toBase64(format: .png)
            //self.delegate?.didDetectSdkData(self, didDetect: sdkModel)
            //getNextViewType()
        }
        else if selectedViewType == .selfie {
            sdkModel.selfieImage = UIImage(cgImage: self.inputCGImage)
            sdkModel.autoCropped_selfieImage = self.capturedFace
            sdkModel.base64_selfieImage =  sdkModel.selfieImage?.toBase64(format: .png)
            sdkModel.base64_autoCropped_selfieImage = sdkModel.autoCropped_selfieImage?.toBase64(format: .png)
            //self.delegate?.didDetectSdkData(self, didDetect: sdkModel)
            self.delegate?.didCaptureSelfiePhoto(self, image: sdkModel.selfieImage!, imageBase64: sdkModel.base64_selfieImage!, cropImage: sdkModel.autoCropped_selfieImage!, cropImageBase64: sdkModel.base64_autoCropped_selfieImage!)
            //getNextViewType()
        }
    }
    
    @objc private func flashState(){
        let avDevice = AVCaptureDevice.default(for: AVMediaType.video)
        if ((avDevice?.hasTorch) != nil) {
            do {
                _ = try avDevice!.lockForConfiguration()
            } catch {
                print("flash on")
            }
            
            if avDevice!.isTorchActive {
                avDevice!.torchMode = AVCaptureDevice.TorchMode.off
            } else {
                do {
                    _ = try avDevice!.setTorchModeOn(level: 1.0)
                } catch {
                    print("flash off")
                }
            }
            avDevice!.unlockForConfiguration()
        }
    }
    
    @objc private func informationNextButtonInput(){
        getNextViewType()
        return
    }
    
    @objc private func nfcReadInput(){
        if !hasNfc {
            getNextViewType()
            return
        }
        
        if sdkModel.mrzInfo != nil {
            if nfcErrorCount >= nfcErrorLimit {
                getNextViewType()
            }
            else {
                let documentNumber = sdkModel.mrzInfo!.documentNumber
                let birthDate = sdkModel.mrzInfo!.birthDate!
                let expiryDate = sdkModel.mrzInfo!.expiryDate!
                
                let idCardModel = IDCardModel(documentNumber: documentNumber, birthDate: birthDate, expiryDate: expiryDate)
                if #available(iOS 13, *) {
                    readCard(idCardModel)
                } else {
                    getNextViewType()
                    // Fallback on earlier versions
                }
            }
        }else {
            initiateNfcReadLabel(forceText: "Kimlik mrz bilgisi bulunamamıştır. Nfc okuması yapılabilmesi için öncelikle kimlik bilgilerinin sistem tarafından kaydedilmesi gerekmektedir.")
        }
    }
}

extension SCSoftKycView{
    
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
    
    fileprivate func add_removeJitsiInfoViews(isAdd : Bool){
        if isAdd {
            addSubview(jitsiLabel)
            addSubview(jitsiButton)
            
            jitsiLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                jitsiLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                jitsiLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
            ])
            jitsiLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            jitsiLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            
            jitsiButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                jitsiButton.heightAnchor.constraint(equalToConstant: 50),
                jitsiButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30),
                jitsiButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
                jitsiButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30)
            ])
        }
        else{
            jitsiLabel.removeFromSuperview()
            jitsiButton.removeFromSuperview()
        }
    }
    
    fileprivate func add_removeInformationView(isAdd : Bool){
        if isAdd {
            addSubview(informationLabel)
            addSubview(informationNextButton)
            
            informationLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                informationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                informationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
            ])
            informationLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            informationLabel.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            
            informationNextButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                informationNextButton.heightAnchor.constraint(equalToConstant: 50),
                informationNextButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30),
                informationNextButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 30),
                informationNextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30)
            ])
            
        }
        else{
            informationLabel.removeFromSuperview()
            informationNextButton.removeFromSuperview()
        }
    }
    
    fileprivate func add_removeIdPhotoLabel(isAdd : Bool){
        if isAdd {
            addSubview(idPhotoLabel)
            idPhotoLabel.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                idPhotoLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
                idPhotoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
                idPhotoLabel.topAnchor.constraint(equalTo: topAnchor, constant: 50)
            ])
        }
        else{
            idPhotoLabel.removeFromSuperview()
        }
    }
    
    fileprivate func add_removeFlashButton(isAdd : Bool){
        if isAdd {
            addSubview(flashButton)
            flashButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                flashButton.heightAnchor.constraint(equalToConstant: 24),
                flashButton.widthAnchor.constraint(equalToConstant: 24),
                flashButton.centerYAnchor.constraint(equalTo: takePhotoButton.centerYAnchor),
                flashButton.leadingAnchor.constraint(equalTo: takePhotoButton.trailingAnchor, constant: 30)
            ])
        }
        else{
            flashButton.removeFromSuperview()
        }
    }
    
    fileprivate func add_removeJitsiView(isAdd : Bool){
        if isAdd {
            addSubview(jitsiMeetView)
            jitsiMeetView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                jitsiMeetView.topAnchor.constraint(equalTo: topAnchor),
                jitsiMeetView.bottomAnchor.constraint(equalTo: bottomAnchor),
                jitsiMeetView.leftAnchor.constraint(equalTo: leftAnchor),
                //takePhotoButton.heightAnchor.constraint(equalToConstant: 100),
                //takePhotoButton.widthAnchor.constraint(equalToConstant: 100)
                jitsiMeetView.rightAnchor.constraint(equalTo: rightAnchor)
            ])
        }
        else{
            jitsiMeetView.removeFromSuperview()
        }
    }
    
    fileprivate func add_removeTakePhotoButton(isAdd : Bool){
        if isAdd {
            addSubview(takePhotoButton)
            takePhotoButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                takePhotoButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -30),
                takePhotoButton.centerXAnchor.constraint(equalTo: centerXAnchor),
                takePhotoButton.heightAnchor.constraint(equalToConstant: 70),
                takePhotoButton.widthAnchor.constraint(equalToConstant: 70)
            ])
        }
        else{
            takePhotoButton.removeFromSuperview()
        }
    }
    
    fileprivate func add_removeCloseButton(isAdd : Bool){
        if isAdd {
            addSubview(closeButton)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: topAnchor,constant: 20),
                //closeButton.bottomAnchor.constraint(equalTo: bottomAnchor),
                //closeButton.leftAnchor.constraint(equalTo: leftAnchor),
                closeButton.heightAnchor.constraint(equalToConstant: 24),
                closeButton.widthAnchor.constraint(equalToConstant: 24),
                closeButton.trailingAnchor.constraint(equalTo: trailingAnchor,constant: -20)
            ])
        }
        else{
            closeButton.removeFromSuperview()
        }
    }
    
    
    fileprivate func add_removeCutoutView(isAdd : Bool){
        if isAdd {
            cutoutView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(cutoutView)
            NSLayoutConstraint.activate([
                cutoutView.topAnchor.constraint(equalTo: topAnchor),
                cutoutView.bottomAnchor.constraint(equalTo: bottomAnchor),
                cutoutView.leftAnchor.constraint(equalTo: leftAnchor),
                cutoutView.rightAnchor.constraint(equalTo: rightAnchor)
            ])
        }
        else{
            cutoutView.removeFromSuperview()
        }
    }
    
    /*fileprivate func add_removeFlipImageView(isAdd : Bool){
        if isAdd {
            flipImageView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(flipImageView)
            NSLayoutConstraint.activate([
                flipImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                flipImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                flipImageView.widthAnchor.constraint(equalToConstant: 80),
                flipImageView.heightAnchor.constraint(equalToConstant: 80)
            ])
        }
        else{
            flipImageView.removeFromSuperview()
        }
    }*/
    
    fileprivate func add_removeCutoutSelfieView(isAdd : Bool){
        if isAdd {
            cutoutSelfieView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(cutoutSelfieView)
            NSLayoutConstraint.activate([
                cutoutSelfieView.topAnchor.constraint(equalTo: topAnchor),
                cutoutSelfieView.bottomAnchor.constraint(equalTo: bottomAnchor),
                cutoutSelfieView.leftAnchor.constraint(equalTo: leftAnchor),
                cutoutSelfieView.rightAnchor.constraint(equalTo: rightAnchor)
            ])
        }
        else{
            cutoutSelfieView.removeFromSuperview()
        }
    }
    
    //TODO
    private func initiateInformationNextButton(stateIsEnd : Bool) {
        var text = "Devam"
        informationNextButton.addTarget(self, action: #selector(self.informationNextButtonInput), for:.touchUpInside)
        if stateIsEnd{
            text = "Çıkış"
            informationNextButton.addTarget(self, action: #selector(self.closeButtonInput), for:.touchUpInside)
        }

        informationNextButton.setTitle(text, for: .normal)
        informationNextButton.setTitleColor(buttonTitleColor, for: .normal)
        informationNextButton.backgroundColor = buttonBackgroundColor
        informationNextButton.titleLabel?.font = buttonFont
        informationNextButton.layer.cornerRadius = buttonRadius
        informationNextButton.layer.masksToBounds = true
        
        //informationNextButton.layoutIfNeeded()
    }
    
    //TODO
    fileprivate func initiateInformationLabel(text : String) {
        informationLabel.numberOfLines = 0
        informationLabel.textColor = labelTextColor
        informationLabel.shape(text, font: labelFont)
    }
    
    fileprivate func initiateJitsiLabel() {
        jitsiLabel.numberOfLines = 0
        let text = infoJitsiText
        jitsiLabel.shape(text, font: labelFont)
        jitsiLabel.textColor = labelTextColor
        jitsiLabel.isHidden = isHiddenJitsiInfo
    }
    
    private func initiateJitsiButton() {
        let text = buttonJitsiText
        jitsiButton.setTitle(text, for: .normal)
        jitsiButton.setTitleColor(buttonTitleColor, for: .normal)
        jitsiButton.backgroundColor = buttonBackgroundColor
        jitsiButton.titleLabel?.font = buttonFont
        jitsiButton.addTarget(self, action: #selector(self.closeButtonInput), for:.touchUpInside)
        jitsiButton.layer.cornerRadius = buttonRadius
        jitsiButton.layer.masksToBounds = true
        jitsiButton.isHidden = isHiddenJitsiButton
        //jitsiButton.layoutIfNeeded()
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
    
    /*private func initiateFlipImageView() {
        flipImageView.image = self.getMyImage(named: "flip_h")
        flipImageView.alpha = 0
    }*/
    
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
    
    private func initiateStatement() {
        idPhotoLabel.numberOfLines = 0
    }
    
    private func initiateFlashButton(){
        flashButton.isOn = false
        if self.buttonFlashOnImage != nil && self.buttonFlashOffImage != nil {
            flashButton.offImage = buttonFlashOffImage
            flashButton.onImage = buttonFlashOnImage
        }
        else {
            flashButton.offImage = self.getMyImage(named: "flash-off")
            flashButton.onImage = self.getMyImage(named: "flash")
        }
        
        if cameraFlashState {
            flashButton.isOn = true
            self.flashState()
        }

        flashButton.addTarget(self, action: #selector(self.flashState), for:.touchUpInside)
        flashButton.isHidden = isHiddenIdPhotoFlashButton
    }
    
    private func initiateTakePhotoButton() {
        if self.buttonCameraActiveImage != nil && self.buttonCameraPassiveImage  != nil{
            self.takePhotoButton.setBackgroundImage(self.buttonCameraPassiveImage, for: .normal)
        }
        else {
            takePhotoButton.setBackgroundImage(self.getMyImage(named: "camera_button_off"), for: .normal)
        }
        takePhotoButton.setImage(nil, for: .normal)
        takePhotoButton.addTarget(self, action: #selector(self.analyzeCard), for:.touchUpInside)
        takePhotoButton.shapeButton()
        takePhotoButton.isEnabled = false
        takePhotoButton.isHidden = isHiddenIdPhotoCameraButton
    }
    
    // idPhoto view
    private func getStatementArea() -> CGRect {
        let scanArea = getTakePhotoButtonArea()
        let width: CGFloat = frame.width - 16
        let height: CGFloat = 24
        let size = CGSize(width: width, height: height)
        
        let y = scanArea.origin.y - scanArea.height - 28
        let titlePoint: CGPoint = CGPoint(x: frame.width/2 - width/2, y: y)
        
        return CGRect(origin: titlePoint, size: size)
    }
    
    private func getFlashButtonArea() -> CGRect {
        let height: CGFloat = 24.0
        let width: CGFloat = 24.0
        let point = CGPoint(x: frame.width - width - 20 , y: 75)
        let size = CGSize(width: width, height: height)
        
        return CGRect(origin: point, size: size)
    }
    
    private func getTakePhotoButtonArea() -> CGRect {
        let height: CGFloat = 70.0
        let width: CGFloat = 70.0
        let point = CGPoint(x: frame.width/2 - width/2, y: frame.height - height - 36.0)
        let size = CGSize(width: width, height: height)
        
        return CGRect(origin: point, size: size)
    }
    
    private func getSwitchCameraButtonArea() -> CGRect {
        let height: CGFloat = 24.0
        let width: CGFloat = 24.0
        
        let point = CGPoint(x: frame.width - width - 20 , y: 115)
        let size = CGSize(width: width, height: height)
        
        return CGRect(origin: point, size: size)
    }
    
    private func getUIImage(from ciImage: CIImage) -> UIImage {
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return UIImage() }
        return UIImage(cgImage: cgImage)
    }
    
    fileprivate func performVisionRequest(image: CGImage, orientation: CGImagePropertyOrientation) {
        
        // Fetch desired requests based on switch status.
        let requests = createVisionRequests()
        // Create a request handler.
        let imageRequestHandler = VNImageRequestHandler(cgImage: image,
                                                        orientation: orientation,
                                                        options: [:])
        try? imageRequestHandler.perform(requests)
        // Send the requests to the request handler.
        /*DispatchQueue.global(qos: .userInitiated).async {
         do {
         try imageRequestHandler.perform(requests)
         } catch let error as NSError {
         print("Failed to perform image request: \(error)")
         //self.presentAlert("Image Request Failed", error: error)
         return
         }
         }*/
    }
    
    /// - Tag: CreateRequests
    fileprivate func createVisionRequests() -> [VNRequest] {
        
        // Create an array to collect all desired requests.
        var requests: [VNRequest] = []
        if selectedViewType == .nfcRead &&
            sdkModel.autoCropped_idFrontImage != nil &&
            sdkModel.autoCropped_idBackImage != nil{
            return requests
        }
        else {
            requests.append(self.rectanglesRequest)
        }
        
        if selectedViewType == .idBackPhoto {
            //requests.append(self.rectanglesRequest)
            //if hasNfc{
            //    requests.append(self.mrzRequest)
            //}
            //else { checkMrz = true }
            
            // always read mrz inPhoto
            requests.append(self.mrzRequest)
        }
        requests.append(self.facesRequest)
        
        // Return grouped requests as a single array.
        return requests
    }
    
    //fileprivate
    private func handleRectanglesRequest(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation] else { return }
        guard let detectedRectangle = observations.first else { return }
        if inputCIImage == nil || inputCGImage == nil {return}
        
        if(captureImageStatus == 0) {
            DispatchQueue.main.async {
                self.checkRectangle = true
                self.updateScanArea()
            }
            return
        }
        
        let imageSize = inputCIImage!.extent.size
        
        let boundingBox = detectedRectangle.boundingBox.scaled(to: imageSize)
        //let topLeft = detectedRectangle.topLeft.scaled(to: imageSize)
        //let topRight = detectedRectangle.topRight.scaled(to: imageSize)
        //let bottomLeft = detectedRectangle.bottomLeft.scaled(to: imageSize)
        //let bottomRight = detectedRectangle.bottomRight.scaled(to: imageSize)
        
        let correctedImage = inputCIImage!
            .cropped(to: boundingBox)
        //.applyingFilter("CIPerspectiveCorrection", parameters: [
        //    "inputTopLeft": CIVector(cgPoint: topLeft),
        //    "inputTopRight": CIVector(cgPoint: topRight),
        //    "inputBottomLeft": CIVector(cgPoint: bottomLeft),
        //    "inputBottomRight": CIVector(cgPoint: bottomRight)
        //])
        
        let cgImage = CIContext.shared.createCGImage(correctedImage, from: correctedImage.extent)
        DispatchQueue.main.async {
            if cgImage != nil{
                if self.captureImageStatus == 1 {
                    self.sdkModel.autoCropped_idFrontImage = UIImage(cgImage: cgImage!)
                    self.sdkModel.base64_autoCropped_idFrontImage = self.sdkModel.autoCropped_idFrontImage?.toBase64(format: .png)
                    self.delegate?.didCaptureIdFrontPhoto(self, image: self.sdkModel.idFrontImage!, imageBase64: self.sdkModel.base64_idFrontImage!, cropImage: self.sdkModel.autoCropped_idFrontImage!, cropImageBase64: self.sdkModel.base64_autoCropped_idFrontImage!)
                    
                    self.sdkModel.idFrontFaceImage = self.capturedFace
                    self.sdkModel.base64_idFrontFaceImage = self.sdkModel.idFrontFaceImage?.toBase64(format: .png)
                    self.delegate?.didCaptureIdFrontFacePhoto(self, image: self.sdkModel.idFrontFaceImage!, imageBase64: self.sdkModel.base64_idFrontFaceImage!)
                    
                }else if self.captureImageStatus == 2 {
                    self.sdkModel.autoCropped_idBackImage = UIImage(cgImage: cgImage!)
                    self.sdkModel.base64_autoCropped_idBackImage = self.sdkModel.autoCropped_idBackImage?.toBase64(format: .png)
                    self.delegate?.didCaptureIdBackPhoto(self, image: self.sdkModel.idBackImage!, imageBase64: self.sdkModel.base64_idBackImage!, cropImage: self.sdkModel.autoCropped_idBackImage!, cropImageBase64: self.sdkModel.base64_autoCropped_idBackImage!)
                }
            }
        }
    }
    
    fileprivate func handleFacesRequest(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else { return }
        guard let detectedFace = observations.first else { return }
        if inputCIImage == nil || inputCGImage == nil {return}
        
        if(captureImageStatus == 0) {
            DispatchQueue.main.async {
                self.checkFace = true
                self.updateScanArea()
            }
            let imageSize = self.inputCIImage.extent.size
            let boundingBox = detectedFace.boundingBox.scaled(to: imageSize)
            let rect = CGRect(x: boundingBox.origin.x, y: boundingBox.origin.y  , width: boundingBox.width, height: boundingBox.height + 50)
            let correctedImage = self.inputCIImage.cropped(to: rect).oriented(forExifOrientation: Int32(CGImagePropertyOrientation.up.rawValue))
            DispatchQueue.main.async {
                //self.didDetectFaceImage(correctedImage, at: boundingBox)
                self.capturedFace = self.getUIImage(from: correctedImage)
            }
        }
    }
    
    fileprivate func handleMrzRequest(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNTextObservation] else { return }
        if inputCIImage == nil || inputCGImage == nil {return}
        
        if(captureImageStatus == 0 && !self.checkMrz) {
            
            let imageWidth = CGFloat(self.inputCGImage.width)
            let imageHeight = CGFloat(self.inputCGImage.height)
            let transform = CGAffineTransform.identity.scaledBy(x: imageWidth, y: -imageHeight).translatedBy(x: 0, y: -1)
            let mrzTextRectangles = observations.map({ $0.boundingBox.applying(transform) }).filter({ $0.width > (imageWidth * 0.8) })
            let mrzRegionRect = mrzTextRectangles.reduce(into: CGRect.null, { $0 = $0.union($1) })
            
            guard mrzRegionRect.height <= (imageHeight * 0.4) else { // Avoid processing the full image (can occur if there is a long text in the header)
                return
            }
            
            if let mrzTextImage = self.inputCGImage.cropping(to: mrzRegionRect) {
                if let mrzResult = self.mrz(from: mrzTextImage), mrzResult.allCheckDigitsValid {
                    if isMrzValid(mrzInfo: mrzResult) {
                        DispatchQueue.main.async {
                            self.checkMrz = true
                            self.updateScanArea()
                            
                            let enlargedDocumentImage = self.enlargedDocumentImage(from: self.inputCGImage)
                            let scanResult = QKMRZScanResult(mrzResult: mrzResult, documentImage: enlargedDocumentImage)
                            
                            self.sdkModel.mrzInfo = scanResult
                            self.capturedMrz = self.getUIImage(from: self.inputCIImage)
                            self.sdkModel.mrzImage = self.capturedMrz
                            
                            self.delegate?.didReadMrz(self, didRead: self.sdkModel.mrzInfo!)
                            let currentDateTime = Calendar.current.startOfDay(for: Date())
                        
                            let bDate = Calendar.current.startOfDay(for: scanResult.birthDate!)
                            let gre = NSCalendar(calendarIdentifier: .gregorian)!
                            let age = gre.components(.year, from: bDate, to: currentDateTime, options: [])
                            
                            if age.year! < 18{
                                self.mrz_18_youngerCheck = true
                                self.delegate?.didAgeControlOver18(status: false)
                                self.viewChange()
                            }
                            else {
                                self.delegate?.didAgeControlOver18(status: true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: MRZ
    fileprivate func isMrzValid(mrzInfo: QKMRZResult) -> Bool {
        var result = false
        if (mrzInfo.documentNumber.count >= 8 &&
                mrzInfo.birthDate != nil &&
                mrzInfo.birthDate?.toString().count == 6 &&
                mrzInfo.expiryDate != nil &&
                mrzInfo.expiryDate?.toString().count == 6) {
            
            let text = mrzInfo.documentNumber
            
            let firstCharDocumentNumber = text[0]
            let numberCharDocumentNumber = text[1..<3]
            let secondCharDocumentNumber = text[3]
            
            let dateOfBirth = Int(mrzInfo.birthDate!.toString()) ?? -1
            let dateOfExpiry = Int(mrzInfo.expiryDate!.toString()) ?? -1
            let serialNo = Int(numberCharDocumentNumber) ?? -1
            
            result = true
            if dateOfBirth == -1 || dateOfExpiry == -1 || serialNo == -1 {
                result = false
            }
            
            if !firstCharDocumentNumber.isLetter || !secondCharDocumentNumber.isLetter {
                result = false
            }
            //if (!Character.isLetter(firstCharDocumentNumber.toCharArray()[0]) || !Character.isLetter(secondCharDocumentNumber.toCharArray()[0]))
        }
        return result
    }
    
    fileprivate func mrz(from cgImage: CGImage) -> QKMRZResult? {
        let preprocess_cgImage = preprocessImage(cgImage)
        if preprocess_cgImage != nil {
            let mrzTextImage = UIImage(cgImage: preprocess_cgImage!)
            let recognizedString = try? tesseract.performOCR(on: mrzTextImage).get()
            
            if let string = recognizedString, let mrzLines = mrzLines(from: string) {
                return mrzParser.parse(mrzLines: mrzLines)
            }
        }
        return nil
    }
    
    fileprivate func mrzLines(from recognizedText: String) -> [String]? {
        let mrzString = recognizedText.replacingOccurrences(of: " ", with: "")
        var mrzLines = mrzString.components(separatedBy: "\n").filter({ !$0.isEmpty })
        
        // Remove garbage strings located at the beginning and at the end of the result
        if !mrzLines.isEmpty {
            let averageLineLength = (mrzLines.reduce(0, { $0 + $1.count }) / mrzLines.count)
            mrzLines = mrzLines.filter({ $0.count >= averageLineLength })
        }
        
        return mrzLines.isEmpty ? nil : mrzLines
    }
    
    fileprivate func preprocessImage(_ image: CGImage) -> CGImage? {
        var inputImage = CIImage(cgImage: image)
        let averageLuminance = inputImage.averageLuminance
        var exposure = 0.5
        let threshold = (1 - pow(1 - averageLuminance, 0.2))
        
        if averageLuminance > 0.8 {
            exposure -= ((averageLuminance - 0.5) * 2)
        }
        
        if averageLuminance < 0.35 {
            exposure += pow(2, (0.5 - averageLuminance))
        }
        
        inputImage = inputImage.applyingFilter("CIExposureAdjust", parameters: ["inputEV": exposure])
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 2])
            .applyingFilter("LuminanceThresholdFilter", parameters: ["inputThreshold": threshold])
        
        return CIContext.shared.createCGImage(inputImage, from: inputImage.extent)
    }
    
    @available(iOS 13, *)
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
        //let masterListURL = Bundle(for: SCSoftKycView.self).url(forResource: "CSCA_TR", withExtension: ".pem")
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
                return "IPhone'unuzu NFC özellikli bir Kimlik Kartının yakınında tutun."
            case .successfulRead:
                return "Kimlik Kartı Başarıyla okundu."
            case .readingDataGroupProgress( _, let progress):
                let progressString = self.handleProgress(percentualProgress: progress)
                return "Yükleniyor lütfen bekleyiniz...\n\(progressString)"
            case .authenticatingWithPassport(let progress):
                let progressString = self.handleProgress(percentualProgress: progress)
                return "Kimlik kartı doğrulama.....\n\n\(progressString)"
            case .error(let tagError):
                self.nfcErrorCount += 1
                
                switch tagError {
                case .TagNotValid:
                    return "TagNotValid"
                case .MoreThanOneTagFound:
                    return "TagNotValid"
                case .ConnectionError:
                    return "ConnectionError"
                case .InvalidMRZKey:
                    return "MRZ bilgisi geçersiz.Tekrar kimliğin arka yüzünü okutunuz."
                case .ResponseError(_, _, _):
                    return "ResponseError"
                case .UserCanceled:
                    self.nfcCancel = true
                    return ""
                case .UnexpectedError:
                    self.nfcCancel = true
                    return ""
                default:
                    return "Beklenmeyen bir hata oluşmuştur."
                }
            @unknown default:
                return "Beklenmeyen bir hata oluşmuştur."
            }
        }, completed: { (passport, error) in
            if let passport = passport {
                // All good, we got a passport
                DispatchQueue.main.async {
                    idCardUtil.passport = passport
                    self.sdkModel.nfcData = idCardUtil
                    self.delegate?.didReadNfc(self, didRead: idCardUtil)
                    self.getNextViewType()
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
    
    /*fileprivate func callResultScreen(_ idCardUtil:IDCardUtil){
        //sdkModel.nfcData = idCardUtil
        //performSegue(withIdentifier: "showResult", sender: self)
        //delegate?.didDetectSdkData(self, didDetect: sdkModel)
        
        if #available(iOS 13, *) {
            delegate?.didReadNfc(self, didRead: idCardUtil.passport!)
        } else {
            // Fallback on earlier versions
        }
        getNextViewType()
    }*/
    
    fileprivate func handleProgress(percentualProgress: Int) -> String {
        let p = (percentualProgress/20)
        let full = String(repeating: "🟢 ", count: p)
        let empty = String(repeating: "⚪️ ", count: 5-p)
        return "\(full)\(empty)"
    }
    
    fileprivate func getImageQuality(image : UIImage) -> CGFloat{
        return 1.0
    }
}

extension SCSoftKycView: AVCaptureVideoDataOutputSampleBufferDelegate  {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        //guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        //let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        //guard let cgImage = convertCIImageToCGImage(inputImage: ciImage) else { return }
        
        guard let cgImage = CMSampleBufferGetImageBuffer(sampleBuffer)?.cgImage else {return }
        if (selectedViewType == .idFrontPhoto || selectedViewType == .idBackPhoto) && cutoutRect != nil{
            self.inputCGImage = self.documentImage(from: cgImage) // cropped image
            self.inputCIImage = CIImage(cgImage: inputCGImage)
        }
        else if selectedViewType == .selfie  && cutoutSelfieRect != nil {
            self.inputCGImage = self.selfieImage(from: cgImage) // cropped image
            self.inputCIImage = CIImage(cgImage: inputCGImage)
        }else {
            self.inputCGImage = cgImage
        }
        
        if sdkModel.idFrontImage != nil && sdkModel.autoCropped_idFrontImage == nil {
            captureImageStatus = 1
            let cgImage = sdkModel.idFrontImage?.cgImage
            if cgImage != nil {
                self.inputCIImage = convertCGImageToCIImage(inputImage: cgImage!)
                self.inputCGImage = cgImage
            }
        }
        else if sdkModel.idBackImage != nil && sdkModel.autoCropped_idBackImage == nil {
            captureImageStatus = 2
            let cgImage = sdkModel.idBackImage?.cgImage
            if cgImage != nil {
                self.inputCIImage = convertCGImageToCIImage(inputImage: cgImage!)
                self.inputCGImage = cgImage
            }
        }
        else {
            captureImageStatus = 0
        }
        
        performVisionRequest(image: inputCGImage, orientation: .up)
    }
    
    func convertCGImageToCIImage(inputImage: CGImage) -> CIImage! {
        let ciImage = CIImage(cgImage: inputImage)
        return ciImage
    }
}

extension SCSoftKycView: JitsiMeetViewDelegate {
    public func conferenceJoined(_ data: [AnyHashable : Any]!) {
        print("conferenceJoined")
        inJitsi = true
    }
    
    public func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        print("conferenceTerminated")
        DispatchQueue.main.async {
            self.cleanUp()
        }
        inJitsi = false
    }
    
    public func participantLeft(_ data: [AnyHashable : Any]!) {
        print("participantLeft")
        cleanUp()
    }
    
    fileprivate func cleanUp() {
        jitsiMeetView.leave()
        jitsiMeetView.removeFromSuperview()
    }
    
    public func conferenceWillJoin(_ data: [AnyHashable : Any]!) {
        print("conferenceWillJoin")
    }
    
    fileprivate func openJitsiMeet(url : String, room : String, token : String) {
        let options = JitsiMeetConferenceOptions.fromBuilder { builder in
            //builder.serverURL = URL(string: self.url)
            //builder.room = self.room
            
            builder.serverURL = URL(string: url)
            builder.room = room
            builder.token = token
            
            builder.audioOnly = false
            builder.audioMuted = false
            builder.videoMuted = false
            builder.welcomePageEnabled = false
            
            builder.setFeatureFlag("add-people.enabled", withBoolean: false)
            builder.setFeatureFlag("invite.enabled", withBoolean: false)
            builder.setFeatureFlag("raise-hand.enabled", withBoolean: false)
            builder.setFeatureFlag("video-share.enabled", withBoolean: false)
            builder.setFeatureFlag("toolbox.alwaysVisible", withBoolean: false)
            builder.setFeatureFlag("toolbox.enabled", withBoolean: false)//
            builder.setFeatureFlag("live-streaming.enabled", withBoolean: false)
            builder.setFeatureFlag("chat.enabled", withBoolean: false)
            builder.setFeatureFlag("meeting-password.enabled", withBoolean: false)
            builder.setFeatureFlag("meeting-name.enabled", withBoolean: false)
            builder.setFeatureFlag("calendar.enabled", withBoolean: false)
            builder.setFeatureFlag("conference-timer.enabled", withBoolean: false)
            builder.setFeatureFlag("call-integration.enabled", withBoolean: false)
            builder.setFeatureFlag("close-captions.enabled", withBoolean: false)
            builder.setFeatureFlag("kick-out.enabled", withBoolean: false)
            builder.setFeatureFlag("meeting-name.enabled", withBoolean: false)
            builder.setFeatureFlag("pip.enabled", withBoolean: false)
            builder.setFeatureFlag("recording.enabled", withBoolean: false)
            builder.setFeatureFlag("resolution", withBoolean: false)
            builder.setFeatureFlag("server-url-change.enabled", withBoolean: false)
            builder.setFeatureFlag("tile-view.enabled", withBoolean: false)
        }
        
        let jitsiMeetView = JitsiMeetView()
        jitsiMeetView.delegate = self
        self.jitsiMeetView = jitsiMeetView
        jitsiMeetView.join(options)
    }
}
