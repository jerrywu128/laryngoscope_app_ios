//
//  SDK.m
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 13-12-6.
//  Copyright (c) 2013年 iCatchTech. All rights reserved.
//

#import "SDK.h"

#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>
#include "ICatchWificamConfig.h"
#include "WiFiCamH264StreamParameter.h"

@interface SDK ()
@property (nonatomic) ICatchWificamSession *session;
@property (nonatomic) ICatchWificamPreview *preview;
@property (nonatomic) ICatchWificamControl *control;
@property (nonatomic) ICatchWificamProperty *prop;
@property (nonatomic) ICatchWificamPlayback *playback;
@property (nonatomic) ICatchWificamVideoPlayback* vplayback;
@property (nonatomic) ICatchWificamState *sdkState;
@property (nonatomic) ICatchWificamInfo *sdkInfo;

@property (nonatomic) ICatchFrameBuffer* videoFrameBufferA;
@property (nonatomic) ICatchFrameBuffer* videoFrameBufferB;
@property (nonatomic) BOOL curVideoFrameBufferA;
@property (nonatomic) ICatchFrameBuffer* audioTrackBufferA;
@property (nonatomic) ICatchFrameBuffer* audioTrackBufferB;
@property (nonatomic) BOOL curAudioTrackBufferA;

@property (nonatomic) NSMutableData *videoData;
@property (nonatomic) NSMutableData *audioData;
@property (nonatomic) NSMutableData *videoPlaybackData;
@property (nonatomic) NSMutableData *audioPlaybackData;

@property (nonatomic) UIImage *autoDownloadImage;
@property (nonatomic) BOOL isStopped;
@property (nonatomic, readwrite) dispatch_queue_t sdkQueue;
@property (nonatomic, readwrite) BOOL isSDKInitialized;
@property (nonatomic, readwrite) BOOL isSupportAutoDownload;

@property (nonatomic, readwrite) BOOL isPublishStreaming;

@property (nonatomic) NSRange videoRange;
@property (nonatomic) NSRange audioRange;
@end

@implementation SDK

//@synthesize curPVFileIndex = _curPVFileIndex;

@synthesize downloadArray;
@synthesize downloadedTotalNumber;
@synthesize sdkQueue;
@synthesize isSDKInitialized;
@synthesize isSupportAutoDownload;

#pragma mark - SDK status

+ (SDK *)instance {
    static SDK *instance = nil;
    /*
     @synchronized(self) {
     if(!instance) {
     instance = [[self alloc] init];
     }
     }
     */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] initSingleton];
        instance.sdkQueue = dispatch_queue_create("WifiCam.GCD.Queue.SDKQ", DISPATCH_QUEUE_SERIAL);
    });
    return instance;
    
}

- (id)init {
    // Forbid calls to –init or +new
    NSAssert(NO, @"Cannot create instance of Singleton");
    
    // You can return nil or [self initSingleton] here,
    // depending on how you prefer to fail.
    return nil;
}

// Real (private) init method
- (id)initSingleton {
    if (self = [super init]) {
        // Init code
    }
    return self;
}

- (BOOL)disablePTPIP {
    bool ret = ICatchWificamConfig::getInstance()->disablePTPIP();
    
    return ret == true ? YES : NO;
}

- (BOOL)enablePTPIP {
    bool ret = ICatchWificamConfig::getInstance()->enablePTPIP();
    
    return ret == true ? YES : NO;
}

- (BOOL)initializeSDK {
    __block BOOL ret = NO;
    do {
#if kV50_Test
        if (![self disablePTPIP]) {
            break;
        }
#endif
        
        AppLog(@"---START INITIALIZE SDK(Data Access Layer)---");
        if (isSDKInitialized) {
            ret = YES;
            break;
        }
        
        _session = new ICatchWificamSession();
        
#if (SDK_DEBUG==1)
        ICatchWificamLog* log = ICatchWificamLog::getInstance();
        log->setSystemLogOutput( true );
        log->setPtpLog(true);
        log->setRtpLog(false);
        log->setPtpLogLevel(LOG_LEVEL_INFO);
        log->setRtpLogLevel(LOG_LEVEL_INFO);
#endif
        
        if (_session == NULL) {
            AppLog(@"Create session failed.");
            break;
        }
        
        AppLog(@"prepareSession");
        if (_session->prepareSession([self getCameraIpAddr].UTF8String) != ICH_SUCCEED)
        {
            AppLog(@"prepareSession failed");
            break;
        } else {
            if (_session->checkConnection() == false) {
                AppLog(@"_session check camera connection return false.");
                break;
            }
        }
        AppLog(@"prepareSession done");
        
        self.preview = _session->getPreviewClient();
        self.control = _session->getControlClient();
        self.prop = _session->getPropertyClient();
        self.playback = _session->getPlaybackClient();
        self.vplayback = _session->getVideoPlaybackClient();
        self.sdkState = _session->getStateClient();
        self.sdkInfo = _session->getInfoClient();
        if (!_preview || !_control || !_prop || !_playback || !_sdkState || !_sdkInfo) {
            AppLog(@"SDK objects were nil");
            break;
        }
        
        self.videoFrameBufferA = new ICatchFrameBuffer(640 * 480 * 2);
        self.videoFrameBufferB = new ICatchFrameBuffer(640 * 480 * 2);
        self.curVideoFrameBufferA = YES;
        self.audioTrackBufferA = new ICatchFrameBuffer(1024 * 50);
        self.audioTrackBufferB = new ICatchFrameBuffer(1024 * 50);
        self.curAudioTrackBufferA = YES;
        self.videoRange = NSMakeRange(0, 640 * 480 * 2);
        self.videoData = [[NSMutableData alloc] initWithCapacity:640 * 480 * 2];
        self.audioRange = NSMakeRange(0, 1024 * 50);
        self.audioData = [[NSMutableData alloc] init];
        self.audioPlaybackData = [[NSMutableData alloc] init];
        self.downloadArray = [[NSMutableArray alloc] init];
        ret = YES;
        
    } while (0);
    
    if (ret) {
        @synchronized(self) {
            isSDKInitialized = YES;
        }
        AppLog(@"---End---");
    } else {
        isSDKInitialized = NO;
        AppLog(@"---INITIALIZE SDK Failed---");
        if (_session) {
            delete _session;_session = NULL;
        }
    }
    
    return ret;
}

- (NSString *)getCameraIpAddr
{
#if kV50_Test
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *pvURL = [defaults stringForKey:@"pvURL"];
    AppLogDebug(AppLogTagAPP, @"pvURL: %@", pvURL);

    NSArray *urlArray = [pvURL componentsSeparatedByString:@"/"];
    NSString *ipAddr = urlArray.firstObject;
    AppLogDebug(AppLogTagAPP, @"ipAddr: %@", ipAddr);
    
    return ipAddr;
#else
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enableLive = [defaults boolForKey:@"PreferenceSpecifier:Live"];
    NSString *ipAddr = [defaults stringForKey:@"ipAddr"];
    AppLogDebug(AppLogTagAPP, @"ipAddr: %@", ipAddr);
    
    if (enableLive && ipAddr) {
        return ipAddr;
    } else {
        return @"192.168.1.1";
    }
#endif
}

- (int)startPublishStreaming:(string)rtmpUrl
{
    int newValue = ICH_NULL;
    if (_preview) {
        AppLogDebug(AppLogTagAPP, @"startPublishStreaming start.");
        newValue = _preview->startPublishStreaming(rtmpUrl);
        AppLogDebug(AppLogTagAPP, @"startPublishStreaming ret : %d.", newValue);
        AppLogDebug(AppLogTagAPP, @"startPublishStreaming end.");
    }
    
    if (!newValue) {
        @synchronized(self) {
            _isPublishStreaming = YES;
        }
    }
    
    return newValue;
}

- (int)stopPublishStreaming
{
    int newValue = ICH_NULL;
    
    if (_isPublishStreaming) {
        @synchronized(self) {
            _isPublishStreaming = NO;
        }
        
        if (_preview) {
            AppLogDebug(AppLogTagAPP, @"stopPublishStreaming start.");
            newValue = _preview->stopPublishStreaming();
            AppLogDebug(AppLogTagAPP, @"stopPublishStreaming ret : %d.", newValue);
            AppLogDebug(AppLogTagAPP, @"stopPublishStreaming end.");
        }
    }
    
    return newValue;
}

- (BOOL)isStreamSupportPublish
{
    int newValue = ICH_NULL;
    
    if (_preview) {
        AppLogDebug(AppLogTagAPP, @"isStreamSupportPublish start.");
        newValue = _preview->isStreamSupportPublish();
        AppLogDebug(AppLogTagAPP, @"isStreamSupportPublish ret : %d.", newValue);
        AppLogDebug(AppLogTagAPP, @"isStreamSupportPublish end.");
    }
    
    return newValue == ICH_SUCCEED ? YES : NO;
}

- (void)destroySDK
{
    if (isSDKInitialized) {
        @synchronized(self) {
            isSDKInitialized = NO;
        }
        
        [NSThread sleepForTimeInterval:0.5];

        if (_session) {
            AppLog(@"start destroy session");
            _session->destroySession();
            delete _session;_session = NULL;
            AppLog(@"destroy session done");
        }
        
        if (_videoFrameBufferA) {
            delete _videoFrameBufferA; _videoFrameBufferA = NULL;
        }
        if (_videoFrameBufferB) {
            delete _videoFrameBufferB; _videoFrameBufferB = NULL;
        }
        if (_audioTrackBufferA) {
            delete _audioTrackBufferA; _audioTrackBufferA = NULL;
        }
        if (_audioTrackBufferB) {
            delete _audioTrackBufferB; _audioTrackBufferB = NULL;
        }
        
        self.preview = NULL;
        self.control = NULL;
        self.prop = NULL;
        self.playback = NULL;
        self.vplayback = NULL;
        self.sdkState = NULL;
        self.sdkInfo = NULL;
        AppLog(@"Over");
    }
}

