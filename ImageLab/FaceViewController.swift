//
//  ViewController.swift
//  ImageLab
//
//  Seed code by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//
//  Writen by Justin Wilson, Paul Herz, and Jake Rowland
//

import UIKit
import AVFoundation

class FaceViewController: UIViewController {
	//outlet to label for face status
	@IBOutlet weak var faceStateLabel: UILabel!
	
	//MARK: Class Properties
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
	
	//Decaying flags for tracking remaining label persistance
	var blinking = 0
	var smiling = 0
	
	//for trackig blink state
	var blinkID: Int32 = -1
	var leftClosed = false
	var rightClosed = false
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.front)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these proerties for better face detection efficiency
		let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow,
		                    CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    }
    
    //MARK: Apply filters and apply feature detectors
    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
		//first highlight faces
        var retImage = highlightFaces(inputImage: inputImage, features: features)
		
		//setup vars
		var featurePosition = CGPoint()
		let holeFilter = CIFilter(name:"CIHoleDistortion",
		                          withInputParameters: ["inputRadius" : 10.0])!

		//mark eyes and mouth
        for f in features {
			if(f.hasMouthPosition) {
				//get feature postition
				featurePosition = f.mouthPosition
				
				//set filter params
				holeFilter.setValue(retImage, forKey: "inputImage")
				holeFilter.setValue(CIVector(cgPoint:featurePosition), forKey: "inputCenter")
				
				//return filtered image
				retImage = holeFilter.outputImage!
			}
			
			if(f.hasLeftEyePosition) {
				//get feature postition
				featurePosition = f.leftEyePosition
				
				//set filter params
				holeFilter.setValue(retImage, forKey: "inputImage")
				holeFilter.setValue(CIVector(cgPoint:featurePosition), forKey: "inputCenter")
				
				//return filtered image
				retImage = holeFilter.outputImage!
			}
			
			if(f.hasRightEyePosition) {
				//get feature postition
				featurePosition = f.rightEyePosition
				
				//set filter params
				holeFilter.setValue(retImage, forKey: "inputImage")
				holeFilter.setValue(CIVector(cgPoint:featurePosition), forKey: "inputCenter")
				
				//return filtered image
				retImage = holeFilter.outputImage!
			}
        }
		
        return retImage //return filtered image
    }
	
	
	///Highlights faces with a inverted circle over face
	func highlightFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage {
		var circleImage : CIImage! = nil
		var maskImage : CIImage! = nil
		var inverseImage: CIImage! = nil
		var filterCenter = CGPoint()
		
		/* build mask image
		   recipie for mask - https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_filer_recipes/ci_filter_recipes.html#//apple_ref/doc/uid/TP30001185-CH4-SW1 */
		
		let radialGradient: CIFilter = CIFilter(name:"CIRadialGradient")!
		
		for f in features {
			//set where to apply filter
			filterCenter.x = f.bounds.origin.x + (f.bounds.size.width / 2)
			filterCenter.y = f.bounds.origin.y + (f.bounds.size.height / 2)
			let radius = min(f.bounds.size.width, f.bounds.size.height) / 1.5
			
			radialGradient.setValue(CIVector(cgPoint: filterCenter), forKey:kCIInputCenterKey)
			radialGradient.setValue(radius, forKey:"inputRadius0")
			radialGradient.setValue(radius + 1.0, forKey:"inputRadius1")
			radialGradient.setValue(CIColor.init(red: 0.0, green: 1.0, blue: 0.0, alpha: 1.0), forKey:"inputColor0")
			radialGradient.setValue(CIColor.init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0), forKey:"inputColor1")
			
			circleImage = radialGradient.outputImage!
			if (maskImage == nil) {
				maskImage = circleImage
			} else {
				let compositingFilter : CIFilter = CIFilter(name:"CISourceOverCompositing")!
				compositingFilter.setValue(circleImage, forKey: kCIInputImageKey)
				compositingFilter.setValue(maskImage, forKey: kCIInputBackgroundImageKey)
				maskImage = compositingFilter.outputImage
			}
		}
		
		//create inverse image
		let colorInverseFilter: CIFilter = CIFilter(name: "CIColorInvert")!
		colorInverseFilter.setValue(inputImage, forKey: kCIInputImageKey)
		inverseImage = colorInverseFilter.outputImage
		
		//blend inverse image and original together using mask
		let blendWithMaskFilter: CIFilter = CIFilter(name: "CIBlendWithMask")!
		blendWithMaskFilter.setValue(inverseImage, forKey: kCIInputImageKey)
		blendWithMaskFilter.setValue(inputImage, forKey: kCIInputBackgroundImageKey)
		blendWithMaskFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)
		
		return blendWithMaskFilter.outputImage! //return resulting image
	}
	
	///Detect faces in img
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation and enables eye blink and smile detections
		let optsFace = [CIDetectorImageOrientation: self.videoManager.ciOrientation, CIDetectorEyeBlink:true, CIDetectorSmile:true] as [String : Any]

		// get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        let f = getFaces(img: inputImage)
		
        // if no faces, just return original image
        if f.count == 0 {
			//make blank
			DispatchQueue.main.async {
				self.faceStateLabel.text = ""
			}
			
			return inputImage
		}
		
		if f.count == 1 {
			//check first face
			updateFaceStateStatus(face: f[0])
		}
	
        //otherwise apply the filters to the faces
        return applyFiltersToFaces(inputImage: inputImage, features: f)
    }
	
	//Update face status label if smiling or blinking is detected
	func updateFaceStateStatus(face:CIFaceFeature) {
		if(face.hasSmile) {smiling = 4} //reset flag to 3 if face is detected
		
		//do we have an ID for this face and does it match the previous one?
		if(face.hasTrackingID && blinkID == face.trackingID) {
			//If there is a transision, declare blinking and store the new eye closure state
			if(leftClosed != face.leftEyeClosed) {
				blinking = 4 //reset flag to 4
				leftClosed = !leftClosed //update state
			} else if(rightClosed != face.rightEyeClosed) {
				blinking = 4 //reset flag to 4
				rightClosed = !rightClosed //update state
			}
		} else {
			//if we don't have an ID or it doesn't match then reset
			blinkID = face.trackingID
			leftClosed = face.leftEyeClosed
			rightClosed = face.rightEyeClosed
		}
		
		//update the label
		DispatchQueue.main.async {
			if (self.smiling > 0 && self.blinking > 0) {
				self.faceStateLabel.text = " Smiling & Blinking "
			} else if (self.smiling > 0) {
				self.faceStateLabel.text = " Smiling "
			} else if (self.blinking > 0) {
				self.faceStateLabel.text = " Blinking "
			} else {
				self.faceStateLabel.text = ""
			}
		}
		
		//decrease persistance flag values by 1
		if(smiling > 0) { smiling = smiling - 1 }
		if(blinking > 0) { blinking = blinking - 1 }
	}
	
	///IBAction to switch camera if button selected
	@IBAction func switchCamera(_ sender: AnyObject) {
	        self.videoManager.toggleCameraPosition()
	
	}
}

