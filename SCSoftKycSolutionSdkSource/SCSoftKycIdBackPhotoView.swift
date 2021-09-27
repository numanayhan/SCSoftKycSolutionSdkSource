import Foundation
import UIKit
import AVFoundation
import Vision
import SwiftyTesseract

public protocol SCSoftKycIdBackPhotoViewDelegate: AnyObject {
    
    func didCaptureIdBackPhoto(_ kycView : SCSoftKycIdBackPhotoView, image : UIImage , imageBase64 : String, cropImage : UIImage , cropImageBase64 : String)
    
    func didClose(_ kycView: SCSoftKycIdBackPhotoView)
    
    func didAgeControlOver18(status : Bool)
    
    func didReadMrz(_ kycView : SCSoftKycIdBackPhotoView, didRead mrzInformation : SCSoftKycMRZInformation)
    
}

@IBDesignable
public class SCSoftKycIdBackPhotoView: UIView {
    
    // Public variables
    
    public var infoIdBackText = "Kimlik kartınızın arka yüzünü belirtilen kare içerisine alarak fotoğraf çekme butonuna basınız."
    public var autoTakePhoto = true
    private var autoTakePhotoCounter = 1
    public var activeColor = UIColor(red: 27.0 / 255.0, green: 170.0 / 255.0, blue: 194.0 / 255.0, alpha: 1.0)
    public var passiveColor = UIColor.white
    public var buttonBackgroundColor = UIColor(red: 27.0 / 255.0, green: 170.0 / 255.0, blue: 194.0 / 255.0, alpha: 1.0)
    public var buttonTitleColor = UIColor.white
    public var buttonFont = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
    public var buttonRadius : CGFloat = 8
    
    public var labelTextColor = UIColor.white
    public var labelFont = UIFont.boldSystemFont(ofSize: 16)
    
    public var buttonCameraActiveImage : UIImage?
    public var buttonCameraPassiveImage : UIImage?
    public var buttonCloseImage : UIImage?
    public var buttonFlashOnImage : UIImage?
    public var buttonFlashOffImage : UIImage?
    public var cameraFlashState = false
    
    public var isHiddenIdPhotoInfo = false
    public var isHiddenIdPhotoCameraButton = false
    public var isHiddenIdPhotoFlashButton = false
    public var isHiddenCloseButton = true
    
    public weak var delegate: SCSoftKycIdBackPhotoViewDelegate?
    