-(void)cleanUpDownloadDirectory
{
    [self cleanTemp];
}

-(void)enableLogSdkAtDiretctory:(NSString *)directoryName
                         enable:(BOOL)enable
{
    ICatchWificamLog* log = ICatchWificamLog::getInstance();
    if (enable) {
        log->setFileLogPath(string([directoryName UTF8String]));
        log->setPtpLogLevel(LOG_LEVEL_CONNECT);
        log->setRtpLogLevel(LOG_LEVEL_CONNECT);
        log->setFileLogOutput(true);
        log->setPtpLog(true);
        log->setRtpLog(true);
        log->setDebugMode(true);
    } else {
        log->setFileLogOutput(false);
        log->setPtpLog(false);
        log->setRtpLog(false);
    }
}

-(BOOL)isConnected
{
    BOOL retVal = NO;
    if (_session && _session->checkConnection()) {
        retVal = YES;
    }
    return retVal;
}

-(NSString *)retrieveCameraFWVersion
{
    return [NSString stringWithFormat:@"%s", _sdkInfo->getCameraFWVersion().c_str()];
}

-(NSString *)retrieveCameraProductName
{
    return [NSString stringWithFormat:@"%s", _sdkInfo->getCameraProductName().c_str()];
}

#pragma mark - Properties
-(vector<ICatchMode>)retrieveSupportedCameraModes
{
    vector<ICatchMode> supportedCameraModes;
    if (_control) {
        _control->getSupportedModes(supportedCameraModes);
    }
    
    return supportedCameraModes;
}

-(vector<ICatchCameraProperty>)retrieveSupportedCameraCapabilities
{
    vector<ICatchCameraProperty> supportedCameraCapability;
    if (_prop) {
        _prop->getSupportedProperties(supportedCameraCapability);
    }
    
    return supportedCameraCapability;
}

-(vector<unsigned int>)retrieveSupportedWhiteBalances
{
    vector<unsigned int> supportedWhiteBalances;
    if (_prop) {
        _prop->getSupportedWhiteBalances(supportedWhiteBalances);
    }
    return supportedWhiteBalances;
}

-(vector<unsigned int>)retrieveSupportedCaptureDelays
{
    vector<unsigned int> supportedCaptureDelays;
    if (_prop) {
        _prop->getSupportedCaptureDelays(supportedCaptureDelays);
    }
    return supportedCaptureDelays;
}

-(vector<string>)retrieveSupportedImageSizes
{
    vector<string> supportedImageSizes;
    if (_prop) {
        _prop->getSupportedImageSizes(supportedImageSizes);
    }
    return supportedImageSizes;
}

-(vector<string>)retrieveSupportedVideoSizes
{
    vector<string> supportedVideoSizes;
    if (_prop) {
        _prop->getSupportedVideoSizes(supportedVideoSizes);
    }
    return supportedVideoSizes;
}

-(vector<unsigned int>)retrieveSupportedLightFrequencies
{
    vector<unsigned int> supportedLightFrequencies;
    if (_prop) {
        _prop->getSupportedLightFrequencies(supportedLightFrequencies);
    }
    
    // Erase some items within vector
    NSMutableArray *a = [[NSMutableArray alloc] init];
    int i = 0;
    for (vector<unsigned int>::iterator it = supportedLightFrequencies.begin();
         it != supportedLightFrequencies.end();
         ++it, ++i) {
        if (*it == LIGHT_FREQUENCY_AUTO || *it == LIGHT_FREQUENCY_UNDEFINED) {
            //[a addObject:[NSNumber numberWithInt:i]];
            [a addObject:@(i)];
        }
    }
    for (i=0; i<a.count; ++i) {
        supportedLightFrequencies.erase(supportedLightFrequencies.begin()+i);
    }
    
    AppLog(@"_supportedLightFrequencies.size: %lu", supportedLightFrequencies.size());
    return supportedLightFrequencies;
}

-(vector<unsigned int>)retrieveSupportedBurstNumbers
{
    vector<unsigned int> supportedBurstNumbers;
    if (_prop) {
        _prop->getSupportedBurstNumbers(supportedBurstNumbers);
    }
    //  for(vector<unsigned int>::iterator it = supportedBurstNumbers.begin();
    //      it != supportedBurstNumbers.end();
    //      ++it) {
    //    AppLog(@"%d", *it);
    //  }
    return supportedBurstNumbers;
}

-(vector<unsigned int>)retrieveSupportedDateStamps
{
    vector<unsigned int> supportedDataStamps;
    if (_prop) {
        _prop->getSupportedDateStamps(supportedDataStamps);
    }
    return supportedDataStamps;
}

-(vector<unsigned int>)retrieveSupportedTimelapseInterval
{
    vector<unsigned int> supportedTimelapseIntervals;
    if (_prop) {
        _prop->getSupportedTimeLapseIntervals(supportedTimelapseIntervals);
    }
    AppLog(@"This size of supportedVideoTimelapseIntervals: %lu", supportedTimelapseIntervals.size());
    return supportedTimelapseIntervals;
}

-(vector<unsigned int>)retrieveSupportedTimelapseDuration
{
    vector<unsigned int> supportedTimelapseDurations;
    if (_prop) {
        _prop->getSupportedTimeLapseDurations(supportedTimelapseDurations);
    }
    AppLog(@"This size of supportedVideoTimelapseDurations: %lu", supportedTimelapseDurations.size());
    return supportedTimelapseDurations;
}

-(string)retrieveImageSize {
    string curImageSize="";
    if (_prop) {
        _prop->getCurrentImageSize(curImageSize);
    }
    return curImageSize;
}
-(string)retrieveVideoSizeByPropertyCode {
    string curVideoSize ="";
    if (_prop) {
        _prop->getCurrentPropertyValue(0xD605, curVideoSize);
    }
    return curVideoSize;
}
-(string)retrieveVideoSize {
    string curVideoSize ="";
    if (_prop) {
        _prop->getCurrentVideoSize(curVideoSize);
    }
    return curVideoSize;
}

-(unsigned int)retrieveDelayedCaptureTime {
    unsigned int curCaptureDelay = 0;
    if (_prop) {
        _prop->getCurrentCaptureDelay(curCaptureDelay);
    }
    return curCaptureDelay;
}

-(unsigned int)retrieveWhiteBalanceValue {
    unsigned int curWhiteBalance = 0;
    if (_prop) {
        _prop->getCurrentWhiteBalance(curWhiteBalance);
    }
    return curWhiteBalance;
}

-(unsigned int)retrieveLightFrequency {
    unsigned int curLightFrequency = 0;
    if (_prop) {
        _prop->getCurrentLightFrequency(curLightFrequency);
    }
    return curLightFrequency;
}
-(unsigned int)retrieveBurstNumber {
    unsigned int curBurstNumber = 0;
    if (_prop) {
        _prop->getCurrentBurstNumber(curBurstNumber);
    }
    AppLog(@"curBurstNumber: %d", curBurstNumber);
    return curBurstNumber;
}

-(unsigned int)retrieveDateStamp {
    unsigned int curDateStamp = 0 ;
    if (_prop) {
        _prop->getCurrentDateStamp(curDateStamp);
    }
    return curDateStamp;
}

-(int)retrieveTimelapseInterval {
    unsigned int curVideoTimelapseInterval = 0;
    if (_prop) {
        if ( _prop->getCurrentTimeLapseInterval(curVideoTimelapseInterval) != ICH_SUCCEED) {
            curVideoTimelapseInterval = -1;
        }
    }
    AppLog(@"Re-Get timelapse interval[RAW]: %d", curVideoTimelapseInterval);
    return curVideoTimelapseInterval;
}

-(int)retrieveTimelapseDuration {
    unsigned int curVideoTimelapseDuration = 0;
    if (_prop) {
        if (_prop->getCurrentTimeLapseDuration(curVideoTimelapseDuration) != ICH_SUCCEED) {
            curVideoTimelapseDuration = -1;
        }
    }
    AppLog(@"curVideoTimelapseDuration: %d", curVideoTimelapseDuration);
    return curVideoTimelapseDuration;
}

-(unsigned int)retrieveBatteryLevel {
    unsigned int curBatteryLevel = 0;
    if (_control) {
        _control->getCurrentBatteryLevel(curBatteryLevel);
    }
    
    return curBatteryLevel;
}

-(BOOL)checkstillCapture {
    uint num = 0;
    if (!_control) {
        AppLog(@"SDK doesn't work!!!");
        return NO;
    }
    
    /*int ret = _control->getFreeSpaceInImages(num);
    if (ret == ICH_SUCCEED && num == 0) {
        return NO;
    } else {
        return  YES;
    }*/
    int ret = _control->getFreeSpaceInImages(num);
    if (ret == ICH_SUCCEED) {
        return YES;
    } else {
        return NO;
    }
}

-(unsigned int)retrieveFreeSpaceOfImage {
//    unsigned int photoNum = 0;
//    uint num = 0;
//    int ret = -1;
//    if (_control) {
//        ret = _control->getFreeSpaceInImages(num);
//    }
//    if (ICH_SUCCEED == ret) {
//        photoNum = num;
//    }
//    
//    return photoNum;
    uint num = 0;
    static uint preNum = 0;
    if (!_control) {
        AppLog(@"SDK doesn't work!!!");
        return num;
    }
    
    int ret = _control->getFreeSpaceInImages(num);
    if (ret == ICH_SUCCEED) {
        preNum = num;
    } else {
        AppLog(@"retrieveFreeSpaceOfImage failed: %d", ret);
    }
    return preNum;
}

