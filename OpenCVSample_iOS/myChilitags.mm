//  Created by 张倬豪 on 2017/11/7.
//  Copyright © 2017年 Talkit. All rights reserved.
//

// Put OpenCV include files at the top. Otherwise an error happens.
#import <opencv2/opencv.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/core/utility.hpp>
#import <opencv2/core/core_c.h>
#import <opencv2/core/core.hpp>
#import <opencv2/highgui/highgui.hpp>

// Chilitags header file
#import <chilitags.hpp>

#import <Foundation/Foundation.h>
#import <csignal>
#import <iostream>
#import <vector>

// OpenCV.h and Chilitags.h are functions of our own, they are called by ViewController
#import "myChilitags.h"


/// Converts an UIImage to Mat.
/// Orientation of the UIImage will be lost.
static void UIImageToMat(UIImage *image, cv::Mat &mat) {
    // Create a pixel buffer.
    NSInteger width = CGImageGetWidth(image.CGImage);
    NSInteger height = CGImageGetHeight(image.CGImage);
    CGImageRef imageRef = image.CGImage;
    cv::Mat mat8uc4 = cv::Mat((int)height, (int)width, CV_8UC4);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef contextRef = CGBitmapContextCreate(mat8uc4.data, mat8uc4.cols, mat8uc4.rows, 8, mat8uc4.step, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrderDefault);
    CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    // Draw all pixels to the buffer.
    cv::Mat mat8uc3 = cv::Mat((int)width, (int)height, CV_8UC3);
    cv::cvtColor(mat8uc4, mat8uc3, CV_RGBA2BGR);
    mat = mat8uc3;
    
}

