//
//  FirstViewController.swift
//  kanji_recognizer
//
//  Created by Ryo Fujii on 2019/05/29.
//  Copyright © 2019 Ryo Fujii. All rights reserved.
//

import UIKit
import SwiftyJSON
import Alamofire

extension UIColor {
    class var osColorBlue: UIColor {
        return UIColor(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 0.8)
    }
    class var osColorRed: UIColor {
        return UIColor(red: 1.0, green: 59.0/255.0, blue: 48.0/255.0, alpha: 0.8)
    }
}

extension UIImage {
    func resizeImage(width: CGFloat, height: CGFloat) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        let resizedImage: UIImage! = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
}

enum ButtonMode {
    case Undo, Clear
    var displayedLabel: String {
        get {
            switch self {
            case .Undo:
                return "Undo"
            case .Clear:
                return "Clear"
            }
        }
    }
}

class CharReader: UIViewController {

    @IBOutlet weak var kanjiCanvas: UIView!
    
    @IBOutlet weak var goButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    
    @IBOutlet weak var gridSwitch: UISwitch!
    
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet var resultButtons: [UIButton]!
    
    // layers for drawing
    var drawPath: UIBezierPath!
    var shapeLayer: CAShapeLayer!
    var addedLayers = [CAShapeLayer]()
    
    var gridLayer = CAShapeLayer()
    
    // settings for clear/undo button
    var clearButtonMode: ButtonMode = .Clear
    var lastTimeDrawn = CFAbsoluteTime()
    
    var clipX: (minX: CGFloat, maxX: CGFloat) = (CGFloat.greatestFiniteMagnitude, 0.0)
    var clipY: (minY: CGFloat, maxY: CGFloat) = (CGFloat.greatestFiniteMagnitude, 0.0)
    
    let nbest = 6
    
    // settings for cloud vision API
    // let googleAPIKey = KeyManager().getValue(key: "googleAPI") as! String
    // var googleURL: URL {
    //      return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    //}
    
    @IBAction func drawKanji(_ sender: UIPanGestureRecognizer) {
        let loc = sender.location(in: sender.view)
        lastTimeDrawn = CFAbsoluteTimeGetCurrent()
        clipX = (min(clipX.minX, max(loc.x, 0)), max(clipX.maxX, min(loc.x, sender.view!.frame.maxX)))
        clipY = (min(clipY.minY, max(loc.y, 0)), max(clipY.maxY, min(loc.y, sender.view!.frame.maxY)))
        
        if sender.state == .began {
            drawPath = UIBezierPath()
            drawPath.move(to: loc)
            
            shapeLayer = CAShapeLayer()
            shapeLayer.strokeColor = UIColor.black.cgColor
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineWidth = 4.0
            sender.view?.layer.addSublayer(shapeLayer)
            self.addedLayers.append(shapeLayer)
        } else if sender.state == .changed {
            drawPath.addLine(to: loc)
            shapeLayer.path = drawPath.cgPath
        }
    }
    
    func setupCanvas(_ view: UIView) {
        // initial settings for canvas
        view.backgroundColor = .white
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.borderWidth = 2.0
        
        // to avoid going out of drawing area
        view.clipsToBounds = true
    }
    
    @IBAction func clearCanvas(_ sender: UIButton) {
        if clearButtonMode == .Clear {
            self.addedLayers.forEach {layer in
                layer.removeFromSuperlayer()
            }
            resultLabel.isHidden = true
            for button in resultButtons {
                button.isHidden = true
            // initialize clipping area again
            clipX = (CGFloat.greatestFiniteMagnitude, 0.0)
            clipY = (CGFloat.greatestFiniteMagnitude, 0.0)
            }
        } else {
            // To avoid turning back to clear button while pushing undo in a row
            lastTimeDrawn = CFAbsoluteTimeGetCurrent()
            guard let lastLayer =  self.addedLayers.popLast() else {
                return
            }
            lastLayer.removeFromSuperlayer()
        }
    }
    
    @objc func changeButtonMode() {
        let timediff = CFAbsoluteTimeGetCurrent() - lastTimeDrawn
        if timediff >= 5.0 {
            clearButtonMode = .Clear
        } else {
            clearButtonMode = .Undo
        }
        clearButton.setTitle(clearButtonMode.displayedLabel, for: .normal)
    }
    
    @IBAction func showGrid(_ sender: UISwitch) {
        gridLayer.isHidden = !gridSwitch.isOn
    }
    
    func setupGrid(_ view: UIView){
        let canvas = view
        let gridPath = UIBezierPath()
        gridPath.move(to: self.view.convert(CGPoint(x: canvas.frame.midX, y: canvas.frame.minY), to: canvas))
        gridPath.addLine(to: self.view.convert(CGPoint(x: canvas.frame.midX, y: canvas.frame.maxY), to: canvas))
        gridPath.move(to: self.view.convert(CGPoint(x: canvas.frame.minX, y: canvas.frame.midY), to: canvas))
        gridPath.addLine(to: self.view.convert(CGPoint(x: canvas.frame.maxX, y: canvas.frame.midY), to: canvas))
        
        gridLayer = CAShapeLayer()
        gridLayer.strokeColor = UIColor.lightGray.cgColor
        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.path = gridPath.cgPath
            
        canvas.layer.addSublayer(gridLayer)
    }
    
    func clipImage(_ image: UIImage, clipArea: CGRect) -> UIImage {
        let clippedImage = UIImage(cgImage: (image.cgImage!.cropping(to: clipArea))!, scale: image.scale, orientation: image.imageOrientation)
        return clippedImage
    }
    
