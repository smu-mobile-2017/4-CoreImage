//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation

class FaceViewController: UIViewController   {

    //MARK: Class Properties
    var filters : [CIFilter]! = nil
    var videoManager:VideoAnalgesic! = nil
    let pinchFilterIndex = 2
    var detector:CIDetector! = nil
    
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = nil
        self.setupFilters()
        
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(position: AVCaptureDevice.Position.front)
        
        // create dictionary for face detection
        // HINT: you need to manipulate these proerties for better face detection efficiency
        let optsDetector = [CIDetectorAccuracy:CIDetectorAccuracyLow, CIDetectorTracking:true] as [String : Any]
        
        // setup a face detector in swift
        self.detector = CIDetector(ofType: CIDetectorTypeFace,
                                  context: self.videoManager.getCIContext(), // perform on the GPU is possible
            options: (optsDetector as [String : AnyObject]))
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning{
            videoManager.start()
        }
    }
    
    //MARK: Setup filtering
    func setupFilters(){
        filters = []
        
        let filterPinch = CIFilter(name:"CIBumpDistortion")!
        filterPinch.setValue(-0.5, forKey: "inputScale")
        filterPinch.setValue(75, forKey: "inputRadius")
        filters.append(filterPinch)
        
    }
    
    //MARK: Apply filters and apply feature detectors
    func applyFiltersToFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage{
        var retImage = inputImage
		retImage = highlightFaces(inputImage: inputImage, features: features)
//        var filterCenter = CGPoint()
//
//        for f in features {
//            //set where to apply filter
//            filterCenter.x = f.bounds.midX
//            filterCenter.y = f.bounds.midY
//
//            //do for each filter (assumes all filters have property, "inputCenter")
//            for filt in filters{
//                filt.setValue(retImage, forKey: kCIInputImageKey)
//                filt.setValue(CIVector(cgPoint: filterCenter), forKey: "inputCenter")
//                // could also manipualte the radius of the filter based on face size!
//                retImage = filt.outputImage!
//            }
//        }
        return retImage
    }
	
	func highlightFaces(inputImage:CIImage,features:[CIFaceFeature])->CIImage {
		var circleImage : CIImage! = nil
		var maskImage : CIImage! = nil
		var inverseImage: CIImage! = nil
		var filterCenter = CGPoint()
		
		/*	recipie for mask - https://developer.apple.com/library/content/documentation/GraphicsImaging/Conceptual/CoreImaging/ci_filer_recipes/ci_filter_recipes.html#//apple_ref/doc/uid/TP30001185-CH4-SW1 */
		
		for f in features {
			//set where to apply filter
			filterCenter.x = f.bounds.origin.x + (f.bounds.size.width / 2)
			filterCenter.y = f.bounds.origin.y + (f.bounds.size.height / 2)
			let radius = min(f.bounds.size.width, f.bounds.size.height) / 1.5
			
			let radialGradient: CIFilter = CIFilter(name:"CIRadialGradient")!
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
		
		//create inverse
		let colorInverseFilter: CIFilter = CIFilter(name: "CIColorInvert")!
		colorInverseFilter.setValue(inputImage, forKey: kCIInputImageKey)
		inverseImage = colorInverseFilter.outputImage
		
		//blend
		let blendWithMaskFilter: CIFilter = CIFilter(name: "CIBlendWithMask")!
		blendWithMaskFilter.setValue(inverseImage, forKey: kCIInputImageKey)
		blendWithMaskFilter.setValue(inputImage, forKey: kCIInputBackgroundImageKey)
		blendWithMaskFilter.setValue(maskImage, forKey: kCIInputMaskImageKey)
		
		return blendWithMaskFilter.outputImage!
	}
    
    func getFaces(img:CIImage) -> [CIFaceFeature]{
        // this ungodly mess makes sure the image is the correct orientation
        let optsFace = [CIDetectorImageOrientation:self.videoManager.ciOrientation]
        // get Face Features
        return self.detector.features(in: img, options: optsFace) as! [CIFaceFeature]
        
    }
    
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{
        
        // detect faces
        let f = getFaces(img: inputImage)
        
        // if no faces, just return original image
        if f.count == 0 { return inputImage }
        
        //otherwise apply the filters to the faces
        return applyFiltersToFaces(inputImage: inputImage, features: f)
    }
    
    

   
}

