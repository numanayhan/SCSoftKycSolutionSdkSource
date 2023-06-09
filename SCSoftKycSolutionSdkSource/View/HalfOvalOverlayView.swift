import UIKit

class HalfOvalOverlayView: UIView {
    
    //let screenBounds = UIScreen.main.bounds
    var overlayFrame: CGRect!
    var width : CGFloat = 306
    var height : CGFloat = 406
    override init(frame: CGRect) {
        super.init(frame: frame)
        //backgroundColor = UIColor.clear
        backgroundColor = UIColor.clear
        contentMode = .redraw
        //accessibilityIdentifier = "takeASelfieHalfOvalOverlayView"
    }
    
    fileprivate func calculateCutoutRect() -> CGRect {
        return CGRect(x: (bounds.width - width) / 2,
                      y: (bounds.height - height) / 2,
                      width: width,
                      height: height)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        overlayFrame = calculateCutoutRect()
        layer.sublayers?.removeAll()
        drawOvalCutout()
    }
    
    fileprivate func drawOvalCutout() {
        let maskLayer = CAShapeLayer()
        let path = CGMutablePath()
        
        path.addEllipse(in: overlayFrame)
        path.addRect(bounds)

        maskLayer.path = path
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd

        layer.mask = maskLayer
        
        //let overlayPath = UIBezierPath(rect: bounds)
        //overlayPath.append(ovalPath)
        //overlayPath.usesEvenOddFillRule = true
        // draw oval layer
        let ovalLayer = CAShapeLayer()
        ovalLayer.path =  UIBezierPath(ovalIn: overlayFrame).cgPath
        ovalLayer.fillColor = UIColor.clear.cgColor
        ovalLayer.strokeColor = UIColor.clear.cgColor
        ovalLayer.lineWidth = 8
        ovalLayer.frame = bounds
        // draw layer that fills the view
        //let fillLayer = CAShapeLayer()
        //fillLayer.path = overlayPath.cgPath
        //fillLayer.fillRule = CAShapeLayerFillRule.evenOdd
        //fillLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        // add layers
        //layer.addSublayer(fillLayer)
        
        /*let center = CGPoint(x: width / 2, y: height)
        let beizerPath = UIBezierPath()
        beizerPath.move(to: center)
        beizerPath.addArc(withCenter: center,
                    radius: 300 / 2,
                    startAngle: .pi,
                    endAngle: 2 * .pi,
                    clockwise: true)
        beizerPath.close()
        let innerGrayCircle = CAShapeLayer()
        innerGrayCircle.path = beizerPath.cgPath
        innerGrayCircle.fillColor = UIColor.gray.cgColor*/
        
        
        layer.addSublayer(ovalLayer)
        //layer.addSublayer(innerGrayCircle)
    }
    
}
