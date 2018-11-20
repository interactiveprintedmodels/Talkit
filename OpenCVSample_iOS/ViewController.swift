//
//  Chilitags.m
//  OpenCVSample_iOS
//
//  Created by 张倬豪 on 2017/11/7.
//  Copyright © 2017年 Talkit. All rights reserved.
//
import UIKit
import AVFoundation

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    

    // Model List
    let modelList = ["plane", "globe", "volcano", "map"]
    //@Lei, modify the intro here
    let modelIntro = ["This is a model of a plane", "This is a model of a Globe", "This is a model of a volcano", "This is a model of Washington region map, and it has four components. You could assembly the pieces of the model"]
    
    var currentmodel = "globe"
    // View
    // FIXME: modelHasBeenChosen seems unused
    var modelHasBeenChosen = false
    
    // variable for storing camera image
    var capturedImage: UIImage = UIImage.init()
    // the bigest image view
    @IBOutlet weak var imageView: UIImageView!
    // the picker view
    @IBOutlet weak var pickerView: UIPickerView!
    // the text label in the middle of the screen
    @IBOutlet weak var modelLabel: UILabel!
    // the button for choosing a model
    @IBOutlet weak var modelChooseBtn: UIButton!
    // the button for calibration a model
    // TODO: unused now
    @IBOutlet weak var calibrationBtn: UIButton!
    //layer view for annimation
    @IBOutlet var gifView: TransView!

    
    // camera capture
    var avSession: AVCaptureSession!
    var avOutput: AVCaptureVideoDataOutput!
    
    //speech input
    var speechRecognizer: SpeechRecognizer! = SpeechRecognizer()
    //a timer to evoke the speech input from time to time
    var speechTimer: Timer!
    
    // TTS
    let synth = AVSpeechSynthesizer()
    var myUtterance = AVSpeechUtterance(string: "")
    
    // audio player
    var audioPlayer = AVAudioPlayer()
    
    // annimation
    var enableAnnimation = false
    var Gif = UIImage.gifImageWithName("w-o-black")
    var GifHeight:CGFloat = 0.0
    var GifWidth:CGFloat = 0.0

    var label = ""
    var content = ""
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setGIF()
        
        // Config UI
        pickerView.isHidden = true
        pickerView.dataSource = self
        pickerView.delegate = self
        
        // Config Speech Input
        speechRecognizer.load()
        speechRecognizer.start()
        speechTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) {
            timer in
            let tempSpeechInput = self.speechRecognizer.speechInputQueue
            self.speechRecognizer = SpeechRecognizer()
            self.speechRecognizer.speechInputQueue = tempSpeechInput
            self.speechRecognizer.load()
            self.speechRecognizer.start()
        }
        
        // config mychilitag
        if !myChilitags.checkSettings() {
            
            //var defaultModelName = readWithFile()
            var defaultModelName = "globe"
            if !modelList.contains(defaultModelName) {
                defaultModelName = "globe"
            }
            
            if let configFilePath = Bundle.main.path(forResource: "globeTagYAML", ofType: "yml"),
                //TODO: change the model file
                let modelFilePath = Bundle.main.path(forResource: defaultModelName, ofType: "json"){
                myChilitags.loadSettings(configFilePath, modelAt: modelFilePath)
            }
        }
        else{
            print("error")
        }
        
        
        // config audio player
        let soundURL = URL(fileURLWithPath: Bundle.main.path(forResource: "cascade", ofType: "wav")!)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            print("config audio successfully")
        }
        catch {
            print("config audio unsuccessfully", error)
        }
        
        // Config a video capturing session.
        // the video has to come after the chilitag configuration and the audio player
        self.avSession = AVCaptureSession()
        let devicetemp = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back)
        let input = try! AVCaptureDeviceInput(device: devicetemp!)
        self.avSession.addInput(input)
        self.avOutput = AVCaptureVideoDataOutput()
        self.avSession.addOutput(avOutput)
        if(self.avOutput.connections.first?.isCameraIntrinsicMatrixDeliverySupported == true){
            self.avOutput.connections.first?.isCameraIntrinsicMatrixDeliveryEnabled = true
            // get the intrinsic matrix from the camera automatically
            print("enable intrinsic matrix output")
        }
        else{
            // failed to do so
            print("failed to enable intrinsic matrix output")
        }
        //@Zhuohao, is this some optimization you did to make the video more smooth?
        self.avOutput.videoSettings = [ kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA) ]
        let queue: DispatchQueue = DispatchQueue(label: "videocapturequeue", attributes: [])
        self.avOutput.setSampleBufferDelegate(self, queue: queue)
        self.avOutput.alwaysDiscardsLateVideoFrames = true
        self.avSession.startRunning()
        
        
        
    }
    
    override var shouldAutorotate : Bool {
        return false
    }
    
}


