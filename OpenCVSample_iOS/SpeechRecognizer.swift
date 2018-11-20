//
//  SpeechRecognizer.swift
//  SpeakSwiftly
//
//  Created by Daniel Leong on 5/8/15.
//  Copyright (c) 2015 Daniel Leong. All rights reserved.
//

import UIKit
import Speech

class SpeechRecognizer: NSObject, SFSpeechRecognizerDelegate {
    
    private var speechRecognizer: SFSpeechRecognizer!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest!
    private var recognitionTask: SFSpeechRecognitionTask!
    private let audioEngine = AVAudioEngine()
    private let locale = Locale(identifier: "en-US")
    
    private var lastSavedString: String = ""
    private let supportedCommands = ["more"]
    
    //private var resultStringTemp: String = ""
    //private var resultStrings: [String] = [String]()
    
    var speechInputQueue: [String] = [String]()
    
    func load() {
        print("load")
        prepareRecognizer(locale: locale)
        
        authorize()
    }
    
    func start() {
        print("start")
        if !audioEngine.isRunning {
            try! startRecording()
        }
    }
    
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            
        }
    }
    
//    private func getResultWord() -> String {
//        var index = resultStrings.endIndex - 1
//        if index == 0 {
//            return resultStrings[index]
//        }
//        print("index", index)
//        let res1 = resultStrings[index]
//        var res2 = resultStrings[index - 1]
//        while (res1 == res2 && index >= 2) {
//            index = index - 1
//            res2 = resultStrings[index - 1]
//        }
//        if res1 == res2 {
//            return res1
//        }
//        else {
//            return String((res1 as NSString).substring(from: res2.count + 1))
//        }
//    }
    
    private func authorize() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    print("Authorized!")
                case .denied:
                    print("Unauthorized!")
                case .restricted:
                    print("Unauthorized!")
                case .notDetermined:
                    print("Unauthorized!")
                }
            }
        }
    }
    
    private func prepareRecognizer(locale: Locale) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)!
        speechRecognizer.delegate = self
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        try audioSession.setMode(AVAudioSessionModeDefault)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                
                let temp = result.bestTranscription.formattedString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
                //print("temp", temp)
                if temp != self.lastSavedString && temp.count > self.lastSavedString.count {
                    
                    var tempSplit = temp.split(separator: " ")
                    var lastSplit = self.lastSavedString.split(separator: " ")
                    while lastSplit.count > 0 {
                        if String(tempSplit[0]) == String(lastSplit[0]) {
                            tempSplit.remove(at: 0)
                            lastSplit.remove(at: 0)
                        }
                        else {
                            break
                        }
                    }
                
                    for command in tempSplit {
                        if self.supportedCommands.contains(String(command)) {
                            self.speechInputQueue.append(String(command))
                        }
                    }
                    //print(self.speechInputQueue)
                    
                    self.lastSavedString = temp
                    
                }
                
                //print(self.resultStringTemp)
                //print("word:" + self.getResultWord())
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
        
    }
    
    // =========================================================================
    // MARK: - SFSpeechRecognizerDelegate
    
    /*public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
     if available {
     recordBtn.isEnabled = true
     recordBtn.setTitle("Start Recording", for: [])
     } else {
     recordBtn.isEnabled = false
     recordBtn.setTitle("Recognition not available", for: .disabled)
     }
     }*/
}

