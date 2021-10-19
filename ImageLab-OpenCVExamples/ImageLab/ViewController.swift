//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    var isovering = false
    var notoveringtimer = 0
    let bridge = OpenCVBridge()
    @IBOutlet weak var togglecamera: UIButton!
    
    @IBOutlet weak var toggleflash: UIButton!
    //MARK: Outlets in view
    @IBOutlet weak var flashSlider: UISlider!
    @IBOutlet weak var stageLabel: UILabel!
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        
        // setup the OpenCV bridge nose detector, from file
        self.bridge.loadHaarCascade(withFilename: "nose")
        
        self.videoManager = VideoAnalgesic(mainView: self.view)    // Change the camera to back
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.back)
        

        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow,CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImageSwift)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    
    }
    
    //MARK: Process image output
    func processImageSwift(inputImage:CIImage) -> CIImage{
        

        var retImage = inputImage
        self.bridge.setTransforms(self.videoManager.transform)
        self.bridge.setImage(retImage,
                             withBounds: retImage.extent,
                             andContext: self.videoManager.getCIContext())
        
        let gotfinger = self.bridge.processFinger()     // Let the function process finger
        retImage = self.bridge.getImageComposite()
        

        DispatchQueue.main.async { // Make sure you're on the main thread here
            self.togglecamera.isEnabled = !gotfinger  // enable/disable the camera based on the finger overing
            self.toggleflash.isEnabled = !gotfinger  // enable/disable the flash based on the finger overing
            if(gotfinger && !self.isovering){     // If it got the finger for the first time
                _ = self.videoManager.turnOnFlashwithLevel(1.0) // Turn on the flash
                self.isovering = true              // Mark it as overing
            }
            else if(self.isovering && !gotfinger){  // If it is overing not it cannot detect it
                if(self.notoveringtimer > 5){      // If it fails the detection for 5 times
                    self.videoManager.turnOffFlash()   // turn off the camera
                    self.isovering = false              // mark it as not overing
                    self.notoveringtimer = 0            // reset the timer
                }
                else{                    // wait to see if stil non-detected next time
                    self.notoveringtimer = self.notoveringtimer + 1;
                }
            }
            // Note: When you test the Part 4.1, it may seem like intermittent, the problem is when the flash is on the image will become more bright which reduce the intensity of red. Try use one finger or not let the finger overing the flash.
        }
        
        
        
        return retImage
    }
    
    //MARK: Setup Face Detection
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
    }
    
    
    // change the type of processing done in OpenCV
    @IBAction func swipeRecognized(_ sender: UISwipeGestureRecognizer) {
        switch sender.direction {
        case .left:
            self.bridge.processType += 1
        case .right:
            self.bridge.processType -= 1
        default:
            break
            
        }
        
        stageLabel.text = "Stage: \(self.bridge.processType)"

    }
    
    //MARK: Convenience Methods for UI Flash and Camera Toggle
    @IBAction func flash(_ sender: AnyObject) {
        if(self.videoManager.toggleFlash()){
            self.flashSlider.value = 1.0
        }
        else{
            self.flashSlider.value = 0.0
        }
    }
    
    @IBAction func switchCamera(_ sender: AnyObject) {
        self.videoManager.toggleCameraPosition()
    }
    
    @IBAction func setFlashLevel(_ sender: UISlider) {
        if(sender.value>0.0){
            let val = self.videoManager.turnOnFlashwithLevel(sender.value)
            if val {
                print("Flash return, no errors.")
            }
        }
        else if(sender.value==0.0){
            self.videoManager.turnOffFlash()
        }
    }

   
}

