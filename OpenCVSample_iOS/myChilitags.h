//
//  Chilitags.h
//  OpenCVSample_iOS
//
//  Created by 张倬豪 on 2017/11/7.
//  Copyright © 2017年 Talkit. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/NSDictionary.h>

@interface myChilitags : NSObject

// Converts a full color image to grayscale image with using OpenCV.
//+ (nonnull UIImage *)cvtColorBGR2GRAY:(nonnull UIImage *)image;
// This is the OpenCV sample interface
// We just need to implement new functions here


//detect the 3D tracker

+ (void)reloadSettings:(nonnull NSString *)configFilePath modelAt:(nonnull NSString*) modelFilePath;
+ (void)loadSettings:(nonnull NSString *)configFilePath modelAt:(nonnull NSString*) modelFilePath;
+ (bool)checkSettings;
+ (void)updateIntrinsicMatrix: (float)fx fy:(float)fy ox:(float)ox oy:(float)oy;


+ (nonnull UIImage *)getVisulizedImage:(nonnull UIImage *)image;
+ (void)processImage:(nonnull UIImage *)image;
+ (void) detectLabel;

+ (void) alwaysFrontOn;
+ (void) alwaysFrontOff;

+ (void)preSetupCalibration;
+ (bool)setupCalibration:(nonnull UIImage *) image;
+ (void)doCalibration:(nonnull UIImage *)image;

+ (nonnull NSString *)getLabels;
+ (nonnull NSString *)checkPosition;


+ (nonnull NSString *)getGifResults;

@end