    func getImage(_ view : UIView) -> UIImage {
        
        let clipWidth = max(clipX.maxX - clipX.minX, clipY.maxY - clipY.minY)
        let origin = CGPoint(x: max(clipX.maxX - (clipWidth + 40.0), 0), y: max(clipY.maxY - (clipWidth + 40.0), 0))
        
        let rect = view.bounds
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()!
        
        // view内の描画をcontextに複写する
        view.layer.borderColor = UIColor.clear.cgColor
        view.layer.render(in: context)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        view.layer.borderColor = UIColor.lightGray.cgColor
        
        UIGraphicsEndImageContext()
        
        // what if clipped area goes outside the canvas?
        let clippedImage = clipImage(image!, clipArea: CGRect(origin: origin, size: CGSize(width: clipWidth + 2 * 40.0, height: clipWidth + 2 * 40.0)))
        return clippedImage.resizeImage(width: 28.0, height: 28.0)
    }
    
    func detectCharFromImage(_ image: UIImage) {
        // 画像をbase64encode
        if let base64EncodedImage: String = image.pngData()?.base64EncodedString() {
            let request: Parameters = ["data": base64EncodedImage]
            
            Alamofire.request("http://localhost:2036/post", method: .post, parameters: request).responseJSON {response in
                switch response.result {
                case .success:
                    self.showResult(response: response)
                case .failure:
                    return
                }
            }
        }
    }
    
    func showResult(response: DataResponse<Any>) {
        guard let result = response.result.value else {
            return
        }
        let json = JSON(result)
        for entry in json {
            let rank = Int(entry.0)!
            let cls = entry.1["cls"].string!
            if rank < nbest {
                resultButtons[rank].setTitle(cls, for: .normal)
                UIView.transition(with: self.view, duration: 0.5, options: UIView.AnimationOptions(), animations: { self.resultButtons[rank].isHidden = false }, completion: nil)
            }
        }
    }

// uncomment when using API
//    func detectCharFromImageAPI(_ image: UIImage) {
//        // 画像をbase64encode
//        if let base64EncodedImage: String = image.pngData()?.base64EncodedString() {
//            // query
//            // 文字検出のためのtype -> TEXT_DETECTION
//            let request: Parameters = [
//                "requests": [
//                    "image": [
//                        "content": base64EncodedImage
//                    ],
//                    "features": [
//                        [
//                            "type": "DOCUMENT_TEXT_DETECTION",
//                            "maxResults": 6
//                        ]
//                    ]
//                ]
//            ]
//
//            let httpHeader: HTTPHeaders = [
//                "Content-Type": "application/json",
//                "X-Ios-Bundle-Identifier": Bundle.main.bundleIdentifier!
//            ]
//        Alamofire.request("https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)", method: .post, parameters: request, encoding: JSONEncoding.default, headers: httpHeader).validate(statusCode: 200..<300).responseJSON { response in
//            // 受け取ったレスポンスの後処理
//            self.showResultAPI(response: response)
//            }
//        }
//    }
    
//    func showResultAPI(response: DataResponse<Any>) {
//        guard let result = response.result.value else {
//            return
//        }
//        let json = JSON(result)
//        let annotations: JSON = json["responses"][0]["textAnnotations"]
//        let numAnnos = annotations.count
//
//        if numAnnos > 0 {
//            resultLabel.isHidden = false
//        }
//
//        for i in 0 ..< resultButtons.count {
//            if i < numAnnos {
//            //結果からdescriptionを取り出して一つの文字列にする
//                var detectedText: String = ""
//                detectedText = annotations[i]["description"].string!
//                // 結果を表示
//                resultButtons[i].setTitle(detectedText, for: .normal)
//
//                UIView.transition(with: self.view, duration: 0.5, options: UIView.AnimationOptions(), animations: {
//                    self.resultButtons[i].isHidden = false
//                }, completion: nil)
//            } else {
//                resultButtons[i].isHidden = true
//            }
//        }
//    }
    
    @IBAction func sendImage(_ sender: UIButton) {
        gridLayer.isHidden = true
        let image : UIImage = getImage(self.kanjiCanvas)
        // uncomment if using API
        // self.detectCharFromImageAPI(image)
        self.detectCharFromImage(image)
        gridLayer.isHidden = !gridSwitch.isOn
        
        // カメラロールに保存する
        // UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.didFinishSavingImage(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    // カメラロールへの保存の結果
//    @objc func didFinishSavingImage(_ image: UIImage, didFinishSavingWithError error: NSError!, contextInfo: UnsafeMutableRawPointer) {
//
//        // 結果によって出すアラートを変更
//        var title = "保存完了"
//        var message = "カメラロールに保存しました"
//
//        if error != nil {
//            title = "エラー"
//            message = "保存に失敗しました"
//        }
//
//        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
//        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
//        self.present(alertController, animated: true, completion: nil)
//    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.view.backgroundColor = UIColor(patternImage: UIImage(named: "table")!)
        
        setupCanvas(kanjiCanvas)
        setupGrid(kanjiCanvas)
        gridLayer.isHidden = !gridSwitch.isOn
        
        // button settings
        goButton.backgroundColor = .osColorBlue
        goButton.setTitleColor(.white, for: .normal)
        goButton.layer.cornerRadius = 5.0
        goButton.clipsToBounds = true
        
        clearButton.backgroundColor = .osColorRed
        clearButton.setTitleColor(.white, for: .normal)
        clearButton.layer.cornerRadius = 5.0
        clearButton.clipsToBounds = true
        
        // hide suggestion area
        resultLabel.isHidden = true
        for button in resultButtons {
            button.backgroundColor = .lightGray
            button.alpha = 0.8
            button.layer.cornerRadius = 5.0
            button.clipsToBounds = true
            button.isHidden = true
        }
        
        Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(self.changeButtonMode), userInfo: nil, repeats: true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