// Part 1: UI, including ModelPicker, Calibration
extension ViewController {
    
    @IBAction func ModelChoosePressed(_ sender: Any) {
        if pickerView.isHidden {
            pickerView.isHidden = false
        }
    }
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return modelList.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return modelList[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentmodel = modelList[row]
        modelLabel.text = currentmodel
        //change the model file
        //saveWithFile(model: modelList[row])
        let yamlstring = currentmodel+"TagYAML"
        let jsonstring = currentmodel
        if let configFilePath = Bundle.main.path(forResource: yamlstring, ofType: "yml"),
            let modelFilePath = Bundle.main.path(forResource: jsonstring, ofType: "json"){
            print("change model to ",currentmodel )
            myChilitags.reloadSettings(configFilePath, modelAt: modelFilePath)}
        if (currentmodel == "volcano") || (currentmodel == "map"){
            myChilitags.alwaysFrontOn()
        }
        else{
            myChilitags.alwaysFrontOff()
        }
        modelHasBeenChosen = true
        pickerView.isHidden = true
        print("disable annimation")
        DispatchQueue.main.async(execute: {self.gifView.isHidden = true})
        self.enableAnnimation = false
        textToSpeech(text: modelIntro[row])
    }
    
    //for calibration
    @IBAction func CalibrationPressed(_ sender: Any) {
        //turn off
        if enableAnnimation && currentmodel == "volcano"{
            print("disable annimation")
            DispatchQueue.main.async(execute: {self.gifView.isHidden = true})
            self.enableAnnimation = false
            //mute the view
        }
        //turn on
        else if currentmodel == "volcano"{
            print("enable annimation")
            DispatchQueue.main.async(execute: {
                self.Gif = UIImage.gifImageWithName("w-o-black")
                self.gifView.image = self.Gif
                self.gifView.isHidden = false
            })
            self.enableAnnimation = true
            let soundURL = URL(fileURLWithPath: Bundle.main.path(forResource: "erruption", ofType: "wav")!)
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            }
            catch {
                print(error)
            }
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            //enable the view
        }
        
    }
    
}



// Part 2: TTS
extension ViewController {
    // a function to speak certain text string
    func textToSpeech(text:String) {
        myUtterance = AVSpeechUtterance(string: text)
        myUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
        myUtterance.voice = AVSpeechSynthesisVoice.init(language: "en_US")
        synth.speak(myUtterance)
    }
}


// Part 3: Process Image
extension ViewController {
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // Convert a captured image buffer to UIImage.
        let imageBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let ciimage : CIImage = CIImage(cvPixelBuffer: imageBuffer)
        capturedImage = self.ci2uiConvert(cmage: ciimage)
        
