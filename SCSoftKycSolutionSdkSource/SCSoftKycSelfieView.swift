import Foundation
import UIKit
import AVFoundation
import Vision

public protocol SCSoftKycSelfieViewDelegate: AnyObject {
    
    func didCaptureSelfiePhoto(_ kycView : SCSoftKycSelfieView, image : UIImage , imageBase64 : String, cropImage : UIImage , cropImageBase64 : String)
    
    func didClose(_ kycView: SCSoftKycSelfieView)
    
}

@IBDesignable
public class SCSoftKycSelfieView: UIView {
    
    // Public variables
    
    public var labelTextColor = UIColor.white
    public var labelFont = UIFont.boldSystemFont(ofSize: 16)
    
    public var buttonBackgroundColor = UIColor(red: 27.0 / 255.0, green: 170.0 / 255.0, blue: 194.0 / 255.0, alpha: 1.0)
    public var buttonTitleColor = UIColor.white
    public var buttonFont = UIFont.systemFont(ofSize: 17.0, weight: .semibold)
    public var buttonRadius : CGFloat = 8
    
    public var activeColor = UIColor(red: 27.0 / 255.0, green: 170.0 / 255.0, blue: 194.0 / 255.0, alpha: 1.0)
    public var passiveColor = UIColor.white
    
    public var buttonCameraActiveImage : UIImage?
    public var buttonCameraPassiveImage : UIImage?
    public var buttonCloseImage : UIImage?
    
    public var isHiddenIdPhotoCameraButton = false
    public var isHiddenCloseButton = true
    
    public weak var delegate: SCSoftKycSelfieViewDelegate?
    //public var _viewTypes = [ViewType]()
    
    //Video Capture
    private var bufferSize: CGSize = .zero
    private let videoDataOutputQueue = DispatchQueue(label: "videoDataOutputQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    private var captureSession = AVCaptureSession()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var videoPreviewLayer = AVCaptureVideoPreviewLayer()
    
    //View outlets
    private let takePhotoButton = CircleButton()
    private let cutoutSelfieView = OvalOverlayView()
    private var informationLabel = StatementLabel()
    private let informationNextButton = UIButton()
    private let closeButton = UIButton()
    //private var flipImageView = UIImageView()
    
    private var sdkModel = SCSoftKycModel()
    private var isFinish = false
    //private var isFront = true
    private var checkFace = false
    
    private var frontCamera : AVCaptureDevice?
    private var frontInput : AVCaptureInput!
    
    fileprivate var observer: NSKeyValueObservation?
    @objc fileprivate dynamic var isScanning = false
    fileprivate var isScanningPaused = false
    
    //Capture result
    //private var capturedImage: UIImage!
    private var capturedFace: UIImage!
    
    fileprivate var inputCIImage: CIImage!
    fileprivate var inputCGImage: CGImage!
    
    private var refreshTimer: Timer?
    
    private var noCameraText = ""
    
    fileprivate var cutoutSelfieRect: CGRect? {
        return cutoutSelfieView.overlayFrame
    }
    
    private lazy var facesRequest: VNDetectFaceRectanglesRequest = {
        return VNDetectFaceRectanglesRequest(completionHandler: self.handleFacesRequest)
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
    func initialize() {
        FilterVendor.registerFilters()
        
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
        updateScanArea()
    }
    
    private func initiateScreen(){
        //DispatchQueue.main.async {
        self.initiateTakePhotoButton()
        self.initiateInformationNextButton(stateIsEnd: true)
        self.initiateCloseButton()
        self.viewChange()
    
    }
    
    private func updateScanArea() {
        var found = false
        
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
    
    public func getMyImage(named : String) -> UIImage? {
        let bundle = Bundle(for: SCSoftKycSelfieView.self)
        return UIImage(named: named, in: bundle, compatibleWith: nil)
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
        captureSession.addInput(frontInput)
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
        // REMOVE VIEW
        //idPhoto
        add_removeInformationView(isAdd: false)
        //add_removeFlipImageView(isAdd: false)
        add_removeCloseButton(isAdd: false)
        
        //share camera view
        add_removeTakePhotoButton(isAdd: false)
        
        //selfie
        add_removeCutoutSelfieView(isAdd: false)
        
        if !noCameraText.isEmpty && frontCamera == nil{
            initiateInformationLabel(text: "Cihazınızda ön kamera bulunmamaktadır. Devam butonuna basarak sürece devam edebilirsiniz.")
            add_removeInformationView(isAdd: true)
            add_removeCloseButton(isAdd: true)
            return
        }
        
        if isFinish {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
                self.delegate?.didClose(self)
            }
            //initiateInformationLabel(text: "Süreç tamamlanmıştır.")
            //initiateInformationNextButton(stateIsEnd: true)
            //add_removeInformationView(isAdd: true)
            //add_removeCloseButton(isAdd: true)
            //closeButtonInput()
            return
        }
        
        // ADD VIEW
        //share camera view
        layer.addSublayer(videoPreviewLayer)
        add_removeCutoutSelfieView(isAdd: true)
        add_removeTakePhotoButton(isAdd: true)
        add_removeCloseButton(isAdd: true)
    }
    
    public func showSelfieView(){
        sdkModel.selfieImage = nil
        sdkModel.autoCropped_selfieImage = nil
        
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
        
        
        sdkModel.selfieImage = UIImage(cgImage: self.inputCGImage)
        sdkModel.autoCropped_selfieImage = self.capturedFace
        sdkModel.base64_selfieImage =  sdkModel.selfieImage?.toBase64(format: .png)
        sdkModel.base64_autoCropped_selfieImage = sdkModel.autoCropped_selfieImage?.toBase64(format: .png)
        //self.delegate?.didDetectSdkData(self, didDetect: sdkModel)
        self.delegate?.didCaptureSelfiePhoto(self, image: sdkModel.selfieImage!, imageBase64: sdkModel.base64_selfieImage!, cropImage: sdkModel.autoCropped_selfieImage!, cropImageBase64: sdkModel.base64_autoCropped_selfieImage!)
        //getNextViewType()
        
    }
    
}

extension SCSoftKycSelfieView{
    
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
        informationNextButton.addTarget(self, action: #selector(self.closeButtonInput), for:.touchUpInside)
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
        requests.append(self.facesRequest)
        
        // Return grouped requests as a single array.
        return requests
    }
    
    fileprivate func handleFacesRequest(request: VNRequest, error: Error?) {
        guard let observations = request.results as? [VNFaceObservation] else { return }
        guard let detectedFace = observations.first else { return }
        if inputCIImage == nil || inputCGImage == nil {return}
        
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

extension SCSoftKycSelfieView: AVCaptureVideoDataOutputSampleBufferDelegate  {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let cgImage = CMSampleBufferGetImageBuffer(sampleBuffer)?.cgImage else {return }
        if cutoutSelfieRect != nil {
            self.inputCGImage = self.selfieImage(from: cgImage) // cropped image
            self.inputCIImage = CIImage(cgImage: inputCGImage)
        }else {
            self.inputCGImage = cgImage
        }
        
        performVisionRequest(image: inputCGImage, orientation: .up)
    }
    
    func convertCGImageToCIImage(inputImage: CGImage) -> CIImage! {
        let ciImage = CIImage(cgImage: inputImage)
        return ciImage
    }
}