-(unsigned int)retrieveFreeSpaceOfVideo {
    unsigned int secs = 0;
    static uint preSecs = 0;
    int ret = -1;
    if (_control) {
        ret = _control->getRemainRecordingTime(secs);
    }
    
    if (ret == ICH_SUCCEED) {
        AppLog(@"freeSpace of Video: %d", secs);
        preSecs = secs;
    } else {
        AppLog(@"getRemainRecordingTime failed: %d", ret);
    }
    return preSecs;
}

-(uint)retrieveMaxZoomRatio
{
    uint ratio = 1;
    if (_prop) {
        _prop->getMaxZoomRatio(ratio);
    }
    AppLog(@"max ratio: %d", ratio);
    return ratio;
}

-(uint)retrieveCurrentZoomRatio
{
    uint ratio = 1;
    if (_prop) {
        _prop->getCurrentZoomRatio(ratio);
    }
    return ratio;
}

-(uint)retrieveCurrentUpsideDown
{
    uint curUD = 0;
    if (_prop) {
        _prop->getCurrentUpsideDown(curUD);
    }
    return curUD;
}

-(uint)retrieveCurrentSlowMotion
{
    uint curSM = 0;
    if (_prop) {
        _prop->getCurrentSlowMotion(curSM);
    }
    return curSM;
}


-(ICatchCameraMode)retrieveCurrentCameraMode
{
    ICatchCameraMode mode = MODE_UNDEFINED;
    if (_control) {
        mode = _control->getCurrentCameraMode();
    }
    return mode;
}

// add - 2017.3.16
- (vector<uint>)retrieveSupportedScreenSaver
{
    return [self getCustomizeSupportedPropertyIntValues:CustomizePropertyID_ScreenSaver];
}

- (uint)retrieveCurrentScreenSaver
{
    return [self getCustomizePropertyIntValue:CustomizePropertyID_ScreenSaver];
}

- (vector<uint>)retrieveSupportedAutoPowerOff
{
    return [self getCustomizeSupportedPropertyIntValues:CustomizePropertyID_AutoPowerOff];
}

- (uint)retrieveCurrentAutoPowerOff
{
    return [self getCustomizePropertyIntValue:CustomizePropertyID_AutoPowerOff];
}

- (vector<uint>)retrieveSupportedPowerOnAutoRecord
{
    return [self getCustomizeSupportedPropertyIntValues:CustomizePropertyID_PowerOnAutoRecord];
}

- (BOOL)retrieveCurrentPowerOnAutoRecord
{
    return [self getCustomizePropertyIntValue:CustomizePropertyID_PowerOnAutoRecord] ? YES : NO;
}

- (vector<uint>)retrieveSupportedExposureCompensation
{
    return [self getCustomizeSupportedPropertyIntValues:CustomizePropertyID_EXposureCompensation];
}

- (uint)retrieveCurrentExposureCompensation
{
    return [self getCustomizePropertyIntValue:CustomizePropertyID_EXposureCompensation];
}

- (vector<uint>)retrieveSupportedImageStabilization
{
    return [self getCustomizeSupportedPropertyIntValues:CustomizePropertyID_ImageStabilization];
}

- (BOOL)retrieveCurrentImageStabilization
{
    return [self getCustomizePropertyIntValue:CustomizePropertyID_ImageStabilization] ? YES : NO;
}

- (vector<uint>)retrieveSupportedVideoFileLength
{
    return [self getCustomizeSupportedPropertyIntValues:CustomizePropertyID_VideoFileLength];
}

- (uint)retrieveCurrentVideoFileLength
{
    return [self getCustomizePropertyIntValue:CustomizePropertyID_VideoFileLength];
}

- (vector<uint>)retrieveSupportedFastMotionMovie
{
    return [self getCustomizeSupportedPropertyIntValues:CustomizePropertyID_FastMotionMovie];
}

- (uint)retrieveCurrentFastMotionMovie
{
    return [self getCustomizePropertyIntValue:CustomizePropertyID_FastMotionMovie];
}

- (vector<uint>)retrieveSupportedWindNoiseReduction
{
    return [self getCustomizeSupportedPropertyIntValues:CustomizePropertyID_WindNoiseReduction];
}

- (BOOL)retrieveCurrentWindNoiseReduction
{
    return [self getCustomizePropertyIntValue:CustomizePropertyID_WindNoiseReduction] ? YES : NO;
}

#pragma mark - Change properties
-(int)changeImageSize:(string)size {
    int newSize = ICH_NULL;
    if (_prop) {
        newSize = _prop->setImageSize(size);
    }
    return newSize;
}

-(int)changeVideoSize:(string)size{
    int newSize = ICH_NULL;
    if (_prop) {
        newSize = _prop->setVideoSize(size);
    }
    return newSize;
}

-(int)changeDelayedCaptureTime:(unsigned int)time{
    int newTime = ICH_NULL;
    if (_prop) {
        newTime = _prop->setCaptureDelay(time);
    }
    return newTime;
}

-(int)changeWhiteBalance:(unsigned int)value{
    int newValue = ICH_NULL;
    if (_prop) {
        newValue = _prop->setWhiteBalance(value);
    }
    return newValue;
}

-(int)changeLightFrequency:(unsigned int)value {
    int newValue = ICH_NULL;
    if (_prop) {
        newValue = _prop->setLightFrequency(value);
    }
    return newValue;
}

-(int)changeBurstNumber:(unsigned int)value {
    int newValue = ICH_NULL;
    if (_prop) {
        newValue = _prop->setBurstNumber(value);
    }
    return newValue;
}

-(int)changeDateStamp:(unsigned int)value {
    int newValue = ICH_NULL;
    if (_prop) {
        newValue = _prop->setDateStamp(value);
    }
    return newValue;
}

-(int)changeTimelapseType:(ICatchPreviewMode)mode {
    int newValue = ICH_NULL;
    if (_preview) {
        newValue = _preview->changePreviewMode(mode);
        AppLog(@"changePreviewMode : %d", newValue);
    }
    return newValue;
}

-(int)changeTimelapseInterval:(unsigned int)value {
    int newValue = ICH_NULL;
    if (_prop) {
        newValue = _prop->setTimeLapseInterval(value);
    }
    return newValue;
}

-(int)changeTimelapseDuration:(unsigned int)value {
    int newValue = ICH_NULL;
    if (_prop) {
        newValue = _prop->setTimeLapseDuration(value);
    }
    return newValue;
}

-(int)changeUpsideDown:(uint)value {
    int newValue = ICH_NULL;
    if (_prop) {
        newValue = _prop->setUpsideDown(value);
    }
    return newValue;
}

-(int)changeSlowMotion:(uint)value {
    int newValue = ICH_NULL;
    if (_prop) {
        newValue = _prop->setSlowMotion(value);
    }
    return newValue;
}

- (NSString *)getPreviewURL
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *pvURL = [defaults stringForKey:@"pvURL"];
    AppLogDebug(AppLogTagAPP, @"pvURL: %@", pvURL);
    
    return pvURL;
}

#pragma mark - MEDIA
- (int)startMediaStream:(ICatchPreviewMode)mode enableAudio:(BOOL)enableAudio{
    int startRetVal = ICH_SUCCEED;
    
    if (!_preview || !_prop) {
        return ICH_NULL;
    }
    //int newValue = _preview-> (mode);
    //AppLog(@"changePreviewMode : %d", newValue);
    
    ICatchVideoFormat format;
    _prop->getCurrentStreamingInfo(format);
    
    int codec = format.getCodec();
    int w = format.getVideoW();
    int h = format.getVideoH();
    int br = format.getBitrate();
    unsigned int fr = format.getFps();
    AppLog(@"codec: 0x%x, w: %d, h: %d, br: %d, fr: %d", codec, w, h, br, fr);
    w = (w<=0) ? 720 : w;
    h = (h<=0) ? 400 : h;
    br = (br<=0) ? 5000000 : br;
#ifndef HW_DECODE_H264
    if (w>=1280 && h>=720 && fr>=30) {
        w = 1280;
        h = 720;
        fr = 15;
    }
#endif
    
    bool disableAudio = enableAudio == YES ? false : true;
    
    uint cacheTime = [self previewCacheTime];
    AppLog(@"cacheTime: %d", cacheTime);
//    if (cacheTime < 200) {
//        ICatchWificamConfig::getInstance()->setPreviewCacheParam(400);
//    }
    
    if (codec == ICATCH_CODEC_H264) {
        AppLog(@"%s - start h264", __func__);
        if (cacheTime > 0 && cacheTime < 200) {
            cacheTime = 400;
        }
        ICatchWificamConfig::getInstance()->setPreviewCacheParam(cacheTime);
        WiFiCamH264StreamParameter param(w, h, br, fr);
        startRetVal = _preview->start(param, mode, disableAudio);
    } else {
        AppLog(@"%s - start mjpg", __func__);
        if (cacheTime > 0 && cacheTime <= 200) {
            cacheTime = 200;
        }
        ICatchWificamConfig::getInstance()->setPreviewCacheParam(cacheTime);
#if kV50_Test
        WiFiCamH264StreamParameter param(w, h, br, fr);
#else
        ICatchMJPGStreamParam param(w, h, br);
#endif
        startRetVal = _preview->start(param, mode, disableAudio);
    }
    AppLog(@"%s - retVal : %d", __func__, startRetVal);
    
    self.isStopped = NO;
    return startRetVal;
}

