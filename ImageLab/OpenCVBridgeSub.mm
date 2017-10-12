//
//  OpenCVBridgeSub.m
//  ImageLab
//
//  Created by Eric Larson on 10/4/16.
//  Copyright © 2016 Eric Larson. All rights reserved.
//

#import "OpenCVBridgeSub.h"

#import "AVFoundation/AVFoundation.h"
#include <queue>

using namespace cv;

@interface OpenCVBridgeSub() {
	std::queue<float> bgrQueues[3];
}
@property (nonatomic) cv::Mat image;
@end

@implementation OpenCVBridgeSub
@dynamic image;
//@dynamic just tells the compiler that the getter and setter methods are implemented not by the class itself but somewhere else (like the superclass or will be provided at runtime).

// returns the red channel mean of the image
-(double)processImage{
    
    cv::Mat image_copy;
    Scalar avgPixelIntensity;
    cv::Mat image = self.image;
    
    cvtColor(image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
	
    avgPixelIntensity = cv::mean( image_copy );
	
	double redChannelMean = avgPixelIntensity.val[2];
	
    self.image = image;
	return redChannelMean;
}

@end
