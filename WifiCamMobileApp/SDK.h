//
//  SDK.h - Data Access Layer
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 13-12-6.
//  Copyright (c) 2013年 iCatchTech. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ICatchWificam.h"
#include "ICatchWifiCamAssist.h"
#import "WifiCamAVData.h"
#import "WifiCamObserver.h"
#include <vector>
#import <Photos/Photos.h>
#import "SDKPrivate.h"

using namespace std;


enum WCFileType {
  WCFileTypeImage  = TYPE_IMAGE,
  WCFileTypeVideo  = TYPE_VIDEO,
  WCFileTypeAudio  = TYPE_AUDIO,
  WCFileTypeText   = TYPE_TEXT,
  WCFileTypeAll    = TYPE_ALL,
  WCFileTypeUnknow = TYPE_UNKNOWN,
};

enum WCRetrunType {
  WCRetSuccess = ICH_SUCCEED,
  WCRetFail,
  WCRetNoSD,
  WCRetSDFUll,
};


@interface SDK : NSObject

@property (nonatomic, readonly) uint previewCacheTime;

#pragma mark - Global
@property (nonatomic) NSMutableArray *downloadArray;
@property (nonatomic) BOOL isBusy;
@property (nonatomic) NSUInteger downloadedTotalNumber;
@property (nonatomic) BOOL connected;
@property (nonatomic, readonly) dispatch_queue_t sdkQueue;
@property (nonatomic, readonly) BOOL isSDKInitialized;
@property (nonatomic, readonly) BOOL isSupportAutoDownload;

#pragma mark - API adapter layer
// SDK
+(SDK *)instance;
-(BOOL)initializeSDK;
-(void)destroySDK;
-(void)cleanUpDownloadDirectory;
-(void)enableLogSdkAtDiretctory:(NSString *)directoryName enable:(BOOL)enable;
-(BOOL)isConnected;

// MEDIA
-(int)startMediaStream:(ICatchPreviewMode)mode enableAudio:(BOOL)enableAudio;
- (int)startMediaStream:(ICatchPreviewMode)mode enableAudio:(BOOL)enableAudio enableLive:(BOOL)enableLive;
-(BOOL)stopMediaStream;
-(BOOL)isMediaStreamOn;
-(BOOL)videoStreamEnabled;
-(BOOL)audioStreamEnabled;
-(ICatchVideoFormat)getVideoFormat;
-(ICatchAudioFormat)getAudioFormat;
-(NSMutableData *)getVideoData;
-(NSData *)getAudioData;
-(BOOL)openAudio:(BOOL)isOpen;
- (WifiCamAVData *)getVideoData2;
- (WifiCamAVData *)getAudioData2;
- (WifiCamAVData *)getVideoData3;
- (WifiCamAVData *)getAudioData3;

// CONTROL
-(WCRetrunType)capturePhoto;
-(WCRetrunType)triggerCapturePhoto;
-(BOOL)startMovieRecord;
-(BOOL)stopMovieRecord;
-(BOOL)startTimelapseRecord;
-(BOOL)stopTimelapseRecord;
-(BOOL)formatSD;
-(BOOL)checkSDExist;
-(void)addObserver:(ICatchEventID)eventTypeId
          listener:(ICatchWificamListener *)listener
       isCustomize:(BOOL)isCustomize;
-(void)removeObserver:(ICatchEventID)eventTypeId
             listener:(ICatchWificamListener *)listener
          isCustomize:(BOOL)isCustomize;
-(void)addObserver:(WifiCamObserver *)observer;
-(void)removeObserver:(WifiCamObserver *)observer;
-(BOOL)zoomIn;
-(BOOL)zoomOut;

// Photo gallery
-(vector<ICatchFile>)requestFileListOfType:(WCFileType)fileType;
-(UIImage *)requestThumbnail:(ICatchFile *)file;
-(UIImage *)requestImage:(ICatchFile *)file;
-(NSString *)p_downloadFile:(ICatchFile *)f;
-(BOOL)downloadFile:(ICatchFile *)f;
-(void)cancelDownload;
-(BOOL)deleteFile:(ICatchFile *)f;
- (BOOL)openFileTransChannel;
- (NSString *)p_downloadFile2:(ICatchFile *)f;
- (BOOL)closeFileTransChannel;
-(BOOL)downloadFile2:(ICatchFile *)f;