- (int)startMediaStream:(ICatchPreviewMode)mode enableAudio:(BOOL)enableAudio enableLive:(BOOL)enableLive {
    int startRetVal = ICH_SUCCEED;
    
    if (!_preview || !_prop) {
        return ICH_NULL;
    }
    
    ICatchVideoFormat format;
    _prop->getCurrentStreamingInfo(format);
    
    int codec = format.getCodec();
    int w = format.getVideoW();
    int h = format.getVideoH();
    int br = format.getBitrate();
    unsigned int fr = format.getFps();
    AppLog(@"codec: 0x%x, w: %d, h: %d, br: %d, fr: %d", codec, w, h, br, fr);
    w = (w<=0) ? 720 : w;
    h = (h<=0) ? 400 : h;
    br = (br<=0) ? 5000000 : br;
#ifndef HW_DECODE_H264
    if (w>=1280 && h>=720 && fr>=30) {
        w = 1280;
        h = 720;
        fr = 15;
    }
#endif
    
    bool disableAudio = enableAudio == YES ? false : true;
    
    uint cacheTime = [self previewCacheTime];
    AppLog(@"cacheTime: %d", cacheTime);
    
#if 0
    if (enableLive && codec == ICATCH_CODEC_H264) {
        AppLog(@"%s - current enable & support live function", __func__);

        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *liveSize = [defaults stringForKey:@"LiveSize"];
        if (!liveSize) {
            liveSize = @"854x480";
            [defaults setObject:@"854x480" forKey:@"LiveSize"];
        }
        
        NSArray *sizeAr = [liveSize componentsSeparatedByString:@"x"];
        if ([sizeAr[0] integerValue]) {
            w = (int)[sizeAr[0] integerValue];
        }
        if ([sizeAr[1] integerValue]) {
            h = (int)[sizeAr[1] integerValue];
        }
        AppLogDebug(AppLogTagAPP, @"support live - w: %d, h: %d", w, h);
    }
#endif
    
    if (codec == ICATCH_CODEC_H264) {
        AppLog(@"%s - start h264", __func__);
        if (cacheTime > 0 && cacheTime < 200) {
            cacheTime = 400;
        }
        ICatchWificamConfig::getInstance()->setPreviewCacheParam(cacheTime);
        
        WiFiCamH264StreamParameter param(w, h, br, fr);
        startRetVal = _preview->start(param, mode, disableAudio);
    } else {
        AppLog(@"%s - start mjpg", __func__);
        if (cacheTime > 0 && cacheTime <= 200) {
            cacheTime = 200;
        }
        ICatchWificamConfig::getInstance()->setPreviewCacheParam(cacheTime);
        
        ICatchMJPGStreamParam param(w, h, br);
        startRetVal = _preview->start(param, mode, disableAudio);
    }

    AppLog(@"%s - retVal : %d", __func__, startRetVal);
    
    self.isStopped = NO;
    return startRetVal;
}

- (BOOL)stopMediaStream {
    
    @synchronized(self) {
        if (!self.isStopped) {
            
            AppLog(@"%s - start", __func__);
            
            if (![self isMediaStreamOn]) {
                AppLog(@"%s - Already stoped", __func__);
                return NO;
            }
            
            int retVal = 1;
            
            if(_preview)
                retVal = _preview->stop();
            AppLog(@"%s - retVal : %d", __func__,retVal);
            [NSThread sleepForTimeInterval:0.5];
            self.isStopped = YES;
            
            if (retVal == ICH_SUCCEED) {
                return YES;
            } else {
                AppLog(@"%s failed", __func__);
                return NO;
            }
        } else {
            return YES;
        }
    }
}

- (BOOL)isMediaStreamOn {
    BOOL retVal = NO;
    
    if (_sdkState && _sdkState->isStreaming() == true) {
        retVal = YES;
    }
    return retVal;
}

- (BOOL)isMediaStreamRecording {
    BOOL retVal = NO;
    
    if (_sdkState && _sdkState->isMovieRecording() == true) {
        retVal = YES;
    } else {
        AppLog(@"Camera is not recording.");
    }
    return retVal;
}

-(BOOL)isVideoTimelapseOn {
    
    BOOL retVal = NO;
    
    if (_sdkState->isTimeLapseVideoOn() == true) {
        AppLog(@"_sdkState->isTimeLapseVideoOn() == true");
        retVal = YES;
    } else {
        AppLog(@"_sdkState->isTimeLapseVideoOn() == false");
    }
    return retVal;
}

-(BOOL)isStillTimelapseOn {
    BOOL retVal = NO;
    
    if (_sdkState && _sdkState->isTimeLapseStillOn() == true) {
        AppLog(@"_sdkState->isTimeLapseStillOn() == true");
        retVal = YES;
    } else {
        AppLog(@"_sdkState->isTimeLapseStillOn() == false");
    }
    return retVal;
}

- (BOOL)videoStreamEnabled {
    return (_preview && _preview->containsVideoStream() == true) ? YES : NO;
}

- (BOOL)audioStreamEnabled {
    return (_preview && _preview->containsAudioStream() == true) ? YES : NO;
}

- (ICatchVideoFormat)getVideoFormat {
    ICatchVideoFormat format;
    
    if (_preview) {
        _preview->getVideoFormat(format);
        
        AppLog(@"video format: %d", format.getCodec());
        AppLog(@"video w,h: %d, %d", format.getVideoW(), format.getVideoH());
    } else {
        AppLog(@"SDK doesn't work!!!");
    }
    
    return format;
}

-(ICatchAudioFormat)getAudioFormat {
    ICatchAudioFormat format;
    if (_preview) {
        _preview->getAudioFormat(format);
    } else {
        AppLog(@"SDK doesn't work!!!");
    }
    
    return format;
}

- (NSMutableData *)getVideoData {
    if (!_preview) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    
    int retVal = _preview->getNextVideoFrame(_videoFrameBufferA);
    if (retVal == ICH_SUCCEED) {
        [_videoData setLength:_videoRange.length];
        [_videoData replaceBytesInRange:_videoRange withBytes:_videoFrameBufferA->getBuffer()];
        [_videoData setLength:_videoFrameBufferA->getFrameSize()];        
        return _videoData;
    } else {
        AppLog(@"** Get video frame failed with error code %d.", retVal);
        return nil;
    }
}

- (NSData *)getAudioData {
    if (!_preview) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    
    int retVal = _preview->getNextAudioFrame(_audioTrackBufferA);
    if (retVal == ICH_SUCCEED) {
        [_audioData setLength:_audioRange.length];
        [_audioData replaceBytesInRange:_audioRange withBytes:_audioTrackBufferA->getBuffer()];
        [_audioData setLength:_audioTrackBufferA->getFrameSize()];
        return _audioData;
    } else {
        AppLog(@"* Get audio track failed with error code %d", retVal);
        return nil;
    }
}

-(BOOL)openAudio:(BOOL)isOpen {
    BOOL ret = NO;
    if (!_preview) {
        return ret;
    }
    if (isOpen) {
        ret = _preview->enableAudio() == ICH_SUCCEED ? YES : NO;
        AppLog(@"enableAudio: %hhd", ret);
    } else {
        ret = _preview->disableAudio() == ICH_SUCCEED ? YES : NO;
        AppLog(@"disableAudio: %hhd", ret);
    }
    return ret;
}
/*
 - (NSString *)getTimeNow {
 NSString* date;
 
 NSDateFormatter * formatter = [[NSDateFormatter alloc ] init];
 //[formatter setDateFormat:@"YYYY.MM.dd.hh.mm.ss"];
 [formatter setDateFormat:@"hh:mm:ss:SSS"];
 date = [formatter stringFromDate:[NSDate date]];
 NSString *timeNow = [[NSString alloc] initWithFormat:@"%@", date];
 NSLog(@"%@", timeNow);
 return timeNow;
 }
 */


- (WifiCamAVData *)getVideoData2 {
    if (!_preview) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    WifiCamAVData *videoFrameData = nil;
    RunLog(@"getVideoData begin");
    int retVal = _preview->getNextVideoFrame(_videoFrameBufferA);
    RunLog(@"getVideoData end");
    RunLog(@"video frame presentation time: %f", _videoFrameBufferA->getPresentationTime());
    if (retVal == ICH_SUCCEED) {
        [_videoData setLength:_videoRange.length];
        [_videoData replaceBytesInRange:_videoRange withBytes:_videoFrameBufferA->getBuffer()];
        [_videoData setLength:_videoFrameBufferA->getFrameSize()];
        videoFrameData = [[WifiCamAVData alloc] initWithData:_videoData
                                                     andTime:_videoFrameBufferA->getPresentationTime()];
    } else {
        //AppLog(@"** Get video frame failed with error code %d.", retVal);
    }
    
    return videoFrameData;
}

- (WifiCamAVData *)getVideoData3 {
    if (!_preview) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    WifiCamAVData *videoFrameData = nil;
    ICatchFrameBuffer *frameBuffer = nil;
    int retVal;
    
    if (_curVideoFrameBufferA) {
        self.curVideoFrameBufferA = NO;
        retVal = _preview->getNextVideoFrame(_videoFrameBufferA);
        frameBuffer = _videoFrameBufferA;
    } else {
        self.curVideoFrameBufferA = YES;
        retVal = _preview->getNextVideoFrame(_videoFrameBufferB);
        frameBuffer = _videoFrameBufferB;
    }
    
    AppLog(@"video frame presentation time: %f", frameBuffer->getPresentationTime());
    if (retVal == ICH_SUCCEED) {
        [_videoData setLength:_videoRange.length];
        [_videoData replaceBytesInRange:_videoRange withBytes:frameBuffer->getBuffer()];
        [_videoData setLength:frameBuffer->getFrameSize()];
        videoFrameData = [[WifiCamAVData alloc] initWithData:_videoData
                                                     andTime:frameBuffer->getPresentationTime()];
    }
    
    return videoFrameData;
}

