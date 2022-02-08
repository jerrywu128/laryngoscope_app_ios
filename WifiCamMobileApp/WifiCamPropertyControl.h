//
//  WifiCamPropertyControl.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-6-23.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WifiCamAlertTable.h"
#import "WifiCamAVData.h"

@interface WifiCamPropertyControl : NSObject

// Inquire state info
//- (BOOL)isMediaStreamRecording;
//-(BOOL)isVideoTimelapseOn;
//-(BOOL)isStillTimelapseOn;
- (BOOL)connected;
- (BOOL)checkSDExist;
- (BOOL)videoStreamEnabled;
- (BOOL)audioStreamEnabled;

// Change those property value
-(int)changeImageSize:(string)size;
-(int)changeVideoSize:(string)size;
-(int)changeDelayedCaptureTime:(unsigned int)time;
-(int)changeWhiteBalance:(unsigned int)value;
-(int)changeLightFrequency:(unsigned int)value;
-(int)changeBurstNumber:(unsigned int)value;
-(int)changeDateStamp:(unsigned int)value;
-(int)changeTimelapseType:(ICatchPreviewMode)mode;
-(int)changeTimelapseInterval:(unsigned int)value;
-(int)changeTimelapseDuration:(unsigned int)value;
-(int)changeUpsideDown:(uint)value;
-(int)changeSlowMotion:(uint)value;
-(BOOL)changeSSID:(NSString *)ssid;
-(BOOL)changePassword:(NSString *)password;
-(BOOL)changeBrightness:(unsigned int)value;
-(BOOL)changeHue:(unsigned int)value;
-(BOOL)changeSaturation:(unsigned int)value;
-(BOOL)changeBLC:(BOOL)value;
-(BOOL)PhotoCapture;
-(BOOL)saveIQvalue;

- (BOOL)changeScreenSaver:(uint)curScreenSaver;
- (uint)parseScreenSaverInArray:(NSInteger)index;
- (BOOL)changeAutoPowerOff:(uint)curAutoPowerOff;
- (uint)parseAutoPowerOffInArray:(NSInteger)index;
- (BOOL)changeExposureCompensation:(uint)curExposureCompensation;
- (uint)parseExposureCompensationInArray:(NSInteger)index;
- (BOOL)changeVideoFileLength:(uint)curVideoFileLength;
- (uint)parseVideoFileLengthInArray:(NSInteger)index;
- (BOOL)changeFastMotionMovie:(uint)curFastMotionMovie;
- (uint)parseFastMotionMovieInArray:(NSInteger)index;
   
// Figure out property value using index value within array
-(unsigned int)parseDelayCaptureInArray:(NSInteger)index;
-(string)parseImageSizeInArray:(NSInteger)index;
-(string)parseVideoSizeInArray:(NSInteger)index;
-(string)parseTimeLapseVideoSizeInArray:(NSInteger)index;
-(unsigned int)parseWhiteBalanceInArray:(NSInteger)index;
-(unsigned int)parsePowerFrequencyInArray:(NSInteger)index;
-(unsigned int)parseBurstNumberInArray:(NSInteger)index;
-(unsigned int)parseDateStampInArray:(NSInteger)index;
-(unsigned int)parseTimelapseIntervalInArray:(NSInteger)index;
-(unsigned int)parseTimelapseDurationInArray:(NSInteger)index;

// Assemble those infomation into an container
-(NSArray *)prepareDataForStorageSpaceOfImage:(string)imageSize;
-(NSArray *)prepareDataForStorageSpaceOfVideo:(string)videoSize;
-(WifiCamAlertTable *)prepareDataForDelayCapture:(unsigned int)curDelayCapture;
-(WifiCamAlertTable *)prepareDataForImageSize:(string)curImageSize;
-(WifiCamAlertTable *)prepareDataForVideoSize:(string)curVideoSize;
-(WifiCamAlertTable *)prepareDataForTimeLapseVideoSize:(string)curVideoSize;
-(WifiCamAlertTable *)prepareDataForLightFrequency:(unsigned int)curLightFrequency;
-(WifiCamAlertTable *)prepareDataForWhiteBalance:(unsigned int)curWhiteBalance;
-(WifiCamAlertTable *)prepareDataForBurstNumber:(unsigned int)curBurstNumber;
-(WifiCamAlertTable *)prepareDataForDateStamp:(unsigned int)curDateStamp;
-(NSString *)calcImageSizeToNum:(NSString *)size;

-(ICatchVideoFormat)retrieveVideoFormat;
-(ICatchAudioFormat)retrieveAudioFormat;
-(WifiCamAVData *)prepareDataForPlaybackVideoFrame;
-(WifiCamAVData *)prepareDataForPlaybackAudioTrack;
- (ICatchFrameBuffer *)prepareDataForPlaybackAudioTrack1;
-(ICatchVideoFormat)retrievePlaybackVideoFormat;
-(ICatchAudioFormat)retrievePlaybackAudioFormat;
-(NSString *)prepareDataForBatteryLevel;

-(WifiCamAlertTable *)prepareDataForTimelapseInterval:(unsigned int)curVideoTimelapseInterval;
-(WifiCamAlertTable *)prepareDataForTimelapseDuration:(unsigned int)curVideoTimelapseDuration;

- (WifiCamAlertTable *)prepareDataForScreenSaver:(uint)curScreenSaver;
- (NSString *)calcScreenSaverTime:(uint)curScreenSaver;
- (WifiCamAlertTable *)prepareDataForAutoPowerOff:(uint)curAutoPowerOff;
- (NSString *)calcAutoPowerOffTime:(uint)curAutoPowerOff;
- (WifiCamAlertTable *)prepareDataForExposureCompensation:(uint)curExposureCompensation;
- (NSString *)calcExposureCompensationValue:(uint)curExposureCompensation;
- (WifiCamAlertTable *)prepareDataForVideoFileLength:(uint)curVideoFileLength;
- (NSString *)calcVideoFileLength:(uint)curVideoFileLength;
- (WifiCamAlertTable *)prepareDataForFastMotionMovie:(uint)curFastMotionMovie;
- (NSString *)calcFastMotionMovieRate:(uint)curFastMotionMovie;

- (NSString *)retrieveIQbrightnessValue;
- (NSString *)retrieveIQhueValue;
- (NSString *)retrieveIQsaturationValue;
- (BOOL)retrieveIQBLCValue;

//
-(unsigned int)retrieveDelayedCaptureTime;
-(unsigned int)retrieveBurstNumber;
-(uint)retrieveMaxZoomRatio;
-(uint)retrieveCurrentZoomRatio;
-(uint)retrieveCurrentUpsideDown;
-(uint)retrieveCurrentSlowMotion;
-(uint)retrieveCurrentMovieRecordElapsedTime;
-(int)retrieveCurrentTimelapseInterval;
-(string) retrieveCurrentVideoSize2;

-(BOOL)isSupportMethod2ChangeVideoSize;
-(BOOL)isSupportPV;

// Update
-(void)updateAllProperty:(WifiCamCamera *)camera;
// tools
- (NSString *)transBatteryLevel2NStr:(unsigned int)value;
@end