        // Output the intrinsic matrix in sampleBuffer
        if let camData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) as? Data {
            let matrix: matrix_float3x3 = camData.withUnsafeBytes { $0.pointee }
            let fx : Float = matrix[0][0]
            let fy : Float = matrix[1][1]
            let ox : Float = matrix[2][0]
            let oy : Float = matrix[2][1]
            myChilitags.updateIntrinsicMatrix(fx, fy: fy, ox: ox, oy: oy)
        }
        
        
        // Detect QR code in the image
        myChilitags.processImage(capturedImage)

        //only start detecting when it's not talking
        //TODO: move the label detection function to mychilitags
        if !synth.isSpeaking &&  !audioPlayer.isPlaying{
            let position = myChilitags.checkPosition()
            if position == "correct"{
                myChilitags.detectLabel()
                let labelTemp = myChilitags.getLabels()
                if labelTemp != "No Speak"{
                    let tempSplit = labelTemp.split(separator: "@")
                    label = String(tempSplit[0])
                    //if it's no label then process it
                    if label == "m_nolabel"{

                    }
                    //if it's not no label then update the content
                    else{
                        content = String(tempSplit[1])
                    }
                    let index = label.index(label.startIndex, offsetBy: 2)
                    let two_chara = String(label.prefix(upTo: index))
                    if two_chara == "m_"{
                        let audio_name =  String(label.suffix(from: index))
                        let soundURL = URL(fileURLWithPath: Bundle.main.path(forResource: audio_name, ofType: "wav")!)
                            
                        do {
                            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                        }
                        catch {
                            print(error)
                        }
                        audioPlayer.prepareToPlay()
                        audioPlayer.play()
                        }
                        else{
                            textToSpeech(text: label)
                        }
                        
                    }
            }
                else{
                    textToSpeech(text: position)
                }
        }
        
        
        //process speech input
        if self.speechRecognizer.speechInputQueue.count > 0 {
            let command = self.speechRecognizer.speechInputQueue[0]
            print(command)
            if command == "more" {
                if !synth.isSpeaking &&  !audioPlayer.isPlaying{
                    self.textToSpeech(text: content)
                }
                else{
                    print("speech is talking")
                }
                
            }
            else {
                self.textToSpeech(text: "unrecognized command")
            }
            self.speechRecognizer.speechInputQueue.remove(at: 0)
            print("after :", self.speechRecognizer.speechInputQueue)
        }


    
        
        // Show the result
        let resultImage = myChilitags.getVisulizedImage(capturedImage)
        
        if enableAnnimation{
            let tempString = myChilitags.getGifResults()
            let strs = tempString.split(separator: "@").map(String.init)
            
            let TL = transCoordinatesFromImgtoScreen(xOriginal:CGFloat((strs[1] as NSString).integerValue), yOriginal:CGFloat((strs[0] as NSString).integerValue))
            let TR = transCoordinatesFromImgtoScreen(xOriginal:CGFloat((strs[3] as NSString).integerValue), yOriginal:CGFloat((strs[2] as NSString).integerValue))
            let BR = transCoordinatesFromImgtoScreen(xOriginal:CGFloat((strs[5] as NSString).integerValue), yOriginal:CGFloat((strs[4] as NSString).integerValue))
            let BL = transCoordinatesFromImgtoScreen(xOriginal:CGFloat((strs[7] as NSString).integerValue), yOriginal:CGFloat((strs[6] as NSString).integerValue))
            DispatchQueue.main.async(execute: {self.gifView.transformToFitQuadTopLeft(tl: TL, tr: TR, bl: BL, br: BR)})
        }
        
        DispatchQueue.main.async(execute: { self.imageView.image = resultImage })
    }
}


extension ViewController{
    //set the gif view
    func setGIF() {
        GifHeight = Gif!.size.height * Gif!.scale
        GifWidth = Gif!.size.width * Gif!.scale
        gifView = TransView(image: Gif)
        gifView.frame = CGRect(x: 0.0, y: 0.0, width: GifWidth, height: GifHeight)
        gifView.layer.anchorPoint = CGPoint(x:0, y:0)
        view.addSubview(gifView)
    }
    
    //convert ciimage to uiimage
    func ci2uiConvert(cmage:CIImage) -> UIImage {
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(cmage, from: cmage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage, scale: 1.0, orientation: UIImageOrientation.right)
        return image
    }
    
    //transform the coordinates from the image data in opencv to the screen data
    func transCoordinatesFromImgtoScreen(xOriginal:CGFloat, yOriginal:CGFloat)  -> CGPoint {
        var x:CGFloat = 0.0
        var y:CGFloat = 0.0
        var ratio:CGFloat = 0.0
        
        //TODO: Move it to main thread
        let ratioX:CGFloat = imageView.bounds.size.width/capturedImage.size.width
        let ratioY:CGFloat = imageView.bounds.size.height/capturedImage.size.height
        
        //find the ratio that is closest to 1
        if abs(ratioX - 1) > abs(ratioY - 1) {
            ratio  = ratioY
        }
        else{
            ratio = ratioX
        }
        
        //in AspectFill, scale from the center
        //x is reversed
        x = (capturedImage.size.width/2 - xOriginal) * ratio + imageView.bounds.size.width/2
        y = (yOriginal  - capturedImage.size.height/2) * ratio + imageView.bounds.size.height/2
        
        return CGPoint(x:x,y:y)
    }
}

extension ViewController {
    // save current model
    func saveWithFile(model: String) {
        let home = NSHomeDirectory() as NSString
        let docPath = home.strings(byAppendingPaths: ["Documents"]) as [NSString]
        let filePath = docPath[0].strings(byAppendingPaths: ["data.plist"])
        let dataSource = NSMutableArray()
        dataSource.add(model)
        dataSource.write(toFile: filePath[0], atomically: true)
    }
    
    func readWithFile() -> String {
        let home = NSHomeDirectory() as NSString
        let docPath = home.strings(byAppendingPaths: ["Documents"]) as [NSString]
        let filePath = docPath[0].strings(byAppendingPaths: ["data.plist"])
        let dataSource = NSArray(contentsOfFile: filePath[0])
        //print("readwithfile", dataSource![0])
        return dataSource![0] as! String
    }
}
