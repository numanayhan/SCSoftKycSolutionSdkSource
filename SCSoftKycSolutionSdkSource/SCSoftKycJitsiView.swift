import Foundation
import UIKit
import JitsiMeetSDK

public protocol SCSoftKycJitsiViewDelegate: AnyObject {
    
    //func didClose(_ kycView: SCSoftKycJitsiView)
    func didJitsiLeave()
}

@IBDesignable
public class SCSoftKycJitsiView: UIView {
    
    // Public variables
    
    public var buttonCloseImage : UIImage?
    public var isHiddenCloseButton = true
    
    public weak var delegate: SCSoftKycJitsiViewDelegate?
    private let closeButton = UIButton()
    
    // Jitsi config
    fileprivate var inJitsi : Bool = false
    fileprivate var jitsiMeetView: JitsiMeetView?
    
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
        setViewStyle()
    }
    
    fileprivate func setViewStyle() {
        backgroundColor = .clear
    }
    
    public func initiateScreen(url : String, room : String, token : String){
        self.initiateCloseButton()
        openJitsiMeet(url: url, room: room, token: token)
        
        add_removeJitsiView(isAdd: true)
        add_removeCloseButton(isAdd: true)
    }
    
    @objc private func closeButtonInput(){
        leaveJitsi()
    }
    
}

extension SCSoftKycJitsiView{
    
    fileprivate func add_removeJitsiView(isAdd : Bool){
        if jitsiMeetView != nil {
            if isAdd {
                addSubview(jitsiMeetView!)
                jitsiMeetView!.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    jitsiMeetView!.topAnchor.constraint(equalTo: topAnchor),
                    jitsiMeetView!.bottomAnchor.constraint(equalTo: bottomAnchor),
                    jitsiMeetView!.leftAnchor.constraint(equalTo: leftAnchor),
                    jitsiMeetView!.rightAnchor.constraint(equalTo: rightAnchor)
                ])
            }
            else{
                jitsiMeetView!.removeFromSuperview()
            }
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
    
    private func getMyImage(named : String) -> UIImage? {
        let bundle = Bundle(for: SCSoftKycJitsiView.self)
        return UIImage(named: named, in: bundle, compatibleWith: nil)
    }
}

extension SCSoftKycJitsiView: JitsiMeetViewDelegate {
    public func conferenceJoined(_ data: [AnyHashable : Any]!) {
        print("conferenceJoined")
        inJitsi = true
    }
    
    public func conferenceTerminated(_ data: [AnyHashable : Any]!) {
        print("conferenceTerminated")
        self.leaveJitsi()
        inJitsi = false
    }
    
    public func participantLeft(_ data: [AnyHashable : Any]!) {
        print("participantLeft")
        leaveJitsi()
    }
    
    public func leaveJitsi() {
        if jitsiMeetView != nil {
            jitsiMeetView!.leave()
            jitsiMeetView!.removeFromSuperview()
            jitsiMeetView = nil
            self.delegate?.didJitsiLeave()
        }
    }
    
    public func conferenceWillJoin(_ data: [AnyHashable : Any]!) {
        print("conferenceWillJoin")
    }
    
    fileprivate func openJitsiMeet(url : String, room : String, token : String) {
        let options = JitsiMeetConferenceOptions.fromBuilder { builder in
            
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
            //builder.setFeatureFlag("toolbox.enabled", withBoolean: false)//
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
            //builder.setFeatureFlag("resolution", withBoolean: false)
            builder.setFeatureFlag("resolution", withValue: 360)
            builder.setFeatureFlag("server-url-change.enabled", withBoolean: false)
            builder.setFeatureFlag("tile-view.enabled", withBoolean: false)
        }
        
        let jitsiMeetView = JitsiMeetView()
        jitsiMeetView.delegate = self
        self.jitsiMeetView = jitsiMeetView
        jitsiMeetView.join(options)
    }
}