    var mrz_18_youngerCheck = false
    //Video Capture
    private var bufferSize: CGSize = .zero
    private let videoDataOutputQueue = DispatchQueue(label: "videoDataOutputQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var captureSession = AVCaptureSession()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    //View outlets
    private let takePhotoButton = CircleButton()
    private let cutoutView = QKCutoutView()
    private var idPhotoLabel = StatementLabel()
    private let flashButton = ToggleButton()
    private var mrzAreaLabel = UILabel()
    private var informationLabel = StatementLabel()
    private let informationNextButton = UIButton()
    private let closeButton = UIButton()
    
    private var sdkModel = SCSoftKycModel()
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
    
    private var capturedFace: UIImage!
    private var capturedMrz: UIImage!
    
    fileprivate let tesseract = SwiftyTesseract(language: .custom("ocrb"), dataSource: Bundle(for: SCSoftKycIdBackPhotoView.self), engineMode: .tesseractOnly)
    fileprivate let mrzParser = QKMRZParser(ocrCorrection: true)
    
    fileprivate var inputCIImage: CIImage!
    fileprivate var inputCGImage: CGImage!
    
    private var refreshTimer: Timer?
    
    private var noCameraText = ""
    
    fileprivate var cutoutRect: CGRect? {
        return cutoutView.cutoutRect
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
    private func initialize() {
        FilterVendor.registerFilters()
        
        setupAndStartCaptureSession()
        setViewStyle()
        //initiateScreen()
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
    
    public func initiateScreen(){
        //DispatchQueue.main.async {
        self.initiateStatement()
        self.initiateFlashButton()
        self.initiateTakePhotoButton()
        self.initiateInformationNextButton()
        self.initiateCloseButton()
        self.viewChange()
        
        //}
        refreshTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
    }
    
    private func updateScanArea() {
        var found = false
        
        if checkRectangle && checkMrz && !checkFace && self.inputCGImage != nil && self.sdkModel.autoCropped_idBackImage != nil{
            found = true
        }
        
        DispatchQueue.main.async {
            if found && self.autoTakePhoto {
                if self.autoTakePhotoCounter % 3 == 0{
                    self.analyzeCard()
                    self.autoTakePhoto = false
                }
                self.autoTakePhotoCounter += 1
            }
            
            let selectedColor = (found) ? self.activeColor.cgColor : self.passiveColor.cgColor
            (self.cutoutView.layer.sublayers?.first as? CAShapeLayer)?.strokeColor = selectedColor
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
            
            self.mrzAreaLabel.textColor = UIColor(cgColor: selectedColor)
        }
    }
    
    public func getMyImage(named : String) -> UIImage? {
        let bundle = Bundle(for: SCSoftKycIdBackPhotoView.self)
        return UIImage(named: named, in: bundle, compatibleWith: nil)
    }
    
    // MARK: Document Image from Photo cropping
    fileprivate func cutoutRect(for cgImage: CGImage) -> CGRect {
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        let rect = videoPreviewLayer.metadataOutputRectConverted(fromLayerRect: cutoutRect!)
        
        if videoPreviewLayer.connection == nil {
            return CGRect(x: (rect.minY * imageWidth), y: (rect.minX * imageHeight), width: (rect.height * imageWidth), height: (rect.width * imageHeight))
        }
        
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
    
    fileprivate func viewChange(){
        if !noCameraText.isEmpty && backCamera == nil {
            initiateInformationLabel(text: "Cihazınızda arka kamera bulunmamaktadır.")
            add_removeInformationView(isAdd: true)
            add_removeCloseButton(isAdd: true)
            return
        }
        
        layer.addSublayer(videoPreviewLayer)
        
        add_removeCutoutView(isAdd: true)
        add_removeTakePhotoButton(isAdd: true)
        add_removeFlashButton(isAdd: true)
        add_removeIdPhotoLabel(isAdd: true)
        
        idPhotoLabel.shape(infoIdBackText, font: labelFont)
        idPhotoLabel.textColor = labelTextColor
        add_removeCloseButton(isAdd: true)
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if self.cutoutRect != nil {
                timer.invalidate()
                self.initiateMrzArea()
            }
        }
    }
    
    public func refreshData(){
        sdkModel.idBackImage = nil
        sdkModel.base64_idBackImage = nil
        sdkModel.autoCropped_idBackImage = nil
        sdkModel.base64_autoCropped_idBackImage = nil
        sdkModel.mrzInformation = nil
        checkMrz = false
    }
    
    @objc private func closeButtonInput(){
        refreshTimer?.invalidate()
        self.delegate?.didClose(self)
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
        
        //isFront = true
        sdkModel.idBackImage = UIImage(cgImage: self.inputCGImage)
        //sdkModel.autoCropped_idBackImage = self.capturedImage
        sdkModel.base64_idBackImage =  sdkModel.idBackImage?.toBase64(format: .png)
        //self.delegate?.didDetectSdkData(self, didDetect: sdkModel)
        //getNextViewType()
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
            self.delegate?.didCaptureIdBackPhoto(self, image: self.sdkModel.idBackImage!, imageBase64: self.sdkModel.base64_idBackImage!, cropImage: self.sdkModel.autoCropped_idBackImage!, cropImageBase64: self.sdkModel.base64_autoCropped_idBackImage!)
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
}

extension SCSoftKycIdBackPhotoView{
    
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
    
    //TODO
    private func initiateInformationNextButton() {
        let text = "Çıkış"
        informationNextButton.addTarget(self, action: #selector(self.closeButtonInput), for:.touchUpInside)
        
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
    
    fileprivate func initiateMrzArea() {
        print("initiateMrzArea")
        mrzAreaLabel.numberOfLines = 3
        let text = "<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<"
        mrzAreaLabel.textColor = labelTextColor
        mrzAreaLabel.text = text
        //mrzAreaLabel.isHidden = false
        let customfont = UIFont.boldSystemFont(ofSize: 18)
        mrzAreaLabel.font = customfont
        mrzAreaLabel.lineBreakMode = .byCharWrapping
        
        let calculateRect = cutoutRect!
        let width = calculateRect.width - 20
        let height = calculateRect.height
        
        let heightLabel = heightForView(text: text, font: customfont, width: width)
        
        let x = (calculateRect.origin.x) + 10
        let y = (calculateRect.origin.y) + height - heightLabel-10
        
        mrzAreaLabel.frame = CGRect(x: x, y: y, width: width, height: heightLabel)
        
        addSubview(mrzAreaLabel)
        //mrzAreaLabel.isHidden = false
    }//
    
    func heightForView(text:String, font:UIFont, width:CGFloat) -> CGFloat {
        let label:UILabel = UILabel(frame: CGRect(x: 0, y: 0, width: width, height: CGFloat.greatestFiniteMagnitude))
        label.numberOfLines = 3
        label.lineBreakMode = NSLineBreakMode.byWordWrapping
        label.font = font
        label.text = text
        
        label.sizeToFit()
        return label.frame.height
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
    
    private func initiateStatement() {
        idPhotoLabel.numberOfLines = 0
        idPhotoLabel.isHidden = isHiddenIdPhotoInfo
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
        requests.append(self.rectanglesRequest)
        requests.append(self.mrzRequest)
        requests.append(self.facesRequest)
        
        // Return grouped requests as a single array.
        return requests
    }
    
    //fileprivate
    private func handleRectanglesRequest(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNRectangleObservation] else { return }
        guard let detectedRectangle = observations.first else { return }
        if inputCIImage == nil || inputCGImage == nil {return}
        
        
        self.checkRectangle = true
        self.updateScanArea()
        
        
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
                self.sdkModel.autoCropped_idBackImage = UIImage(cgImage: cgImage!)
                self.sdkModel.base64_autoCropped_idBackImage = self.sdkModel.autoCropped_idBackImage?.toBase64(format: .png)
            }
        }
    }
    
    fileprivate func handleFacesRequest(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else { return }
        guard let detectedFace = observations.first else { return }
        if inputCIImage == nil || inputCGImage == nil {return}
        
        
        self.checkFace = true
        self.updateScanArea()
        
        let imageSize = self.inputCIImage.extent.size
        let boundingBox = detectedFace.boundingBox.scaled(to: imageSize)
        let rect = CGRect(x: boundingBox.origin.x, y: boundingBox.origin.y  , width: boundingBox.width, height: boundingBox.height + 50)
        let correctedImage = self.inputCIImage.cropped(to: rect).oriented(forExifOrientation: Int32(CGImagePropertyOrientation.up.rawValue))
        DispatchQueue.main.async {
            //self.didDetectFaceImage(correctedImage, at: boundingBox)
            self.capturedFace = self.getUIImage(from: correctedImage)
        }
        
    }
    
    fileprivate func handleMrzRequest(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNTextObservation] else { return }
        if inputCIImage == nil || inputCGImage == nil {return}
        
        if(!self.checkMrz) {
            
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
                    if self.isMrzValid(mrzInfo: mrzResult) {
                        DispatchQueue.main.async {
                            self.checkMrz = true
                            self.updateScanArea()
                            
                            let enlargedDocumentImage = self.enlargedDocumentImage(from: self.inputCGImage)
                            let scanResult = QKMRZScanResult(mrzResult: mrzResult, documentImage: enlargedDocumentImage)
                            
                            self.sdkModel.mrzInformation = self.setMRZInfo(scanResult: scanResult)
                            self.capturedMrz = self.getUIImage(from: self.inputCIImage)
                            self.sdkModel.mrzImage = self.capturedMrz
                            
                            self.delegate?.didReadMrz(self, didRead: self.sdkModel.mrzInformation!)
                            let currentDateTime = Calendar.current.startOfDay(for: Date())
                            
                            let bDate = Calendar.current.startOfDay(for: scanResult.birthDate!)
                            let gre = NSCalendar(calendarIdentifier: .gregorian)!
                            let age = gre.components(.year, from: bDate, to: currentDateTime, options: [])
                            
                            if age.year! < 18{
                                self.mrz_18_youngerCheck = true
                                self.delegate?.didAgeControlOver18(status: false)
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
    
    func setMRZInfo(scanResult : QKMRZScanResult) -> SCSoftKycMRZInformation{
        let mrzInformation = SCSoftKycMRZInformation()
        
        mrzInformation.birthDate = scanResult.birthDate?.toString()
        mrzInformation.expiryDate = scanResult.expiryDate?.toString()
        mrzInformation.documentNumber = scanResult.documentNumber
        mrzInformation.documentType = scanResult.documentType
        mrzInformation.countryCode = scanResult.countryCode
        mrzInformation.surnames = scanResult.surnames
        mrzInformation.givenNames = scanResult.givenNames
        mrzInformation.nationality = scanResult.nationality
        mrzInformation.gender = scanResult.sex
        mrzInformation.personalNumber = scanResult.personalNumber
        mrzInformation.personalNumber2 = scanResult.personalNumber2
        
        return mrzInformation
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
}

extension SCSoftKycIdBackPhotoView: AVCaptureVideoDataOutputSampleBufferDelegate  {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        //guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        //let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        //guard let cgImage = convertCIImageToCGImage(inputImage: ciImage) else { return }
        
        guard let cgImage = CMSampleBufferGetImageBuffer(sampleBuffer)?.cgImage else {return }
        if cutoutRect != nil{
            self.inputCGImage = self.documentImage(from: cgImage) // cropped image
            self.inputCIImage = CIImage(cgImage: inputCGImage)
        }
        else {
            self.inputCGImage = cgImage
        }
        
        if sdkModel.idBackImage != nil && sdkModel.autoCropped_idBackImage == nil {
            let cgImage = sdkModel.idBackImage?.cgImage
            if cgImage != nil {
                self.inputCIImage = convertCGImageToCIImage(inputImage: cgImage!)
                self.inputCGImage = cgImage
            }
        }
        
        performVisionRequest(image: inputCGImage, orientation: .up)
    }
    
    func convertCGImageToCIImage(inputImage: CGImage) -> CIImage! {
        let ciImage = CIImage(cgImage: inputImage)
        return ciImage
    }
}