/// Converts a Mat to UIImage.
static UIImage *MatToUIImage(cv::Mat &mat) {
    // Create a pixel buffer.
    assert(mat.elemSize() == 1 || mat.elemSize() == 3);
    cv::Mat matrgb;
    if (mat.elemSize() == 1) {
        cv::cvtColor(mat, matrgb, CV_GRAY2RGB);
    } else if (mat.elemSize() == 3) {
        cv::cvtColor(mat, matrgb, CV_BGR2RGB);
    }
    // Change a image format.
    NSData *data = [NSData dataWithBytes:matrgb.data length:(matrgb.elemSize() * matrgb.total())];
    CGColorSpaceRef colorSpace;
    if (matrgb.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    CGImageRef imageRef = CGImageCreate(matrgb.cols, matrgb.rows, 8, 8 * matrgb.elemSize(), matrgb.step.p[0], colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault, provider, NULL, false, kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    return image;
}

/// Restore the orientation to image.
static UIImage *RestoreUIImageOrientation(UIImage *processed, UIImage *original) {
    if (processed.imageOrientation == original.imageOrientation) {
        return processed;
    }
    return [UIImage imageWithCGImage:processed.CGImage scale:1.0 orientation:original.imageOrientation];
}

// Check whether a 3D face is facing to the camera
//by calculating the normal of the face and the rotation vector from Chilitag
static bool isInTheFront(double normal[], cv::Mat tempRvecs) {
    //std::cout << "tempRvecs" << tempRvecs << std::endl;
    std::cout << "hahahahahaha"<< (normal[0] * tempRvecs.at<double>(2, 0) + normal[1] * tempRvecs.at<double>(2, 1) + normal[2] * tempRvecs.at<double>(2, 2)) << std::endl;
    return (normal[0] * tempRvecs.at<double>(2, 0) + normal[1] * tempRvecs.at<double>(2, 1) + normal[2] * tempRvecs.at<double>(2, 2)) <= 0;
}

//calculate the size of a triangluar area
static double getTriangleArea(cv::Point2d p0, cv::Point2d p1, cv::Point2d p2) {
    cv::Point2d ab, bc;
    ab = cv::Point2d(p1.x - p0.x, p1.y - p0.y);
    bc = cv::Point2d(p2.x - p1.x, p2.y - p1.y);
    return abs((ab.x * bc.y - ab.y * bc.x) / 2.0);
}

//check if a point d is in a triangle (a,b,c)
static Boolean isInTriangle(cv::Point2d a, cv::Point2d b, cv::Point2d c, cv::Point2d d) {
    double ABS_DOUBLE_0 = 0.0001;
    double sabc, sadb, sbdc, sadc;
    sabc = getTriangleArea(a, b, c);
    sadb = getTriangleArea(a, d, b);
    sbdc = getTriangleArea(b, d, c);
    sadc = getTriangleArea(a, d, c);
    double sumSuqar = sadb + sbdc + sadc;
    if (-ABS_DOUBLE_0 < (sabc - sumSuqar) && (sabc - sumSuqar) < ABS_DOUBLE_0) {
        return true;
    } else {
        return false;
    }
}

//check if a point d in in a circle
static Boolean isInCircle(double circle_x, double circle_y, float rad, double x, double y){
    // Compare radius of circle with distance
    // of its center from given point
    if ((x - circle_x) * (x - circle_x) +
        (y - circle_y) * (y - circle_y) <= rad * rad)
        return true;
    else
        return false;
}

//check if a circle intersects with a line in triangle
static Boolean isCircleIntersectWithLine(cv::Point2d pt1, cv::Point2d pt2, double circle_x, double circle_y, float rad){
    double c1x = circle_x - pt1.x;
    double c1y = circle_y - pt1.y;
    double e1x = pt2.x - pt1.x;
    double e1y = pt2.y - pt1.y;
    double k = c1x*e1x + c1y*e1y;
    if(k > 0){
        double len = sqrt(e1x*e1x + e1y*e1y);
        k = k/len;
        if(k < len and sqrt(c1x*c1x + c1y*c1y - k*k) <= rad){
            return true;
        }
        
    }
    return false;
}


static Boolean overlapCircle(cv::Point2d pt1, cv::Point2d pt2, cv::Point2d pt3, double circle_x, double circle_y, float rad){
    //check if any vertex of the triangle is within the circle
    if (isInCircle(circle_x, circle_y, rad, pt1.x, pt1.y))
        return true;
    if (isInCircle(circle_x, circle_y, rad, pt2.x, pt2.y))
        return true;
    if (isInCircle(circle_x, circle_y, rad, pt3.x, pt3.y))
        return true;
    //check if the center of the circle is within the triangle
    if (isInTriangle(pt1, pt2, pt3, cv::Point2d(circle_x,circle_y)))
        return true;
    //check if the circle intersects with any line
    if (isCircleIntersectWithLine(pt1, pt2, circle_x, circle_y, rad))
        return true;
    if (isCircleIntersectWithLine(pt2, pt3, circle_x, circle_y, rad))
        return true;
    if (isCircleIntersectWithLine(pt1, pt1, circle_x, circle_y, rad))
        return true;
    return false;
}


// fulfill the functions of our own using Chilitags or the function above
@implementation myChilitags


//variables for chilitag
chilitags::Chilitags3D chilitags3D;
cv::Mat rVec(3, 3, cv::DataType<double>::type);
cv::Mat tVec(3, 1, cv::DataType<double>::type);
cv::Mat transformationMatrix;
cv::Mat MaskedImage;

Boolean hasReadConfig = false;
Boolean hasReadJSON = false;
//Boolean redDetected = false;
float redRadius = 0;
double redPositionX = -1;
double redPositionY = -1;
double preRedPositionX = -1;
double preRedPositionY = -1;
double timestamp_preStamp = 0;
//double minX, minY, maxX, maxY;

#define STATUS_NOMODEL -1 //no model in the image
#define STATUS_HASMODEL 3 //model detected
#define STATUS_NOFINGER -2
#define STATUS_HASFINGER 1

#define STATUS_HIT 0 //detected red and finger is on marked label
#define STATUS_MISS 1 //detected red and finger is not on markded label
#define STATUS_FAIL 2 //no red detected
int model_status = -1;
int finger_status = -2;
int pre_move_status = 1;
int current_move_status ;
double timestamp_firststay;
double timestamp_checkposition = 0;
#define STATUS_MOVE 1
#define STATUS_STAY 0
int move_count = 0;
int stay_count = 0;
int last_model_status = -100;
int last_finger_status = -100;


//setting variables for calibration
//number of boards
int numBoards = 8; //currently, the number is controlled by the viewcontroller
//number of corners along width
int numCornersHor = 9;
//number of corners along height
int numCornersVer = 6;
//additional variables for the board
int numSquares = numCornersHor * numCornersVer;
cv::Size board_sz = cv::Size(numCornersHor,numCornersVer);
cv::TermCriteria criteria = cv::TermCriteria(CV_TERMCRIT_EPS | CV_TERMCRIT_ITER, 30, 0.1);
bool hasCalibrated = false;

//the points of a board
std::vector<cv::Point3f> objp;
//a container to temporarily hold the current snapshot's chessboard corners
std::vector<cv::Point2f> corners;
//a list of the points of different boards
std::vector<std::vector<cv::Point3f>> objpts;
//a list of the corners of different boards
std::vector<std::vector<cv::Point2f>> imgpts;


cv::Mat intrinsicMat = cv::Mat(3, 3, cv::DataType<double>::type);
cv::Mat distCoeffs = cv::Mat(5, 1, cv::DataType<double>::type);

//variables for models
struct Face {
    Boolean marked;
    int faceIndex;
    std::vector<int> nearFacesIndexes;
    std::vector<cv::Point3d> verts;
    std::vector<cv::Point2d> projectedVerts;
    NSString* label;
    NSString* content;
    double normal[3];
    cv::Scalar color;
};
std::vector<Face> modelFaces;
std::vector<Face> visibleFaces;
std::vector<Face> possibleFaces;
//variables for judging moving
std::vector<Face> activatedHistory;
Boolean labelSpoken = false;

//variables for 3D to 2D transmation
std::vector<cv::Point3d> objectPoints;
std::vector<cv::Point2d> imagePoints;
std::vector<cv::Point2i> visible_2d;

std::vector<NSString*> currentLabels;
std::vector<NSString*> currentContents;

Boolean alwaysFront = false;

+ (void) alwaysFrontOn{
    alwaysFront = true;
}

+ (void) alwaysFrontOff{
    alwaysFront = false;
}

+ (void)reloadSettings:(nonnull NSString *)configFilePath modelAt:(nonnull NSString*) modelFilePath{
    const char * configFile = NULL;
    
    if ([configFilePath canBeConvertedToEncoding:NSUTF8StringEncoding]) {
        configFile = [configFilePath cStringUsingEncoding:NSUTF8StringEncoding];
    }
    if (true) {
        chilitags3D.readTagConfiguration(configFile);
        hasReadConfig = true;
        
        //initialize distCoeffes
        distCoeffs.at<double>(0) = 0.302479;
        distCoeffs.at<double>(1) = -2.42986;
        distCoeffs.at<double>(2) = 0.000656226;
        distCoeffs.at<double>(3) = -0.00557037;
        distCoeffs.at<double>(4) = 5.22657;
    }
    
    if (true) {
        NSString* jsonString = [[NSString alloc] initWithContentsOfFile:modelFilePath encoding:NSUTF8StringEncoding error:nil];
        NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
        NSDictionary* faces = [dic objectForKey:@"faces"];
        hasReadJSON = true;
        
        modelFaces.clear();
        for (NSString *key in faces) {
            Face currentFace;
            NSDictionary *face = [faces objectForKey:key];
            NSString *marked = [face objectForKey:@"marked"];
            //check the marked and color for the face
            if ([marked boolValue]){
                currentFace.marked = true;
                NSDictionary *colorDic = [face objectForKey:@"color"];
                NSString *color_r = [colorDic objectForKey:@"r"];
                NSString *color_g = [colorDic objectForKey:@"g"];
                NSString *color_b = [colorDic objectForKey:@"b"];
                currentFace.color = cv::Scalar(color_r.doubleValue, color_g.doubleValue, color_b.doubleValue);
                
            }
            else {
                currentFace.marked = false;
                //currentFace.color = nil;
            }
            
            //check the label and content for the face
            NSString *label = [face objectForKey:@"label"];
            NSString *content = [face objectForKey:@"content"];
            currentFace.label = label;
            currentFace.content = content;
            
            //check the normal for the face
            NSDictionary *normalDic = [face objectForKey:@"normal"];
            NSString *normal_x = [normalDic objectForKey:@"x"];
            NSString *normal_y = [normalDic objectForKey:@"y"];
            NSString *normal_z = [normalDic objectForKey:@"z"];
            currentFace.normal[0] = normal_x.doubleValue;
            currentFace.normal[1] = normal_y.doubleValue;
            currentFace.normal[2] = normal_z.doubleValue;
            
            //check the normal for the face
            NSString *num;
            num = [face objectForKey:@"index"];
            currentFace.faceIndex = num.intValue;
            
            //check the indexes of near faces
            std::vector<int> tempIndexes;
            tempIndexes.clear();
            NSDictionary* nearIndexes = [face objectForKey:@"nearFaces"];
            for (NSString *indexKey in nearIndexes)
            {
                NSString *one_near_indexTemp = [nearIndexes objectForKey:indexKey];
                tempIndexes.push_back(one_near_indexTemp.intValue);
            }
            currentFace.nearFacesIndexes = tempIndexes;
            
            //check the verts for three points
            NSDictionary *vertsDic = [face objectForKey:@"verts"];
            NSDictionary *vert1 = [vertsDic objectForKey:@"vert1"];
            NSDictionary *vert2 = [vertsDic objectForKey:@"vert2"];
            NSDictionary *vert3 = [vertsDic objectForKey:@"vert3"];
            double tempx, tempy, tempz;
            num = [vert1 objectForKey:@"x"];
            tempx = num.doubleValue;
            num = [vert1 objectForKey:@"y"];
            tempy = num.doubleValue;
            num = [vert1 objectForKey:@"z"];
            tempz = num.doubleValue;
            currentFace.verts.push_back(cv::Point3d(tempx, tempy, tempz));
            num = [vert2 objectForKey:@"x"];
            tempx = num.doubleValue;
            num = [vert2 objectForKey:@"y"];
            tempy = num.doubleValue;
            num = [vert2 objectForKey:@"z"];
            tempz = num.doubleValue;
            currentFace.verts.push_back(cv::Point3d(tempx, tempy, tempz));
            num = [vert3 objectForKey:@"x"];
            tempx = num.doubleValue;
            num = [vert3 objectForKey:@"y"];
            tempy = num.doubleValue;
            num = [vert3 objectForKey:@"z"];
            tempz = num.doubleValue;
            currentFace.verts.push_back(cv::Point3d(tempx, tempy, tempz));
            
            modelFaces.push_back(currentFace);
            
        }
    }
    
}

//load the configfile for chilitag, and the model file,
//TEMP set the default value of disCoeffs
//convert the data from the model file into modelFaces
+ (void)loadSettings:(nonnull NSString *)configFilePath modelAt:(nonnull NSString*) modelFilePath{
    const char * configFile = NULL;
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
    NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
    timestamp_preStamp = timeStampObj.doubleValue;
    
    
    if ([configFilePath canBeConvertedToEncoding:NSUTF8StringEncoding]) {
        configFile = [configFilePath cStringUsingEncoding:NSUTF8StringEncoding];
    }
    if (!hasReadConfig) {
        chilitags3D.readTagConfiguration(configFile);
        hasReadConfig = true;
        
        //initialize distCoeffes
        distCoeffs.at<double>(0) = 0.302479;
        distCoeffs.at<double>(1) = -2.42986;
        distCoeffs.at<double>(2) = 0.000656226;
        distCoeffs.at<double>(3) = -0.00557037;
        distCoeffs.at<double>(4) = 5.22657;
    }
    
    if (!hasReadJSON) {
        NSString* jsonString = [[NSString alloc] initWithContentsOfFile:modelFilePath encoding:NSUTF8StringEncoding error:nil];
        NSData* jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary* dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:nil];
        NSDictionary* faces = [dic objectForKey:@"faces"];
        hasReadJSON = true;
        
        modelFaces.clear();
        for (NSString *key in faces) {
            Face currentFace;
            NSDictionary *face = [faces objectForKey:key];
            NSString *marked = [face objectForKey:@"marked"];
            //check the marked and color for the face
            if ([marked boolValue]){
                currentFace.marked = true;
                NSDictionary *colorDic = [face objectForKey:@"color"];
                NSString *color_r = [colorDic objectForKey:@"r"];
                NSString *color_g = [colorDic objectForKey:@"g"];
                NSString *color_b = [colorDic objectForKey:@"b"];
                currentFace.color = cv::Scalar(color_r.doubleValue, color_g.doubleValue, color_b.doubleValue);
                
            }
            else {
                currentFace.marked = false;
                //currentFace.color = nil;
            }
            
            //check the label and content for the face
            NSString *label = [face objectForKey:@"label"];
            NSString *content = [face objectForKey:@"content"];
            currentFace.label = label;
            currentFace.content = content;
            
            //check the normal for the face
            NSDictionary *normalDic = [face objectForKey:@"normal"];
            NSString *normal_x = [normalDic objectForKey:@"x"];
            NSString *normal_y = [normalDic objectForKey:@"y"];
            NSString *normal_z = [normalDic objectForKey:@"z"];
            currentFace.normal[0] = normal_x.doubleValue;
            currentFace.normal[1] = normal_y.doubleValue;
            currentFace.normal[2] = normal_z.doubleValue;
            
            //check the normal for the face
            NSString *num;
            num = [face objectForKey:@"index"];
            currentFace.faceIndex = num.intValue;
            
            //check the indexes of near faces
            std::vector<int> tempIndexes;
            tempIndexes.clear();
            NSDictionary* nearIndexes = [face objectForKey:@"nearFaces"];
            for (NSString *indexKey in nearIndexes)
            {
                NSString *one_near_indexTemp = [nearIndexes objectForKey:indexKey];
                tempIndexes.push_back(one_near_indexTemp.intValue);
            }
            currentFace.nearFacesIndexes = tempIndexes;
            
            //check the verts for three points
            NSDictionary *vertsDic = [face objectForKey:@"verts"];
            NSDictionary *vert1 = [vertsDic objectForKey:@"vert1"];
            NSDictionary *vert2 = [vertsDic objectForKey:@"vert2"];
            NSDictionary *vert3 = [vertsDic objectForKey:@"vert3"];
            double tempx, tempy, tempz;
            num = [vert1 objectForKey:@"x"];
            tempx = num.doubleValue;
            num = [vert1 objectForKey:@"y"];
            tempy = num.doubleValue;
            num = [vert1 objectForKey:@"z"];
            tempz = num.doubleValue;
            currentFace.verts.push_back(cv::Point3d(tempx, tempy, tempz));
            num = [vert2 objectForKey:@"x"];
            tempx = num.doubleValue;
            num = [vert2 objectForKey:@"y"];
            tempy = num.doubleValue;
            num = [vert2 objectForKey:@"z"];
            tempz = num.doubleValue;
            currentFace.verts.push_back(cv::Point3d(tempx, tempy, tempz));
            num = [vert3 objectForKey:@"x"];
            tempx = num.doubleValue;
            num = [vert3 objectForKey:@"y"];
            tempy = num.doubleValue;
            num = [vert3 objectForKey:@"z"];
            tempz = num.doubleValue;
            currentFace.verts.push_back(cv::Point3d(tempx, tempy, tempz));
            
            modelFaces.push_back(currentFace);
            
        }
    }
    
}

//return true if has loaded the file
+ (bool)checkSettings {
    return hasReadConfig and hasReadJSON;
}

//update intrinsicMatrix with the data from camera
+ (void)updateIntrinsicMatrix: (float)fx fy:(float)fy ox:(float)ox oy:(float)oy {
    intrinsicMat.at<double>(0, 0) = fx;
    intrinsicMat.at<double>(0, 1) = 0.0;
    intrinsicMat.at<double>(0, 2) = ox;
    intrinsicMat.at<double>(1, 0) = 0.0;
    intrinsicMat.at<double>(1, 1) = fy;
    intrinsicMat.at<double>(1, 2) = oy;
    intrinsicMat.at<double>(2, 0) = 0.0;
    intrinsicMat.at<double>(2, 1) = 0.0;
    intrinsicMat.at<double>(2, 2) = 1.0;
    chilitags3D.setCalibration(intrinsicMat,distCoeffs);
}

double gifRes[8];

+ (void)processImage:(nonnull UIImage *)image {
    cv::Mat inputImageMat, outputImageMat;
    UIImageToMat(image, inputImageMat);
    model_status = STATUS_NOMODEL;
    for (auto& kv : chilitags3D.estimate(inputImageMat)) {
        //std::cout << kv.first << " at " << cv::Mat(kv.second) << "\n";
        if (kv.first == "myobject") {
            model_status = STATUS_HASMODEL;
            
            transformationMatrix = cv::Mat(kv.second);
            //   Rotation vector
            for (int i = 0; i < 3; i++) {
                for (int j = 0; j < 3; j++) {
                    rVec.at<double>(i, j) = transformationMatrix.at<float>(i, j);
                    //NSLog(@"%d, %d, %f", i, j, rVec.at<double>(i, j));
                }
            }
            
            
            // Translation vector
            tVec.at<double>(0) = transformationMatrix.at<float>(0, 3);
            tVec.at<double>(1) = transformationMatrix.at<float>(1, 3);
            tVec.at<double>(2) = transformationMatrix.at<float>(2, 3);
            NSLog(@"%f, %f, %f", tVec.at<double>(0), tVec.at<double>(1), tVec.at<double>(2));
            
            //process model data
            objectPoints.clear();
            imagePoints.clear();
            visibleFaces.clear();
            possibleFaces.clear();
            
            //find visibleFaces from modelFacees
            for (auto& singleFace :modelFaces) {
                if (alwaysFront or isInTheFront(singleFace.normal, rVec)) {
                    visibleFaces.push_back(singleFace);
                    objectPoints.push_back(singleFace.verts[0]);
                    objectPoints.push_back(singleFace.verts[1]);
                    objectPoints.push_back(singleFace.verts[2]);
                }
            }
            
            visible_2d.clear();
            //convert 3D visible points to 2D visible points
            cv::projectPoints(objectPoints, rVec, tVec, intrinsicMat, distCoeffs, imagePoints);
            for (int i = 0; i < visibleFaces.size(); i++) {
                visibleFaces[i].projectedVerts.push_back(imagePoints[3 * i + 0]);
                visibleFaces[i].projectedVerts.push_back(imagePoints[3 * i + 1]);
                visibleFaces[i].projectedVerts.push_back(imagePoints[3 * i + 2]);
                visible_2d.push_back(cv::Point2i(imagePoints[3 * i + 0]));
                visible_2d.push_back(cv::Point2i(imagePoints[3 * i + 1]));
                visible_2d.push_back(cv::Point2i(imagePoints[3 * i + 2]));
            }
            
            
            //detect the finger using the red color
            //first mask the image using a fillpoly method
            //std::vector<cv::Point2d> hull;
            std::vector<cv::Point2i> hull;
            cv::convexHull(visible_2d, hull);
            
            cv::Mat tempMask = cv::Mat((int)CGImageGetHeight(image.CGImage), (int)CGImageGetWidth(image.CGImage), CV_8UC3);
            MaskedImage = cv::Mat((int)CGImageGetHeight(image.CGImage), (int)CGImageGetWidth(image.CGImage), CV_8UC3);
            
            std::vector<std::vector<cv::Point2i> > fillContAll;
            fillContAll.push_back(hull);
            cv::fillPoly(tempMask, fillContAll, cv::Scalar(255, 255,255));
            cv::bitwise_and(tempMask, inputImageMat, MaskedImage);
            
            cv::Mat inputImageMat = MaskedImage, imgHSV, imgThresholded ,imgThresholded_filter1, imgThresholded_filter2 ;
            
            finger_status = STATUS_NOFINGER;
            
            int iLowH_filter1 = 165;
            int iHighH_filter1 = 180;
            
            int iLowH_filter2 = 0;
            int iHighH_filter2 = 3;
            
            int iLowS = 149;
            int iHighS = 255;
            
            int iLowV = 101;
            int iHighV = 255;
            
            // OpenCv can draw with sub-pixel precision with fixed point coordinates
            
            cvtColor(inputImageMat, imgHSV, cv::COLOR_BGR2HSV); //Convert the captured frame from BGR to HSV
            
            cv::inRange(imgHSV, cv::Scalar(iLowH_filter1, iLowS, iLowV), cv::Scalar(iHighH_filter1, iHighS, iHighV), imgThresholded_filter1); //Threshold the image
            cv::inRange(imgHSV, cv::Scalar(iLowH_filter2, iLowS, iLowV), cv::Scalar(iHighH_filter2, iHighS, iHighV), imgThresholded_filter2); //Threshold the image
            cv::addWeighted(imgThresholded_filter1, 1.0, imgThresholded_filter2, 1.0, 0.0, imgThresholded);
            
            
            //morphological opening (removes small objects from the foreground)
            erode(imgThresholded, imgThresholded, getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5)) );
            dilate( imgThresholded, imgThresholded, getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5)) );
            
            //morphological closing (removes small holes from the foreground)
            dilate( imgThresholded, imgThresholded, getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5)) );
            erode(imgThresholded, imgThresholded, getStructuringElement(cv::MORPH_ELLIPSE, cv::Size(5, 5)) );
            std::vector<std::vector<cv::Point> > contours;
            std::vector<cv::Vec4i> hierarchy;
            cv::GaussianBlur(imgThresholded, imgThresholded, cv::Size(3,3), 0);
            cv::findContours(imgThresholded, contours, hierarchy, CV_RETR_TREE, CV_CHAIN_APPROX_SIMPLE );
            if(contours.size() > 0){
                NSLog(@"got ya");
                // find the largest contour in the mask, then use
                // it to compute the minimum enclosing circle and centroid
                double largest_area = 0;
                int largest_contour_index = -1;
                for (int i = 0; i< contours.size(); i++) // iterate through each contour.
                {
                    double a = contourArea(contours[i], false);  //  Find the area of contour
                    if (a>largest_area){
                        largest_area = a;
                        largest_contour_index = i;                //Store the index of largest contour
                    }
                }
                //deel with the largest contour
                cv::Point2f center;
                float radius;
                cv::minEnclosingCircle( contours[largest_contour_index], center, radius);
                //redimage = imgThresholded;
                //cv::circle(redimage, center, (int)radius, cv::Scalar(255, 255, 255), 20);
                finger_status = STATUS_HASFINGER;
                redPositionX = center.x;
                redPositionY = center.y;
                redRadius = radius;
            }
    
        }
    }
}

