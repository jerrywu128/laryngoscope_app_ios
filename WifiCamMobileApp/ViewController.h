//
//  ViewController.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 13-12-5.
//  Copyright (c) 2013年 iCatchTech. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef NS_ENUM(NSInteger, MovieRecState) {
  MovieRecStarted,
  MovieRecStoped,
};

@class Camera;
@interface ViewController : UIViewController
/**
 * 20150630  guo.jiang
 * Deprecated !
 */
- (void)updateMovieRecState:(MovieRecState)state;
- (void)updateBatteryLevel;
- (void)stopStillCapture;
- (void)stopTimelapse;
- (void)timelapseStartedNotice;
- (void)timelapseCompletedNotice;
- (void)postMovieRecordTime;
- (void)postMovieRecordFileAddedEvent;
- (void)postFileDownloadEvent:(ICatchFile *)file;
- (void)sdFull;


@property (nonatomic, strong) Camera *savedCamera;
@end