// Video playback
-(WifiCamAVData *)getPlaybackFrameData;
-(WifiCamAVData *)getPlaybackAudioData;
- (ICatchFrameBuffer *)getPlaybackAudioData1;
-(NSData *)getPlaybackAudioData2;
-(ICatchVideoFormat)getPlaybackVideoFormat;
-(ICatchAudioFormat)getPlaybackAudioFormat;
-(BOOL)videoPlaybackEnabled;
-(BOOL)videoPlaybackStreamEnabled;
-(BOOL)audioPlaybackStreamEnabled;
-(double)play:(ICatchFile *)file;
-(BOOL)pause;
-(BOOL)resume;
-(BOOL)stop;
-(BOOL)seek:(double)point;

//
-(BOOL)isMediaStreamRecording;
-(BOOL)isVideoTimelapseOn;
-(BOOL)isStillTimelapseOn;

// Properties
-(vector<ICatchMode>)retrieveSupportedCameraModes;
-(vector<ICatchCameraProperty>)retrieveSupportedCameraCapabilities;
-(vector<unsigned int>)retrieveSupportedWhiteBalances;
-(vector<unsigned int>)retrieveSupportedCaptureDelays;
-(vector<string>)retrieveSupportedImageSizes;
-(vector<string>)retrieveSupportedVideoSizes;
-(vector<unsigned int>)retrieveSupportedLightFrequencies;
-(vector<unsigned int>)retrieveSupportedBurstNumbers;
-(vector<unsigned int>)retrieveSupportedDateStamps;
-(vector<unsigned int>)retrieveSupportedTimelapseInterval;
-(vector<unsigned int>)retrieveSupportedTimelapseDuration;
-(string)retrieveImageSize;
-(string)retrieveVideoSize;
-(string)retrieveVideoSizeByPropertyCode;
-(unsigned int)retrieveDelayedCaptureTime;
-(unsigned int)retrieveWhiteBalanceValue;
-(unsigned int)retrieveLightFrequency;
-(unsigned int)retrieveBurstNumber;
-(unsigned int)retrieveDateStamp;
-(int)retrieveTimelapseInterval;
-(int)retrieveTimelapseDuration;
-(unsigned int)retrieveBatteryLevel;
-(BOOL)checkstillCapture;
-(unsigned int)retrieveFreeSpaceOfImage;
-(unsigned int)retrieveFreeSpaceOfVideo;
-(NSString *)retrieveCameraFWVersion;
-(NSString *)retrieveCameraProductName;
-(uint)retrieveMaxZoomRatio;
-(uint)retrieveCurrentZoomRatio;
-(uint)retrieveCurrentUpsideDown;
-(uint)retrieveCurrentSlowMotion;
-(ICatchCameraMode)retrieveCurrentCameraMode;

// Customize Property
- (vector<uint>)retrieveSupportedScreenSaver;
- (uint)retrieveCurrentScreenSaver;
- (vector<uint>)retrieveSupportedAutoPowerOff;
- (uint)retrieveCurrentAutoPowerOff;
- (vector<uint>)retrieveSupportedPowerOnAutoRecord;
- (BOOL)retrieveCurrentPowerOnAutoRecord;
- (vector<uint>)retrieveSupportedExposureCompensation;
- (uint)retrieveCurrentExposureCompensation;
- (vector<uint>)retrieveSupportedImageStabilization;
- (BOOL)retrieveCurrentImageStabilization;
- (vector<uint>)retrieveSupportedVideoFileLength;
- (uint)retrieveCurrentVideoFileLength;
- (vector<uint>)retrieveSupportedFastMotionMovie;
- (uint)retrieveCurrentFastMotionMovie;
- (vector<uint>)retrieveSupportedWindNoiseReduction;
- (BOOL)retrieveCurrentWindNoiseReduction;

// Change properties
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

// Customize property stuff
-(int)getCustomizePropertyIntValue:(int)propid;
-(NSString *)getCustomizePropertyStringValue:(int)propid;
-(BOOL)setCustomizeIntProperty:(int)propid value:(uint)value;
-(BOOL)setCustomizeStringProperty:(int)propid value:(NSString *)value;
-(BOOL)isValidCustomerID:(int)customerid;


// --

-(UIImage *)getAutoDownloadImage;
-(void)updateFW:(string)fwPath;

- (PHFetchResult *)retrieveCameraRollAssetsResult;
- (BOOL)addNewAssetWithURL:(NSURL *)fileURL toAlbum:(NSString *)albumName andFileType:(ICatchFileType)fileType;
- (BOOL)savetoAlbum:(NSString *)albumName andAlbumAssetNum:(uint)assetNum andShareNum:(uint)shareNum;

#pragma mark - Live
- (int)startPublishStreaming:(string)rtmpUrl;
- (int)stopPublishStreaming;
- (BOOL)isStreamSupportPublish;

@end