+ (void) detectLabel {
    
    if (finger_status == STATUS_HASFINGER)
    {
        //calculate the speed of the moving
        double distance, speed, time;
        distance = (redPositionX-preRedPositionX)*(redPositionX-preRedPositionX) +
        (redPositionY-preRedPositionY)*(redPositionY-preRedPositionY);
        
        preRedPositionX = redPositionX;
        preRedPositionY = redPositionY;
        NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
        NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
        time = timeStampObj.doubleValue - timestamp_preStamp;
        timestamp_preStamp = timeStampObj.doubleValue;
        
        //determine the curreent status based on the speed
        speed = distance/time;
        //std::cout<< speed << std::endl;
        if (speed <800){
            current_move_status = STATUS_STAY;
        }
        else{
            current_move_status = STATUS_MOVE;
        }
    }
}


+ (NSString *)getLabels {
    if(model_status == STATUS_NOMODEL) return @"No Speak";
    if(finger_status == STATUS_NOFINGER) return @"No Speak";
    
    //get the current label
    //if it's moving then return "no speak"
    if(pre_move_status == STATUS_MOVE and current_move_status == STATUS_MOVE) return @"No Speak";
    //change from stay to move, reset labelSpoken
    if(pre_move_status == STATUS_STAY and current_move_status == STATUS_MOVE){
        labelSpoken = false;
        pre_move_status = current_move_status;
        return @"No Speak";
    }
    //change from move to stay
    if(pre_move_status == STATUS_MOVE and current_move_status == STATUS_STAY){
        NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
        NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
        timestamp_firststay = timeStampObj.doubleValue;
        pre_move_status = current_move_status;
        return @"No Speak";
    }
    Boolean havelabel = false;
    if(pre_move_status == STATUS_STAY and current_move_status == STATUS_STAY){
        NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
        NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
        double timelap = timeStampObj.doubleValue - timestamp_firststay;
        if(timelap > 0.2 and labelSpoken ==false){
            labelSpoken =true;
            havelabel = true;
        }
        else{
            return @"No Speak";
        }
    }
    //start detection
    if(havelabel){
        for (int i = 0; i < visibleFaces.size(); i++) {
            if (overlapCircle(visibleFaces[i].projectedVerts[0],
                              visibleFaces[i].projectedVerts[1],
                              visibleFaces[i].projectedVerts[2],
                              redPositionX,redPositionY,redRadius)
                and visibleFaces[i].marked) {
                possibleFaces.push_back(visibleFaces[i]);
            }
        }
        //there is no label
        if (possibleFaces.size() == 0) {
            return @"m_nolabel";
        }
        //check how many possible faces
        if (possibleFaces.size() == 1) {
            std::string tempLabel = std::string([possibleFaces[0].label UTF8String]);
            std::string tempContent = std::string([possibleFaces[0].content UTF8String]);
            std::string tempString = tempLabel + "@" + tempContent;
            NSString *res = [NSString stringWithCString:tempString.c_str() encoding:[NSString defaultCStringEncoding]];
            return res;
        }
        //if there are more than one possible faces
        else{
            std::set<std::string> uniqueFaceLabels;
            uniqueFaceLabels.clear();
            for (auto& temp: possibleFaces) {
                uniqueFaceLabels.insert(std::string([temp.label UTF8String]));
            }
            //if there is only one label
            if (uniqueFaceLabels.size()==1){
                std::string tempLabel = std::string([possibleFaces[0].label UTF8String]);
                std::string tempContent = std::string([possibleFaces[0].content UTF8String]);
                std::string tempString = tempLabel + "@" + tempContent;
                NSString *res = [NSString stringWithCString:tempString.c_str() encoding:[NSString defaultCStringEncoding]];
                return res;
            }
            //if there are more than one labels
            else{
                std::vector<Face> activatedFaces;
                activatedFaces.clear();
                //check the distance
                //find the nearest face
                std::vector<double> distance;
                distance.clear();
                for (int i = 0; i < possibleFaces.size(); i++) {
                    double res = transformationMatrix.at<float>(2, 0) * possibleFaces[i].verts[0].x +
                    transformationMatrix.at<float>(2, 1) * possibleFaces[i].verts[0].y +
                    transformationMatrix.at<float>(2, 2) * possibleFaces[i].verts[0].z +
                    transformationMatrix.at<float>(2, 3);
                    distance.push_back(res);
                }
                double minDistance = distance[0];
                int minIndex = 0;
                for (int i = 1; i < distance.size(); i++) {
                    if (distance[i] < minDistance) {
                        minDistance = distance[i];
                        minIndex = i;
                    }
                }
                Face nearestFace = possibleFaces[minIndex];
                cv::Point3d centroidnearestFace = (nearestFace.verts[0] + nearestFace.verts[1] + nearestFace.verts[2])/3.0;
                for (auto& singleFace :possibleFaces) {
                    //find the distance betweeen two faces
                    cv::Point3d centroidSingleFace = (singleFace.verts[0] + singleFace.verts[1] + singleFace.verts[2])/3.0;
                    double dis = cv::norm(cv::Mat(centroidnearestFace),cv::Mat(centroidSingleFace));
                    if (dis <= 20){
                        activatedFaces.push_back(singleFace);
                    }
                }
                uniqueFaceLabels.clear();
                for (auto& temp: activatedFaces) {
                    uniqueFaceLabels.insert(std::string([temp.label UTF8String]));
                }
                std::set<std::string>::iterator iter;
                std::string tempLabel = "";
                std::string tempContent = "";
                int count = 0;
                for (iter = uniqueFaceLabels.begin(); iter != uniqueFaceLabels.end(); iter++) {
                        tempLabel.append(*iter);
                        tempLabel.append("     ");
                        count++;
                }
                if(count == 1){
                    tempLabel = std::string([activatedFaces[0].label UTF8String]);
                    tempContent = std::string([activatedFaces[0].content UTF8String]);
                }
                //if there are more than one remaining label
                if (count > 1) {
                    tempLabel = std::to_string(count) + "     " + tempLabel;
                    tempContent = "please find one label";
                }
                std::string tempString = tempLabel + "@" +tempContent;
                NSString *res = [NSString stringWithCString:tempString.c_str() encoding:[NSString defaultCStringEncoding]];
                return res;
            }
        }
    }
    return @"No Speak";
}