- (WifiCamAVData *)getAudioData2 {
    if (!_preview) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    
    WifiCamAVData *audioTrackData = nil;
    AppLog(@"getAudioData begin");
    int retVal = _preview->getNextAudioFrame(_audioTrackBufferA);
    AppLog(@"getAudioData end");
    AppLog(@"audio track presentation time: %f", _audioTrackBufferA->getPresentationTime());
    if (retVal == ICH_SUCCEED) {
        [_audioData setLength:_audioRange.length];
        [_audioData replaceBytesInRange:_audioRange withBytes:_audioTrackBufferA->getBuffer()];
        [_audioData setLength:_audioTrackBufferA->getFrameSize()];
        audioTrackData = [[WifiCamAVData alloc] initWithData:_audioData
                                                     andTime:_audioTrackBufferA->getPresentationTime()];
    } else {
        AppLog(@"** Get audio frame failed with error code %d.", retVal);
    }
    
    return audioTrackData;
}

- (WifiCamAVData *)getAudioData3 {
    if (!_preview) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    
    WifiCamAVData *audioTrackData = nil;
    ICatchFrameBuffer *frameBuffer = nil;
    int retVal;
    if (_curAudioTrackBufferA) {
        self.curAudioTrackBufferA = NO;
        retVal = _preview->getNextAudioFrame(_audioTrackBufferA);
        frameBuffer = _audioTrackBufferA;
    } else {
        self.curAudioTrackBufferA = YES;
        retVal = _preview->getNextAudioFrame(_audioTrackBufferB);
        frameBuffer = _audioTrackBufferB;
    }
   
    AppLog(@"audio track presentation time: %f", frameBuffer->getPresentationTime());
    if (retVal == ICH_SUCCEED) {
        [_audioData setLength:_audioRange.length];
        [_audioData replaceBytesInRange:_audioRange withBytes:frameBuffer->getBuffer()];
        [_audioData setLength:frameBuffer->getFrameSize()];
        audioTrackData = [[WifiCamAVData alloc] initWithData:_audioData
                                                     andTime:frameBuffer->getPresentationTime()];
    }
    
    return audioTrackData;
}

#pragma mark - CONTROL
- (WCRetrunType)capturePhoto {
    WCRetrunType retVal = WCRetSuccess;
    
    do {
        if (_sdkState && _sdkState->isCameraBusy() == false) {
            if (_control && _control->capturePhoto() != ICH_SUCCEED) {
                retVal = WCRetFail;
                break;
            }
        } else {
            retVal = WCRetFail;
            break;
        }
    } while (0);
    
    return retVal;
}

- (WCRetrunType)triggerCapturePhoto
{
    WCRetrunType retVal = WCRetSuccess;
    
    do {
        if (_sdkState && _sdkState->isCameraBusy() == false) {
            AppLog(@"Trigger capture.");
            if (_control && _control->triggerCapturePhoto() != ICH_SUCCEED) {
                retVal = WCRetFail;
                break;
            }
        } else {
            AppLog(@"Camera Busy!!!");
            retVal = WCRetFail;
            break;
        }
    } while (0);
    
    return retVal;
}

- (BOOL)startMovieRecord {
    if (!_control) {
        AppLog(@"SDK doesn't working.");
        return NO;
    }
    TRACE();
    int retVal = _control->startMovieRecord();
    AppLog(@"%s : retVal: %d", __func__, retVal);
    return retVal==ICH_SUCCEED?YES:NO;
}

- (BOOL)stopMovieRecord {
    if (!_control) {
        AppLog(@"SDK doesn't working.");
        return NO;
    }
    TRACE();
    int retVal = _control->stopMovieRecord();
    AppLog(@"%s : retVal: %d", __func__, retVal);
    return retVal==ICH_SUCCEED?YES:NO;
}

-(BOOL)startTimelapseRecord {
    TRACE();
    if (!_control) {
        AppLog(@"SDK doesn't working.");
        return NO;
    }
    int retVal = ICH_SUCCEED;
    retVal = _control->startTimeLapse();
    return retVal==ICH_SUCCEED?YES:NO;
}

-(BOOL)stopTimelapseRecord {
    TRACE();
    if (!_control) {
        AppLog(@"SDK doesn't working.");
        return NO;
    }
    int retVal = ICH_SUCCEED;
    retVal = _control->stopTimeLapse();
    return retVal==ICH_SUCCEED?YES:NO;
}

- (void)addObserver:(ICatchEventID)eventTypeId listener:(ICatchWificamListener *)listener isCustomize:(BOOL)isCustomize
{
    TRACE();
    if (listener && _control) {
        
        if (isCustomize) {
            AppLog(@"add customize eventTypeId: %d", eventTypeId);
            _control->addCustomEventListener(eventTypeId, listener);
        } else {
            AppLog(@"add eventTypeId: %d", eventTypeId);
            _control->addEventListener(eventTypeId, listener);
        }
    } else  {
        AppLog(@"listener is null");
    }
    
}

-(void)addObserver:(WifiCamObserver *)observer;
{
    if (observer.listener) {
        if (observer.isGlobal) {
            int ret = ICH_NULL;
            ret = ICatchWificamSession::addEventListener(observer.eventType, observer.listener, true);
            if (ret == ICH_SUCCEED) {
                AppLog(@"Add global event(0x%x,%p) listener succeed.", observer.eventType, observer);
            } else {
                AppLog(@"Add global event(0x%x,%p) listener failed.", observer.eventType, observer);
            }
            return;
        } else {
            if (_control) {
                if (observer.isCustomized) {
                    AppLog(@"add customize eventTypeId: %d", observer.eventType);
                    _control->addCustomEventListener(observer.eventType, observer.listener);
                } else {
                    AppLog(@"add eventTypeId: %d", observer.eventType);
                    _control->addEventListener(observer.eventType, observer.listener);
                }
            } else {
                AppLog(@"SDK isn't working.");
            }
        }
    } else  {
        AppLog(@"listener is null");
    }
}

-(void)removeObserver:(WifiCamObserver *)observer {
    if (observer.listener) {
        if (observer.isGlobal) {
            int ret = ICH_NULL;
            ret = ICatchWificamSession::delEventListener(observer.eventType, observer.listener, true);
            if (ret == ICH_SUCCEED) {
                AppLog(@"Remove global event(0x%x,%p) listener succeed.", observer.eventType, observer);
            } else {
                AppLog(@"Remove global event(0x%x,%p) listener failed.", observer.eventType, observer);
            }
            return;
        } else {
            if (_control) {
                if (observer.isCustomized) {
                    AppLog(@"Remove customize eventTypeId: %d", observer.eventType);
                    _control->delCustomEventListener(observer.eventType, observer.listener);
                } else {
                    AppLog(@"Remove eventTypeId: %d", observer.eventType);
                    _control->delEventListener(observer.eventType, observer.listener);
                }
            } else {
                AppLog(@"SDK isn't working.");
            }
            
        }
    } else  {
        AppLog(@"listener is null");
    }
}

- (void)removeObserver:(ICatchEventID)eventTypeId listener:(ICatchWificamListener *)listener isCustomize:(BOOL)isCustomize
{
    TRACE();
    if (listener && _control) {
        if (isCustomize) {
            _control->delCustomEventListener(eventTypeId, listener);
        } else {
            _control->delEventListener(eventTypeId, listener);
        }
    } else  {
        AppLog(@"listener is null");
    }
}

- (BOOL)formatSD {
    if (!_control) {
        AppLog(@"SDK doesn't working.");
        return NO;
    }
    int retVal = ICH_SUCCEED;
    retVal = _control->formatStorage();
    return retVal == ICH_SUCCEED ? YES : NO;
}

- (BOOL)checkSDExist {
//    BOOL retVal = YES;
//    
//    if (_control && _control->isSDCardExist() == false) {
//        retVal = NO;
//        AppLog(@"Please insert an SD card");
//    }
//    
//    return retVal;
    bool retVal;
    
    if (!_control) {
        AppLog(@"SDK doesn't working.");
        return NO;
    }
    
    int ret = _control->isSDCardExist(retVal);
    if (ret == ICH_SUCCEED) {
        return retVal;
    } else {
        AppLog(@"CheckSDExist failed. %d", ret);
        return NO;
    }
}

- (BOOL)zoomIn {
    if (!_control) {
        AppLog(@"SDK doesn't working.");
        return NO;
    }
    int ret = _control->zoomIn();
    if (ret != ICH_SUCCEED) {
        AppLog(@"ZoomIn failed. %d", ret);
        return NO;
    } else {
        return YES;
    }
    
}

- (BOOL)zoomOut {
    if (!_control) {
        AppLog(@"SDK doesn't working.");
        return NO;
    }
    int ret = _control->zoomOut();
    if (ret != ICH_SUCCEED) {
        AppLog(@"ZoomOut failed. %d", ret);
        return NO;
    } else {
        return YES;
    }
    
}


#pragma mark - PLAYBACK
- (vector<ICatchFile>)requestFileListOfType:(WCFileType)fileType
{
    vector<ICatchFile> list;
    if (_playback) {
        switch (fileType) {
            case WCFileTypeImage:
                _playback->listFiles(TYPE_IMAGE, list, 20);
                break;
                
            case WCFileTypeVideo:
                _playback->listFiles(TYPE_VIDEO, list, 20);
                break;
                
            case WCFileTypeAll:
                _playback->listFiles(TYPE_ALL, list, 20);
                break;
                
            case WCFileTypeAudio:
            case WCFileTypeText:
            case WCFileTypeUnknow:
            default:
                break;
        }
    } else {
        AppLog(@"SDK doesn't working.");
    }
    
    AppLog(@"listSize: %lu", list.size());
    return list;
}

