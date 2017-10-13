//
//  ViewController.swift
//  ImageLab
//
//  Created by Eric Larson
//  Copyright © 2016 Eric Larson. All rights reserved.
//

import UIKit
import AVFoundation
import Charts
import Accelerate

class ViewController: UIViewController, ChartViewDelegate {
	
	let chartMaximumPoints: Int = 100
	let framesPerSecond: Double = 30.0
	let measurementTime: Double = 7.0 //time in seconds
	var ppgArray: [Double]! = nil
	var ppgArrayLength: Int = 0
	
	var beatsPerMinute: Double? = nil {
		didSet {
			DispatchQueue.main.async {
				if let bpm = self.beatsPerMinute {
					self.bpmLabel.text = "\(bpm) bpm"
				} else {
					self.bpmLabel.text = "—"
				}
			}
		}
	}
	
    //MARK: Class Properties
    var videoManager: VideoAnalgesic! = nil
    let bridge = OpenCVBridgeSub()
    
    //MARK: Outlets in view
	@IBOutlet weak var lineChartView: LineChartView!
	@IBOutlet weak var bpmLabel: UILabel!
	
    //MARK: ViewController Hierarchy
    override func viewDidLoad() {
        super.viewDidLoad()
		
		self.ppgArray = [Double]()
		
		self.ppgArrayLength = Int(self.framesPerSecond * self.measurementTime)
		ppgArray.reserveCapacity(self.ppgArrayLength) //set the size
		
        self.view.backgroundColor = nil
        
        self.videoManager = VideoAnalgesic.sharedInstance
        self.videoManager.setCameraPosition(position: .back)
        
        self.videoManager.setProcessingBlock(newProcessBlock: self.processImage)
        
        if !videoManager.isRunning {
            videoManager.start()
        }
		videoManager.setFPS(desiredFrameRate: framesPerSecond)
		
		lineChartView.delegate = self
		let dataSet = LineChartDataSet(values: [ChartDataEntry(x: 0, y: 0)], label: nil)
		
		dataSet.circleRadius = 0.0 // hide points (lines only)
		dataSet.drawValuesEnabled = false // don't show labels on value points
		dataSet.mode = .cubicBezier // smoothing
		lineChartView.isUserInteractionEnabled = false
		lineChartView.chartDescription = nil // no description label
		lineChartView.legend.enabled = false // no legend
//		lineChartView.leftAxis.axisMinimum = 0.0
//		lineChartView.leftAxis.axisMaximum = 50.0
		lineChartView.leftAxis.drawLabelsEnabled = false
		lineChartView.rightAxis.drawLabelsEnabled = false
		lineChartView.xAxis.drawLabelsEnabled = false
		
		
		lineChartView.data = LineChartData(dataSet: dataSet)
		
		// dummy code to push random values to chart (for testing)
		/*
		Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
			let random = Double(arc4random())/Double(INT32_MAX)*10.0
			self.addPointToChart(random)
		}
		*/
    }
	
	override func viewDidAppear(_ animated: Bool) {
		let _ = self.videoManager.toggleFlash()
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		let _ = self.videoManager.toggleFlash()
	}
	
	func addPointToChart(_ value: Double) {
		let dataSet = self.lineChartView.data!.dataSets[0]
		
		let x = dataSet.entryForIndex(dataSet.entryCount - 1)?.x
		let _ = dataSet.addEntry(ChartDataEntry(x: x!+1, y: value))
		if dataSet.entryCount > chartMaximumPoints {
			let _ = dataSet.removeFirst()
		}
		self.lineChartView.data!.notifyDataChanged()
		self.lineChartView.notifyDataSetChanged()
	}
	
	func addPointToPPGArray(_ ppgPoint: Double) {
		self.ppgArray.append(ppgPoint) //add to the array
		
		//check size, if at measurmentTime * framePerSecond in length; find peaks and count beats
		if(self.ppgArray.count == self.ppgArrayLength) {
			//find peaks
			let heartBeatCount: Double = Double(findNumberOfPeaks())
			print(heartBeatCount)
			//update label
			self.beatsPerMinute = 60.0/measurementTime * heartBeatCount
			
			//reset
			resetPPGArray()
		}
	}
	
	///ppgArray need to be of even length, no error checking
	func findNumberOfPeaks() -> Int {
		let windowSize: Int = 25 //keep odd
		let windowCenterIdx: Int = windowSize/2 + 1 // floor(odd/2) for 0...
		var heartBeatCount: Int = 0
		let loopLength = (self.ppgArray.count - windowSize) + 1
		
	
		for i in 0 ..< loopLength {  //doing for loops like this is horrible!!!
			//find max value in window
			var magResult = 0.0
			var peakIndex: vDSP_Length = 0
			ppgArray.withUnsafeBufferPointer { ptr in
				let slidingPtr = ptr.baseAddress! + i
				vDSP_maxviD(slidingPtr, 1, &magResult, &peakIndex, vDSP_Length(windowSize))
			}
			
			if (peakIndex == windowCenterIdx) {
				heartBeatCount += 1
				print(Int(peakIndex) + i)
			}
		}
		
		return heartBeatCount
	}
	
	func resetPPGArray() {
		self.ppgArray.removeAll(keepingCapacity: true) //empty array
		
		print("reset scan")
	}
	
    //MARK: Process image output
    func processImage(inputImage:CIImage) -> CIImage{

        // if you just want to process on separate queue use this code
        // this is a NON BLOCKING CALL, but any changes to the image in OpenCV cannot be displayed real time
		DispatchQueue.main.async {
			self.bridge.setImage(inputImage, withBounds: inputImage.extent, andContext: self.videoManager.getCIContext())
			let redChannelMean = self.bridge.processImage()
			
			if 10...50 ~= redChannelMean  {
				// if there's a finger
				self.addPointToChart(redChannelMean)
				self.addPointToPPGArray(redChannelMean)
			} else {
				// no finger
				self.addPointToChart(0.0)
				self.resetPPGArray()
			}
			
		}
		
        return inputImage
    }
	
//    @IBAction func switchCamera(_ sender: AnyObject) {
//        self.videoManager.toggleCameraPosition()
//    }
	
}

