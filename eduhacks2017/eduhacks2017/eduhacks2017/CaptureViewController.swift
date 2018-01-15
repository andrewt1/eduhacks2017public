//
//  CaptureViewController.swift
//  eduhacks2017
//
//  Created by Gabriel Uribe on 9/30/17.
//  Copyright © 2017 Gabriel Uribe. All rights reserved.
//

import UIKit
import AVFoundation
import Speech

class CaptureViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, SFSpeechRecognizerDelegate {
    @IBOutlet weak var pointsLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var microphoneButton: UIButton!
    @IBOutlet weak var photoView: UIImageView!
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "zh"))! //es-MX
    let correct = "✅"
    let wrong = "❌"
    var prediction = ""
    var points = 0
    
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    private var fullTranscript = ""
    private var translations: [String] = []
    
    var tap: UIGestureRecognizer?
    @IBOutlet weak var showAnswerButton: UIButton!
    
    let stillImageOutput = AVCaptureStillImageOutput()
    
    let cameraSession = AVCaptureSession()
    
    @IBOutlet weak var predictionLabel: UILabel!
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let preview =  AVCaptureVideoPreviewLayer(session: self.cameraSession)
        preview.videoGravity = .resizeAspectFill
        return preview
        
    }()
    
    var model = Inceptionv3()
    
    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        
        microphoneButton.isEnabled = false
        
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { (authStatus) in
            
            var isButtonEnabled = false
            
            switch authStatus {
            case .authorized:
                isButtonEnabled = true
                
            case .denied:
                isButtonEnabled = false
                print("User denied access to speech recognition")
                
            case .restricted:
                isButtonEnabled = false
                print("Speech recognition restricted on this device")
                
            case .notDetermined:
                isButtonEnabled = false
                print("Speech recognition not yet authorized")
            }
            
            OperationQueue.main.addOperation() {
                self.microphoneButton.isEnabled = isButtonEnabled
            }
        }

        predictionLabel.text = "Starting prediction 🚀"
        
        let captureDevice = AVCaptureDevice.default(for: .video)! // todo: Can return nil. MDM restrictions
        
        do {
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            cameraSession.beginConfiguration()
            
            if (cameraSession.canAddInput(deviceInput) == true) {
                cameraSession.addInput(deviceInput)
            }
            
            let dataOutput = AVCaptureVideoDataOutput()
            
            dataOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)]
            
            dataOutput.alwaysDiscardsLateVideoFrames = true
            
            if (cameraSession.canAddOutput(dataOutput) == true) {
                cameraSession.addOutput(dataOutput)
            }
            
            cameraSession.commitConfiguration()
            
            let queue = DispatchQueue(label: "com.iostreamh.inception.video-output")
            dataOutput.setSampleBufferDelegate(self, queue: queue)
            
        }
        catch let error as NSError {
            NSLog("\(error), \(error.localizedDescription)")
        }
        
        var frame = view.frame
        frame.size.height = frame.size.height //- 35.0
        previewLayer.frame = frame
        
        cameraView.layer.addSublayer(previewLayer)
        tap = UITapGestureRecognizer(target: self, action:#selector(CaptureViewController.saveToCamera))
        cameraView.addGestureRecognizer(tap!)
        
        cameraSession.startRunning()
        stillImageOutput.outputSettings = [AVVideoCodecKey:AVVideoCodecType.jpeg]
        if cameraSession.canAddOutput(stillImageOutput) {
            cameraSession.addOutput(stillImageOutput)
        }
    }
    
    @IBAction func showAnswerTapped(_ sender: Any) {
        showAnswerButton.setTitle(self.translations[0], for: .normal)
    }
    
    @IBAction func recordButtonTapped(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            microphoneButton.isEnabled = false
            
            microphoneButton.backgroundColor = UIColor.lightGray
            self.predictionLabel.text = self.prediction
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                self.microphoneButton.backgroundColor = UIColor(red: 255, green: 255, blue: 255, alpha: 1)

                var match = false
                for word in self.translations {
                    if self.fullTranscript == word.capitalizingFirstLetter() {
                        print("there's a match!")
                        match = true
                    }
                }
                
                if match {
                    //self.predictionLabel.textColor = UIColor.green
                    self.predictionLabel.text = self.prediction + self.correct
                    self.points += 10
                    self.pointsLabel.text = String(self.points)
                } else {
                    //self.predictionLabel.textColor = UIColor.red
                    self.predictionLabel.text = self.prediction + self.wrong
                }
            })

        }
    }
    
    @IBAction func recordButtonStart(_ sender: Any) {
        if !audioEngine.isRunning {
            startRecording()
            microphoneButton.backgroundColor = UIColor.red
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func cancelButton(_ sender: Any) {
        cameraSession.startRunning()
        cameraView.addGestureRecognizer(tap!)
        self.photoView.isHidden = true
        self.cancelButton.isHidden = true
        self.microphoneButton.isHidden = true
        self.predictionLabel.textColor = UIColor.white
        self.showAnswerButton.isHidden = true
        self.showAnswerButton.setTitle("Show Answer ", for: .normal)
    }
    
    @objc func saveToCamera(sender: UITapGestureRecognizer) {
        if let videoConnection = stillImageOutput.connection(with: AVMediaType.video) {
            stillImageOutput.captureStillImageAsynchronously(from: videoConnection) {
                (imageDataSampleBuffer, error) -> Void in
                if let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: imageDataSampleBuffer!, previewPhotoSampleBuffer: nil) {
                    let image = UIImage(data: imageData)
                    self.cameraSession.stopRunning()
                    self.photoView.image = image
                    self.photoView.isHidden = false
                    self.cancelButton.isHidden = false
                    self.cameraView.removeGestureRecognizer(self.tap!)
                    self.microphoneButton.isHidden = false
                    self.showAnswerButton.isHidden = false
                    EduTranslate.go(words: self.predictionLabel.text!, callback: self.translatedWords)
                }
                
                //let imageData = AVCapturePhotoOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer!)
                //UIImageWriteToSavedPhotosAlbum(UIImage(data: imageData!)!, nil, nil, nil)
            }
        }
    }
    
    func translatedWords(words: [String]) {
        translations = words
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection){
        connection.videoOrientation = .portrait
        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let img = UIImage(ciImage: ciImage).resizeTo(CGSize(width: 299, height: 299))
            if let uiImage = img {
                let pixelBuffer = uiImage.buffer()!
                let output = try? model.prediction(image: pixelBuffer)
                DispatchQueue.main.async {
                    //self.resizedImage.image = uiImage
                    self.predictionLabel.text = output?.classLabel ?? "I don't know! 😞"
                    self.prediction = self.predictionLabel.text ?? "I don't know! 😞"
                }
            }
        }
    }

    
    func startRecording() {
        
        if recognitionTask != nil {  //1
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()  //2
        do {
            try audioSession.setCategory(AVAudioSessionCategoryRecord)
            try audioSession.setMode(AVAudioSessionModeMeasurement)
            try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()  //3
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            fatalError("Unable to create an SFSpeechAudioBufferRecognitionRequest object")
        } //5
        
        recognitionRequest.shouldReportPartialResults = true  //6
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in  //7
            
            var isFinal = false  //8
            
            if result != nil {
                self.fullTranscript = (result?.bestTranscription.formattedString)!
                print(result?.bestTranscription.formattedString ?? "")
                isFinal = (result?.isFinal)!
            }
            
            if error != nil || isFinal {  //10
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.microphoneButton.isEnabled = true
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)  //11
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, when) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()  //12
        
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine couldn't start because of an error.")
        }
        
        //textView.text = "Say something, I'm listening!"
        
    }
    
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            microphoneButton.isEnabled = true
        } else {
            microphoneButton.isEnabled = false
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension UIImage {
    func buffer() -> CVPixelBuffer? {
        return UIImage.buffer(from: self)
    }
    
    // Taken from:
    // https://stackoverflow.com/questions/44462087/how-to-convert-a-uiimage-to-a-cvpixelbuffer
    // https://www.hackingwithswift.com/whats-new-in-ios-11
    static func buffer(from image: UIImage) -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer : CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard (status == kCVReturnSuccess) else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.translateBy(x: 0, y: image.size.height)
        context?.scaleBy(x: 1.0, y: -1.0)
        
        UIGraphicsPushContext(context!)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pixelBuffer
    }
    
    func resizeTo(_ size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}


extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }
    
    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

//https://www.invasivecode.com/weblog/AVFoundation-Swift-capture-video/
//https://gist.github.com/MihaelIsaev/273e4e8ddaaf062d2155