// prepare vis
+ (nonnull UIImage *)getVisulizedImage:(nonnull UIImage *)image {
    cv::Mat inputImageMat, outputImageMat;
    UIImage *outputImage;
    UIImageToMat(image, inputImageMat);
    outputImageMat = inputImageMat.clone();
    //if there is no model
    if (model_status == STATUS_NOMODEL){
        return image;
    }
    //if there is a model
    else{
        //start redenring output data
//        static const int SHIFT = 16;
//        static const float PRECISION = 1<<SHIFT;
//            for (int i = 0; i < visibleFaces.size(); i++) {
//                if(visibleFaces[i].marked){
//                    // fill the shape instead of drawing the outline
////                    cv::line(outputImageMat,PRECISION * visibleFaces[i].projectedVerts[0],PRECISION * visibleFaces[i].projectedVerts[1], visibleFaces[i].color, 1, cv::LINE_AA, SHIFT);
////                    cv::line(outputImageMat,PRECISION * visibleFaces[i].projectedVerts[1],PRECISION * visibleFaces[i].projectedVerts[2],visibleFaces[i].color, 1, cv::LINE_AA, SHIFT);
////                    cv::line(outputImageMat,PRECISION * visibleFaces[i].projectedVerts[2],PRECISION * visibleFaces[i].projectedVerts[0],visibleFaces[i].color, 1, cv::LINE_AA, SHIFT);
//                    //cv::fillPoly(outputImageMat, visibleFaces[i].projectedVerts, visibleFaces[i].color);
//                    cv::Point tempPoints[1][3];
//                    tempPoints[0][0] = visibleFaces[i].projectedVerts[0];
//                    tempPoints[0][1] = visibleFaces[i].projectedVerts[1];
//                    tempPoints[0][2] = visibleFaces[i].projectedVerts[2];
//                    const cv::Point* ppt[1] = {tempPoints[0]};
//                    int npt[] = {3};
//                    //cv::fillPoly(outputImageMat, ppt, npt, 1, visibleFaces[i].color);
//                }
//                else{
//                        //don't draw unmarked faces
//                    }
//            }
//
//            //draw activated faces (possibly change the annimation?
//            if(possibleFaces.size() > 0){
//                std::vector<std::vector<cv::Point2i>> pts;
//                pts.clear();
//                for (auto& singleFace :possibleFaces) {
//                    std::vector<cv::Point2i> temp_pts;
//                    temp_pts.clear();
//                    temp_pts.push_back(cv::Point2i(singleFace.projectedVerts[0]));
//                    temp_pts.push_back(cv::Point2i(singleFace.projectedVerts[1]));
//                    temp_pts.push_back(cv::Point2i(singleFace.projectedVerts[2]));
//                    pts.push_back(temp_pts);
//                }
//                cv::fillPoly(outputImageMat, pts, cv::Scalar(255, 255,0));
//            }

            //draw finger position
        if (finger_status == STATUS_HASFINGER){
            cv::circle(outputImageMat, cv::Point2d(redPositionX, redPositionY), (int)redRadius, cv::Scalar(0, 255, 0), 20);
        }
        
    }
    
    outputImage = MatToUIImage(outputImageMat);
    //outputImage = MatToUIImage(redimage);
    return RestoreUIImageOrientation(outputImage, image);
}