- (UIImage *)requestThumbnail:(ICatchFile *)f {
    UIImage *retImg = nil;
    do {
        if (!f || !_playback) {
            AppLog(@"Invalid ICatchFile pointer used for download thumbnail. / SDK doesn't working.");
            break;
        }
        ICatchFrameBuffer *thumbBuf = new ICatchFrameBuffer(640*360*2);
        if (thumbBuf == NULL) {
            AppLog(@"new failed");
            break;
        }
        
        int ret = _playback->getThumbnail(f, thumbBuf);
        if (ICH_BUF_TOO_SMALL == ret) {
            AppLog(@"ICH_BUF_TOO_SMALL");
            break;
        }
        if (thumbBuf->getFrameSize() <=0) {
            AppLog(@"thumbBuf's data size <= 0, ret: %d", ret);
            break;
        }
        NSData *imageData = [NSData dataWithBytes:thumbBuf->getBuffer()
                                           length:thumbBuf->getFrameSize()];
        
        
        UIImage *thumbnail = [UIImage imageWithData:imageData];
        
        if (f->getFileType() == TYPE_VIDEO
            && [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
            UIImage *videoIcon = [UIImage imageNamed:@"image_video"];
            NSArray *imgArray = [[NSArray alloc] initWithObjects:videoIcon, nil];
            NSArray *imgPointArray = [[NSArray alloc] initWithObjects:@(5.0), @(thumbnail.size.height - videoIcon.size.height/2.0 - 5.0), nil];
            retImg = [Tool mergedImageOnMainImage:thumbnail WithImageArray:imgArray AndImagePointArray:imgPointArray];
        } else {
            retImg = thumbnail;
        }
        
        delete thumbBuf;
        thumbBuf = NULL;
    } while (0);
    
    
    
    return retImg;
}

- (UIImage *)requestImage:(ICatchFile *)f
{
    if (!f || !_playback) {
        AppLog(@"Invalid ICatchFile pointer used for downloading. / SDK doesn't working.");
        return nil;
    }
    UIImage* image = nil;
//    ICatchFrameBuffer *picBuf = new ICatchFrameBuffer(3648*2736/2);
    ICatchFrameBuffer *picBuf = new ICatchFrameBuffer(640*480);
    if (picBuf == NULL) {
        AppLog(@"new failed");
        return nil;
    }
    //int ret = _playback->downloadFile(f, picBuf);
    int ret = _playback->getQuickview(f, picBuf);
    
    if (ret == ICH_BUF_TOO_SMALL || ret == ICH_MTP_GET_OBJECTS_ERROR) {
        delete picBuf; picBuf = NULL;
        picBuf = new ICatchFrameBuffer(3648*2736);
        if (picBuf == NULL) {
            AppLog(@"New failed");
            return nil;
        }
        _playback->downloadFile(f, picBuf);
    }
    
    if (picBuf->getFrameSize() <=0) {
        AppLog(@"picBuf is empty");
        return nil;
    }
    NSData *imageData = [NSData dataWithBytes:picBuf->getBuffer()
                                       length:picBuf->getFrameSize()];
    delete picBuf; picBuf = NULL;
    image = [UIImage imageWithData:imageData];
    
    return image;
}

-(BOOL)deleteFile:(ICatchFile *)f
{
    int ret = -1;
    if (!f || !_playback) {
        AppLog(@"Invalid ICatchFile pointer used for deleting. / SDK doesn't working.");
        return NO;
    }
    switch (f->getFileType()) {
        case TYPE_IMAGE:
            ret = _playback->deleteFile(f);
            break;
            
        case TYPE_VIDEO:
            ret = _playback->deleteFile(f);
            break;
            
        case TYPE_AUDIO:
        case TYPE_TEXT:
        case TYPE_ALL:
        case TYPE_UNKNOWN:
        default:
            break;
    }
    
    if (ret != ICH_SUCCEED) {
        AppLog(@"Delete failed.");
        return NO;
    } else {
        return YES;
    }
}

- (void)timerFireMethod:(NSTimer*)theTimer//弹出框
{
    UIAlertView *promptAlert = (UIAlertView*)[theTimer userInfo];
    [promptAlert dismissWithClickedButtonIndex:0 animated:NO];
    promptAlert = nil;
}

-(void)cleanTemp
{
    NSArray *tmpDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:nil];
    for (NSString *file in  tmpDirectoryContents) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), file] error:nil];
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSArray *documentsDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    NSString *logFilePath = nil;
    for (NSString *fileName in  documentsDirectoryContents) {
        if (![fileName isEqualToString:@"Camera.sqlite"] && ![fileName isEqualToString:@"Camera.sqlite-shm"] && ![fileName isEqualToString:@"Camera.sqlite-wal"]) {
            
            logFilePath = [documentsDirectory stringByAppendingPathComponent:fileName];
            [[NSFileManager defaultManager] removeItemAtPath:logFilePath error:nil];
        }
    }
    
//    UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"应用空间已清理完成 !" message:nil delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil, nil];
//    
//    [NSTimer scheduledTimerWithTimeInterval:1.0f
//                                     target:self
//                                   selector:@selector(timerFireMethod:)
//                                   userInfo:alert
//                                    repeats:YES];
//    
//    [alert show];
}

- (void)               image: (UIImage *) image
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo;
{
    if (error) {
        AppLog(@"Error: %@", [error userInfo]);
    } else {
        AppLog(@"image Saved");
        
        
    }
}

- (void)               video: (NSString *) videoPath
    didFinishSavingWithError: (NSError *) error
                 contextInfo: (void *) contextInfo;
{
    
    if (error) {
        AppLog(@"Error: %@", [error userInfo]);
    } else {
        AppLog(@"video Saved");
        
        AppLog(@"Delete temp video: %@", videoPath);
        [[NSFileManager defaultManager] removeItemAtPath:videoPath error:nil];
    }
}

- (void)cancelDownload
{
    if (_playback) {
        _playback->cancelFileDownload();
        AppLog(@"Downloading Canceled");
    } else {
        AppLog(@"Downloading failed to cancel.");
    }
    
}

- (NSString *)p_downloadFile:(ICatchFile *)f {
    if (!f || !_playback) {
        AppLog(@"f is NULL or SDK doesn't working.");
        return nil;
    }
    NSString *fileName = [NSString stringWithUTF8String:f->getFileName().c_str()];
    NSString *locatePath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), fileName];
    int ret = _playback->downloadFile(f, [locatePath cStringUsingEncoding:NSUTF8StringEncoding]);
    
    AppLog(@"Download File, ret : %d", ret);
    if (ret != ICH_SUCCEED) {
        locatePath = nil;
    } else {
        
        AppLog(@"locatePath: %@", locatePath);
        
        NSString *filePath = [NSString stringWithFormat:@"%s", f->getFilePath().c_str()];
        AppLog(@"set file path %@ to 0xD83B", filePath);
        [self setCustomizeStringProperty:0xD83B value:filePath];
        
    }
    
    return locatePath;
}

-(BOOL)downloadFile:(ICatchFile *)f
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self createNewAssetCollection];
    });
    BOOL retVal = NO;
    NSURL *fileURL = nil;
    NSString *locatePath = [self p_downloadFile:f];
    if (locatePath) {
//        fileURL = [NSURL URLWithString:locatePath];
        fileURL = [NSURL fileURLWithPath:locatePath];
    } else {
        return retVal;
    }
    switch (f->getFileType()) {
        case TYPE_IMAGE:
            if (locatePath) {
                self.autoDownloadImage = [UIImage imageWithContentsOfFile:locatePath];
                retVal = [self addNewAssetWithURL:fileURL toAlbum:@"SBCapp"/*@"WiFiCam"*/ andFileType:TYPE_IMAGE];
                ++self.downloadedTotalNumber;
            }
            break;
            
        case TYPE_VIDEO:
            if (locatePath && UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(locatePath)) {
                retVal = [self addNewAssetWithURL:fileURL toAlbum:@"SBCapp"/*@"WiFiCam"*/ andFileType:TYPE_VIDEO];
                ++self.downloadedTotalNumber;
            } else {
                AppLog(@"The specified video can not be saved to user’s Camera Roll album");
            }
            break;
            
        case TYPE_AUDIO:
        case TYPE_TEXT:
        case TYPE_ALL:
        case TYPE_UNKNOWN:
        default:
            AppLog(@"Unsupported file type to download right now!!");
            break;
    }
    
    return retVal;
}

- (BOOL)openFileTransChannel
{
    if (!_playback) {
        AppLog(@"SDK doesn't work!!!");
        return NO;
    }
    
    int retVal = _playback->openFileTransChannel();
    if (retVal == ICH_SUCCEED) {
        AppLog(@"openFileTransChannel succeed.");
        return YES;
    } else {
        AppLog(@"openFileTransChannel failed: %d", retVal);
        return NO;
    }
}

- (BOOL)closeFileTransChannel
{
    if (!_playback) {
        AppLog(@"SDK doesn't work!!!");
        return NO;
    }
    
    int retVal = _playback->closeFileTransChannel();
    if (retVal == ICH_SUCCEED) {
        AppLog(@"closeFileTransChannel succeed.");
        return YES;
    } else {
        AppLog(@"closeFileTransChannel failed: %d", retVal);
        return NO;
    }
}

- (NSString *)p_downloadFile2:(ICatchFile *)f {
    if (!f || !_playback) {
        AppLog(@"f is NULL or SDK doesn't working.");
        return nil;
    }
    NSString *fileName = [NSString stringWithUTF8String:f->getFileName().c_str()];
    NSString *locatePath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), fileName];
    int ret = _playback->downloadFileQuick(f, [locatePath cStringUsingEncoding:NSUTF8StringEncoding]);
    
    AppLog(@"Download File, ret : %d", ret);
    if (ret != ICH_SUCCEED) {
        locatePath = nil;
    } else {
        
        AppLog(@"locatePath: %@", locatePath);
        
        NSString *filePath = [NSString stringWithFormat:@"%s", f->getFilePath().c_str()];
        AppLog(@"set file path %@ to 0xD83B", filePath);
        [self setCustomizeStringProperty:0xD83B value:filePath];
        
    }
    
    return locatePath;
}

