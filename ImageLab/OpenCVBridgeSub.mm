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

-(bool)processImage{
    
    cv::Mat frame_gray,image_copy,mean,stddev;
    char text[50];
    Scalar avgPixelIntensity;
    cv::Mat image = self.image;
    
    cvtColor(image, image_copy, CV_BGRA2BGR); // get rid of alpha for processing
	
    avgPixelIntensity = cv::mean( image_copy );
    sprintf(text,"Avg. B: %.0f, G: %.0f, R: %.0f", avgPixelIntensity.val[0],avgPixelIntensity.val[1],avgPixelIntensity.val[2]);
    cv::putText(image, text, cv::Point(20, 20), FONT_HERSHEY_PLAIN, 0.75, Scalar::all(255), 1, 2);
	
	bool isFinger = avgPixelIntensity.val[2] < 50;
	
	if(isFinger) {
		sprintf(text,"FINGER");
		cv::putText(image, text, cv::Point(50,50), FONT_HERSHEY_PLAIN, 0.75, Scalar::all(255), 1, 2);
		for (int i = 0; i < 3; ++i) {
			auto size = self->bgrQueues[i].size();
			if(size <= 100) {
				self->bgrQueues[i].push(avgPixelIntensity.val[i]);
			}
		}
		if(self->bgrQueues[0].size() == 100) {
			printf("Hey hey hey we got 100 points here\n");
		}
	}
	
    self.image = image;
	return isFinger;
}

@end