+ (NSString *)checkPosition {
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
    NSNumber *timeStampObj = [NSNumber numberWithDouble: timeStamp];
    if(timeStampObj.doubleValue - timestamp_checkposition> 10){
        timestamp_checkposition = timeStampObj.doubleValue;
        //check if there is a model
        if(model_status == STATUS_NOMODEL) return @"no model";
        
        //check if there is a finger
        if(finger_status == STATUS_NOFINGER) return @"no finger";
        
        return @"correct";
    }
    //std::cout<< "correct" << std::endl;
    return @"correct";
}




+ (void)preSetupCalibration {
    for(int j=0;j<numSquares;j++)
        objp.push_back(cv::Point3f(j/numCornersHor, j%numCornersHor, 0.0f));
}

+ (bool)setupCalibration:(nonnull UIImage *) image {
    cv::Mat inputImageMat, grayMat;
    UIImageToMat(image, inputImageMat);
    
    //convert images to gray color
    cv::cvtColor(inputImageMat, grayMat, cv::COLOR_BGR2GRAY);
    
    bool found = cv::findChessboardCorners(grayMat, board_sz, corners, CV_CALIB_CB_ADAPTIVE_THRESH | CV_CALIB_CB_FILTER_QUADS);
    
    //if not found, return false
    //if found checkerboard, add the objp and corners to the current data
    if (!found) return false;
    else {
        //std::cout<< "find checkerboard" << std::endl;
        cv::cornerSubPix(grayMat, corners, cv::Size(5, 5), cv::Size(-1, -1), criteria);
        objpts.push_back(objp);
        imgpts.push_back(corners);
        return true;
    }
}