-(BOOL)downloadFile2:(ICatchFile *)f
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self createNewAssetCollection];
    });
    BOOL retVal = NO;
    NSURL *fileURL = nil;
    NSString *locatePath = [self p_downloadFile2:f];
    if (locatePath) {
        //        fileURL = [NSURL URLWithString:locatePath];
        fileURL = [NSURL fileURLWithPath:locatePath];
    } else {
        return retVal;
    }
    switch (f->getFileType()) {
        case TYPE_IMAGE:
            if (locatePath) {
                self.autoDownloadImage = [UIImage imageWithContentsOfFile:locatePath];
                retVal = [self addNewAssetWithURL:fileURL toAlbum:@"SBCapp"/*@"WiFiCam"*/ andFileType:TYPE_IMAGE];
                ++self.downloadedTotalNumber;
            }
            break;
            
        case TYPE_VIDEO:
            if (locatePath && UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(locatePath)) {
                retVal = [self addNewAssetWithURL:fileURL toAlbum:@"SBCapp"/*@"WiFiCam"*/ andFileType:TYPE_VIDEO];
                ++self.downloadedTotalNumber;
            } else {
                AppLog(@"The specified video can not be saved to user’s Camera Roll album");
            }
            break;
            
        case TYPE_AUDIO:
        case TYPE_TEXT:
        case TYPE_ALL:
        case TYPE_UNKNOWN:
        default:
            AppLog(@"Unsupported file type to download right now!!");
            break;
    }
    
    return retVal;
}

#pragma mark - Video PB
- (BOOL)videoPlaybackEnabled
{
    return (_control && _control->supportVideoPlayback() == true) ? YES : NO;
}

- (double)play:(ICatchFile *)file; {
    double videoFileTotalSecs = 0;
    if (!_vplayback) {
        AppLog(@"SDK doesn't working.");
        return 0;
    }
    
    int ret = _vplayback->play(*file);
    if (ret != ICH_SUCCEED) {
        AppLog(@"play failed. ret: %d", ret);
    } else {
        _vplayback->getLength(videoFileTotalSecs);
    }
    
    return videoFileTotalSecs;
}

- (BOOL)pause {
    int ret = ICH_NULL;
    if (_vplayback != NULL) {
        ret = _vplayback->pause();
    }
    AppLog(@"PAUSE %@ ret: %d", ret == ICH_SUCCEED ? @"Succeed.":@"Failed.", ret);
    return ret == ICH_SUCCEED ? YES : NO;
}

- (BOOL)resume {
    int ret = ICH_NULL;
    if (_vplayback) {
        ret = _vplayback->resume();
    }
    AppLog(@"RESUME %@ ret: %d", ret == ICH_SUCCEED ? @"Succeed.":@"Failed.", ret);
    return ret == ICH_SUCCEED ? YES : NO;
}

- (BOOL)stop {
    int ret = ICH_NULL;
    if (_vplayback) {
        ret = _vplayback->stop();
    }
    AppLog(@"STOP %@ ret: %d", ret == ICH_SUCCEED ? @"Succeed.":@"Failed.", ret);
    return ret == ICH_SUCCEED ? YES : NO;
}

- (BOOL)seek:(double)point {
    int ret = ICH_NULL;
    if (_vplayback) {
        AppLog(@"call seek...");
        ret = _vplayback->seek(point);
    }
    AppLog(@"SEEK %@ ret: %d", ret == ICH_SUCCEED ? @"Succeed.":@"Failed.", ret);
    return ret == ICH_SUCCEED ? YES : NO;
}

- (WifiCamAVData *)getPlaybackFrameData {
    if (!_vplayback) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    WifiCamAVData *videoFrameData = nil;
    double time = 0;
    int retVal;
    NSRange maxRange = NSMakeRange(0, 640 * 480 * 2);
    
    ICatchFrameBuffer *frameBuffer = NULL;
    if (_vplayback == NULL) {
        return nil;
    }
    if (_curVideoFrameBufferA) {
        self.curVideoFrameBufferA = NO;
        retVal = _vplayback->getNextVideoFrame(_videoFrameBufferB);
        frameBuffer = _videoFrameBufferB;
    } else {
        self.curVideoFrameBufferA = YES;
        retVal = _vplayback->getNextVideoFrame(_videoFrameBufferA);
        frameBuffer = _videoFrameBufferA;
    }
    
    //    AppLog(@"getPlaybackFrameData : %d", retVal);
    
    if (retVal == ICH_SUCCEED) {
        if (!_videoPlaybackData) {
            //            AppLog(@"Create videoPlaybackData");
            self.videoPlaybackData = [NSMutableData dataWithBytes:frameBuffer->getBuffer()
                                                           length:maxRange.length];
        } else {
            _videoPlaybackData.length = maxRange.length;
            [_videoPlaybackData replaceBytesInRange:maxRange withBytes:frameBuffer->getBuffer()];
        }
        _videoPlaybackData.length = frameBuffer->getFrameSize();
        
        time = frameBuffer->getPresentationTime();
                RunLog(@"video PTS: %f", time);
        videoFrameData = [[WifiCamAVData alloc] initWithData:_videoPlaybackData andTime:time];
    } else {
        //        AppLog(@"--> getNextVideoFrame failed : %d", retVal);
        videoFrameData = [[WifiCamAVData alloc] init];
        videoFrameData.time = 0;
        videoFrameData.data = nil;
    }
    
    videoFrameData.state = retVal;
    return videoFrameData;
}

- (ICatchFrameBuffer *)getPlaybackAudioData1 {
    if (!_vplayback) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    
    int retVal = _vplayback->getNextAudioFrame(_audioTrackBufferA);

    if (retVal == ICH_SUCCEED) {
        
        return _audioTrackBufferA;
    } else {
//        AppLog(@"getNextAudioFrame failed : %d", retVal);
        return NULL;
    }
}

- (WifiCamAVData *)getPlaybackAudioData {
    NSDate *begin = nil;
    NSDate *end = nil;
    
    if (!_vplayback) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    WifiCamAVData *audioTrackData = nil;
    ICatchFrameBuffer *trackBuffer = NULL;
    int retVal = ICH_NULL;
    double time = 0;
    NSRange maxRange = NSMakeRange(0, 1024 * 50);
    
    if (_curAudioTrackBufferA) {
        self.curAudioTrackBufferA = NO;
        begin = [NSDate date];
        retVal = _vplayback->getNextAudioFrame(_audioTrackBufferB);
        end = [NSDate date];
        AppLog(@"getPlaybackAudioDataTime: %fms", [end timeIntervalSinceDate:begin] * 1000);
        trackBuffer = _audioTrackBufferB;
    } else {
        self.curAudioTrackBufferA = YES;
        begin = [NSDate date];
        retVal = _vplayback->getNextAudioFrame(_audioTrackBufferA);
        end = [NSDate date];
        AppLog(@"getPlaybackAudioDataTime: %fms", [end timeIntervalSinceDate:begin] * 1000);
        trackBuffer = _audioTrackBufferA;
    }
    
    if (retVal == ICH_SUCCEED) {
        if (!_audioPlaybackData) {
            AppLog(@"Create audioPlaybackData");
            //        self.audioPlaybackData = [NSMutableData dataWithBytesNoCopy:_audioTrackBuffer->getBuffer()
            //                                                     length:_audioTrackBuffer->getFrameSize()
            //                                               freeWhenDone:NO];
            self.audioPlaybackData = [NSMutableData dataWithBytes:trackBuffer->getBuffer()
                                                           length:maxRange.length];
        } else {
            _audioPlaybackData.length = maxRange.length;
            [_audioPlaybackData replaceBytesInRange:maxRange withBytes:trackBuffer->getBuffer()];
        }
        _audioPlaybackData.length = trackBuffer->getFrameSize();
        
        /*
         static dispatch_once_t onceToken;
         dispatch_once(&onceToken, ^{
         FILE *file;
         NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
         NSString *documentsDirectory = [paths objectAtIndex:0];
         NSString *filePath = [documentsDirectory stringByAppendingPathComponent:@"testAudio"];
         file = fopen([filePath cStringUsingEncoding:NSASCIIStringEncoding], "a+");
         
         fwrite(_audioTrackBuffer->getBuffer(), sizeof(char), _audioTrackBuffer->getFrameSize(), file);
         
         fclose(file);
         });
         */
        
        time = trackBuffer->getPresentationTime();
                AppLog(@"audio PTS: %f", time);
        audioTrackData = [[WifiCamAVData alloc] initWithData:_audioPlaybackData andTime:time];
    } else {
        //        AppLog(@"--> getNextAudioFrame failed : %d", retVal);
    }
    
    return audioTrackData;
}

- (NSData *)getPlaybackAudioData2 {
    NSDate *begin = nil;
    NSDate *end = nil;
    NSTimeInterval elapse = 0;
    
    begin = [NSDate date];
    if (!_vplayback) {
        AppLog(@"SDK doesn't work!!!");
        return nil;
    }
    
    int retVal = _vplayback->getNextAudioFrame(_audioTrackBufferA);
    end = [NSDate date];
    elapse = [end timeIntervalSinceDate:begin];
    AppLog(@"getNextAudioFrame: %f(%d)", elapse, _audioTrackBufferA->getFrameSize());
    
    
    //    begin = [NSDate date];
    if (retVal == ICH_SUCCEED) {
        
        [_audioPlaybackData setLength:_audioRange.length];
        [_audioPlaybackData replaceBytesInRange:_audioRange
                                      withBytes:_audioTrackBufferA->getBuffer()];
        [_audioPlaybackData setLength:_audioTrackBufferA->getFrameSize()];
        
        //        end = [NSDate date];
        //        elapse = [end timeIntervalSinceDate:begin];
        //        AppLog(@"After: %f", elapse);
        
        return _audioPlaybackData;
    } else {
        AppLog(@"--> getNextAudioFrame failed : %d", retVal);
        
        //        end = [NSDate date];
        //        elapse = [end timeIntervalSinceDate:begin];
        //        AppLog(@"After: %f", elapse);
        return nil;
    }
}