+ (void)doCalibration:(nonnull UIImage *)image {
    cv::calibrateCamera(objpts, imgpts, cv::Size( CGImageGetWidth(image.CGImage),CGImageGetHeight(image.CGImage)), intrinsicMat, distCoeffs, rVec, tVec);
    //output the result
    //for (int i=0;i<5;i++) std::cout<< distCoeffs.at<double>(i) << " ";
    hasCalibrated = true;
}

+ (nonnull NSString *)getGifResults {
    //calculate the gifresults
    std::vector<cv::Point3d> gifPoints;
    std::vector<cv::Point2d> gifResults;
    gifPoints.clear();
    gifResults.clear();
    gifPoints.push_back(cv::Point3d(-31.168, -96.054, 0.001));
    gifPoints.push_back(cv::Point3d(118.084, -96.054, 0.006));
    gifPoints.push_back(cv::Point3d(118.084, 12.000, 0.006));
    gifPoints.push_back(cv::Point3d(-31.168, 12.000, 0.001));
    cv::projectPoints(gifPoints, rVec, tVec, intrinsicMat, distCoeffs, gifResults);
    
    
    gifRes[0] = gifResults[0].x;
    gifRes[1] = gifResults[0].y;
    //std::cout<< "left top" <<gifResults[0].x<<" "<<gifResults[0].y<< std::endl;
    gifRes[2] = gifResults[1].x;
    gifRes[3] = gifResults[1].y;
    //std::cout<< "top right" <<gifResults[1].x<<" "<<gifResults[1].y<< std::endl;
    gifRes[4] = gifResults[2].x;
    gifRes[5] = gifResults[2].y;
    //std::cout<< "bottom right" <<gifResults[2].x<<" "<<gifResults[2].y<< std::endl;
    gifRes[6] = gifResults[3].x;
    gifRes[7] = gifResults[3].y;
    //std::cout<< "bottom left" <<gifResults[3].x<<" "<<gifResults[3].y<< std::endl;
    
    NSString *res = @"";
    NSString *stringFloat = [NSString stringWithFormat:@"%lf@", gifRes[0]];
    res = [res stringByAppendingString: stringFloat];
    stringFloat = [NSString stringWithFormat:@"%lf@", gifRes[1]];
    res = [res stringByAppendingString: stringFloat];
    stringFloat = [NSString stringWithFormat:@"%lf@", gifRes[2]];
    res = [res stringByAppendingString: stringFloat];
    stringFloat = [NSString stringWithFormat:@"%lf@", gifRes[3]];
    res = [res stringByAppendingString: stringFloat];
    stringFloat = [NSString stringWithFormat:@"%lf@", gifRes[4]];
    res = [res stringByAppendingString: stringFloat];
    stringFloat = [NSString stringWithFormat:@"%lf@", gifRes[5]];
    res = [res stringByAppendingString: stringFloat];
    stringFloat = [NSString stringWithFormat:@"%lf@", gifRes[6]];
    res = [res stringByAppendingString: stringFloat];
    stringFloat = [NSString stringWithFormat:@"%lf", gifRes[7]];
    res = [res stringByAppendingString: stringFloat];
    return res;
}

@end