- (ICatchVideoFormat)getPlaybackVideoFormat {
    ICatchVideoFormat format;
    if (_vplayback) {
        _vplayback->getVideoFormat(format);
        
        AppLog(@"video format: %d", format.getCodec());
        AppLog(@"video w,h: %d, %d", format.getVideoW(), format.getVideoH());
    } else {
        AppLog(@"SDK doesn't work!!!");
    }
    
    
    return format;
}

-(ICatchAudioFormat)getPlaybackAudioFormat {
    ICatchAudioFormat format;
    if (_vplayback) {
        _vplayback->getAudioFormat(format);
    } else {
        AppLog(@"SDK doesn't work!!!");
    }
    
    return format;
}

- (BOOL)videoPlaybackStreamEnabled {
    return (_vplayback && _vplayback->containsVideoStream() == true) ? YES : NO;
}

- (BOOL)audioPlaybackStreamEnabled {
    return (_vplayback && _vplayback->containsAudioStream() == true) ? YES : NO;
}
#pragma mark - Customize properties
//------------------- modify by allen.chuang 20140703 -----------------
/*
 guo.jiang[20140918]
 
 */
// support customer property code
-(int)getCustomizePropertyIntValue:(int)propid {
    unsigned int value = 0;
    if (_prop) {
        _prop->getCurrentPropertyValue(propid, value);
        printf("\nproperty int value: %d\n", value);
    } else {
        AppLog(@"SDK doesn't working.");
    }
    
    return value;
}

-(NSString *)getCustomizePropertyStringValue:(int)propid {
    string value;
    
    if (_prop) {
        _prop->getCurrentPropertyValue(propid, value);
        printf("property string value: %s\n", value.c_str());
    } else {
        AppLog(@"SDK doesn't working.");
    }
    return [NSString stringWithFormat:@"%s", value.c_str()];
}

-(BOOL)setCustomizeIntProperty:(int)propid value:(uint)value {
    int ret = 1;
    if (_prop) {
        ret = _prop->setPropertyValue(propid, value);
    } else {
        AppLog(@"SDK doesn't working.");
    }
    AppLog(@"setProperty id:%d, value:%d",propid,value);
    return ret == ICH_SUCCEED ? YES : NO;
}

-(BOOL)setCustomizeStringProperty:(int)propid value:(NSString *)value {
    string stringValue = [value cStringUsingEncoding:NSUTF8StringEncoding];
    printf("set customized string property to : %s\n", stringValue.c_str());
    int ret = 1;
    if (_prop) {
        ret = _prop->setPropertyValue(propid, stringValue);
    } else {
        AppLog(@"SDK doesn't working.");
    }
    
    AppLog(@"setProperty id:%d, value:%@, ret : %d",propid,value, ret);
    return ret == ICH_SUCCEED ? YES : NO;
}

// check the customerid is valid or not
-(BOOL)isValidCustomerID:(int)customerid {
    int retid = [self getCustomizePropertyIntValue:0xD613];
    return (retid & 0xFF00) == (customerid & 0xFF00) ? YES : NO;
}

//add by zj.feng - 2017.3.16
- (vector<uint>)getCustomizeSupportedPropertyIntValues:(CustomizePropertyID)proid {
    vector<uint> value;
    int i = 0;
    
    if (_prop) {
        _prop->getSupportedPropertyValues(proid, value);
        for (vector<uint>::iterator it = value.begin(); it != value.begin(); ++it, ++i) {
            printf("getSupportedProperty is index: %d - value: %d\n", i, *it);
        }
    } else {
        AppLog(@"SDK doesn't working.");
    }
    
    return value;
}

- (vector<string>)getCustomizeSupportedPropertyStringValues:(CustomizePropertyID)proid {
    vector<string> value;
    int i = 0;
    
    if (_prop) {
        _prop->getSupportedPropertyValues(proid, value);
        for (vector<string>::iterator it = value.begin(); it != value.begin(); ++it, ++i) {
            printf("getSupportedProperty is index: %d - value: %s\n", i, (*it).c_str());
        }
    } else {
        AppLog(@"SDK doesn't working.");
    }
    
    return value;
}

#pragma mark -
-(UIImage *)getAutoDownloadImage {
    return self.autoDownloadImage;
}

-(void)updateFW:(string)fwPath {
    printf("%s\n", fwPath.c_str());
    int ret = ICatchWificamAssist::getInstance()->updateFw(_session, fwPath);
    AppLog(@"updateFw ret: %d", ret);
}

#pragma mark - Photo Album

- (void)createNewAssetCollection
{
    PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
    for (int i=0; i<topLevelUserCollections.count; ++i) {
        PHCollection *collection = [topLevelUserCollections objectAtIndex:i];
        if ([collection.localizedTitle isEqualToString:@"SBCapp"/*@"WiFiCam"*/]) {
            return;
        }
    }
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:@"SBCapp"/*@"WiFiCam"*/];
    } completionHandler:^(BOOL success, NSError *error) {
        NSLog(@"Finished adding asset collection. %@", (success ? @"Success" : error));
    }];
}

- (BOOL)addNewAssetWithURL:(NSURL *)fileURL toAlbum:(NSString *)albumName andFileType:(ICatchFileType)fileType
{
    NSError *error;
    BOOL retVal = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        // Request creating an asset from the image.
        PHAssetChangeRequest *createAssetRequest = nil;
        if (fileType == TYPE_IMAGE) {
            createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:fileURL];
        } else if (fileType == TYPE_VIDEO) {
            createAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:fileURL];
        } else {
            AppLog(@"Unknown file type to save.");
            return;
        }
        
        PHAssetCollection *myAssetCollection = nil;
        PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
        for (int i=0; i<topLevelUserCollections.count; ++i) {
            PHCollection *collection = [topLevelUserCollections objectAtIndex:i];
            if ([collection.localizedTitle isEqualToString:albumName]) {
                PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
                myAssetCollection = assetCollection;
                break;
            }
        }
        if (myAssetCollection && createAssetRequest) {
            // Request editing the album.
            PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:myAssetCollection];
            // Get a placeholder for the new asset and add it to the album editing request.
            PHObjectPlaceholder *assetPlaceholder = [createAssetRequest placeholderForCreatedAsset];
            [albumChangeRequest addAssets:@[ assetPlaceholder ]];
        }
        
    } error:&error];
    
    if (!retVal) {
        AppLog(@"Failed to save. %@", error.localizedDescription);
    }
    return retVal;
}

- (BOOL)savetoAlbum:(NSString *)albumName andAlbumAssetNum:(uint)assetNum andShareNum:(uint)shareNum
{
    /*static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self createNewAssetCollection];
    });*/
    [self createNewAssetCollection];
    
    uint cameraTotalNum = 0;
    while (assetNum + shareNum != cameraTotalNum) {
        @autoreleasepool {
            [NSThread sleepForTimeInterval:0.5];
            cameraTotalNum = (uint)[self retrieveCameraRollAssetsResult].count;
            AppLog(@"cameraTotalNum: %d", cameraTotalNum);
        }
    }
    
    return [self addNewAssettoAlbum:albumName andNumber:shareNum];
}

- (BOOL)addNewAssettoAlbum:(NSString *)albumName andNumber:(int)num
{
    NSError *error;
    BOOL retVal = [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
        
        PHAssetCollection *myAssetCollection = nil;
        PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
        for (int i=0; i<topLevelUserCollections.count; ++i) {
            PHCollection *collection = [topLevelUserCollections objectAtIndex:i];
            if ([collection.localizedTitle isEqualToString:albumName]) {
                PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
                myAssetCollection = assetCollection;
                break;
            }
        }
        
        // 获得相机胶卷
        PHAssetCollection *cameraRoll = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil].lastObject;
        
        PHFetchResult *assetResult = [PHAsset fetchAssetsInAssetCollection:cameraRoll options:[PHFetchOptions new]];
        for (int i = 0; i < num; i++) {
            [assetResult enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    //获取相册的照片
                    if (idx == [assetResult count] - (num - i)) {
                        if (myAssetCollection && obj) {
                            // Request editing the album.
                            PHAssetCollectionChangeRequest *albumChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:myAssetCollection];
                            // Get a placeholder for the new asset and add it to the album editing request.
                            [albumChangeRequest addAssets:@[obj]];
                        }
                    }
                } completionHandler:^(BOOL success, NSError *error) {
                    // NSLog(@"Error: %@", error);
                }];
            }];
        }
    } error:&error];
    
    if (!retVal) {
        AppLog(@"Failed to save. %@", error.localizedDescription);
    }
    
    return retVal;
}

- (PHFetchResult *)retrieveCameraRollAssetsResult
{
    PHAssetCollection *cameraRoll = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeSmartAlbumUserLibrary options:nil].lastObject;
    return  [PHAsset fetchAssetsInAssetCollection:cameraRoll options:[PHFetchOptions new]];
}

#pragma mark - READONLY
-(uint)previewCacheTime {
    uint cacheTime = 0;
    if (_prop) {
        _prop->getPreviewCacheTime(cacheTime);
    } else {
        AppLog(@"SDK isn't working");
    }
    
    return cacheTime;
}

-(BOOL)isSupportAutoDownload {
    return _sdkState->supportImageAutoDownload()==true ? YES : NO;
}

@end
