//
//  ViewController.m
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 13-12-5.
//  Copyright (c) 2013年 iCatchTech. All rights reserved.
//

#import "ViewController.h"
#import "ViewControllerPrivate.h"
#ifndef HW_DECODE_H264
#import "VideoFrameExtractor.h"
#endif

#include "SignInViewController.h"
#import <GoogleSignIn/GoogleSignIn.h>
#import <VideoToolbox/VideoToolbox.h>

#define TimeInterval [[[NSUserDefaults standardUserDefaults] stringForKey:@"LivePostTimeoutInterval"] doubleValue]

static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}

@implementation ViewController {
    /**
     * 20150630  guo.jiang
     * Deprecated ! (USE WifiCamObserver & WifiCamSDKEventListener.)
     */
    
    VideoRecOffListener *videoRecOffListener;
    VideoRecOnListener *videoRecOnListener;

    StillCaptureDoneListener *stillCaptureDoneListener;
    SDCardFullListener *sdCardFullListener;
    TimelapseStopListener *timelapseStopListener;
    TimelapseCaptureStartedListener *timelapseCaptureStartedListener;
    TimelapseCaptureCompleteListener *timelapseCaptureCompleteListener;
    VideoRecPostTimeListener *videoRecPostTimeListener;
    FileDownloadListener *fileDownloadListener; //ICATCH_EVENT_FILE_DOWNLOAD
    
    uint8_t *_sps;
    NSInteger _spsSize;
    uint8_t *_pps;
    NSInteger _ppsSize;
    CMVideoFormatDescriptionRef _decoderFormatDescription;
    VTDecompressionSessionRef _deocderSession;
}

#pragma mark - Lifecycle
- (void)viewDidLoad
{
    TRACE();
    [super viewDidLoad];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    WifiCamManager *app = [WifiCamManager instance];
    self.wifiCam = [app.wifiCams objectAtIndex:0];
    self.camera = _wifiCam.camera;
    self.ctrl = _wifiCam.controler;
    self.staticData = [WifiCamStaticData instance];
    
    [self p_constructPreviewData];
    [self p_initPreviewGUI];
    
    self.enableAudioButton.hidden = YES;
    self.sizeButton.userInteractionEnabled = NO;
  
    if ([self.enableAudioButton isHidden]) {
        [self.enableAudioButton removeFromSuperview];
    }
    // Test
    //    self.pvCache = [NSMutableArray arrayWithCapacity:30];
    
    UITapGestureRecognizer *tap0 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showZoomController:)];
    [_preview addGestureRecognizer:tap0];
    
#ifdef HW_DECODE_H264
    // H.264
    self.avslayer = [[AVSampleBufferDisplayLayer alloc] init];
    self.avslayer.bounds = _preview.bounds;
    self.avslayer.position = CGPointMake(CGRectGetMidX(_preview.bounds), CGRectGetMidY(_preview.bounds));
    self.avslayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.avslayer.backgroundColor = [[UIColor blackColor] CGColor];
    
    CMTimebaseRef controlTimebase;
    CMTimebaseCreateWithMasterClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(), &controlTimebase);
    self.avslayer.controlTimebase = controlTimebase;
    //    CMTimebaseSetTime(self.avslayer.controlTimebase, CMTimeMake(5, 1));
    CMTimebaseSetRate(self.avslayer.controlTimebase, 1.0);
    
    //    [self.view.layer insertSublayer:_avslayer below:_preview.layer];
    
    self.h264View = [[UIView alloc] initWithFrame:self.view.bounds];
    [_h264View.layer addSublayer:_avslayer];
    [self.view insertSubview:_h264View belowSubview:_preview];
    
    UITapGestureRecognizer *tap1 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(showZoomController:)];
    [_h264View addGestureRecognizer:tap1];
#endif
    self.userDefaults = [NSUserDefaults standardUserDefaults];
    [self iniIQSetting];
   
}

- (void)iniIQSetting{
    
    _CloseIQButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    _CloseIQButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    _CloseIQButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    _CloseIQButton.imageEdgeInsets = UIEdgeInsetsMake(40,40,40,40);
    
    _CloseIQSlider.imageView.contentMode = UIViewContentModeScaleAspectFit;
    _CloseIQSlider.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    _CloseIQSlider.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    _CloseIQSlider.imageEdgeInsets = UIEdgeInsetsMake(40,40,40,40);
    
    [_setIQbrightness setTitle:NSLocalizedString(@"SETTING_BRIGHTNESS",nil) forState:UIControlStateNormal];
    [_setIQhue setTitle:NSLocalizedString(@"SETTING_HUE",nil) forState:UIControlStateNormal];
    [_setIQsaturation setTitle:NSLocalizedString(@"SETTING_SATURATION",nil) forState:UIControlStateNormal];
    [_setIQWhiteBalance setTitle:NSLocalizedString(@"SETTING_AWB",nil) forState:UIControlStateNormal];
    [_setIQBLC setTitle:NSLocalizedString(@"SETTING_BLC",nil) forState:UIControlStateNormal];
    [_changeIqPwdButton setTitle:NSLocalizedString(@"change_password",nil) forState:UIControlStateNormal];
    _changeIqPwdButton.titleLabel.font = [UIFont systemFontOfSize:14];
    _setIQValueSlider.minimumValue = 0;
    _setIQValueSlider.maximumValue = 255;
    _setIQValueSlider.continuous = NO;
}

- (void)showLiveGUIIfNeeded:(WifiCamPreviewMode)curMode
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PreferenceSpecifier:Live"] && (curMode == WifiCamPreviewModeVideoOff || curMode == WifiCamPreviewModeVideoOn) && [[SDK instance] isStreamSupportPublish]) {
            _liveSwitch.hidden = NO;
            _liveTitle.hidden = NO;
            
        } else {
            _liveSwitch.hidden = YES;
            _liveTitle.hidden = YES;
            
        }
    });
}

-(void)viewWillAppear:(BOOL)animated
{
    TRACE();
    [super viewWillAppear:animated];
    self.AudioRun = _wifiCam.camera.enableAudio;
    if (!_AudioRun) {
        self.enableAudioButton.tag = 1;
        [self.enableAudioButton setBackgroundImage:[UIImage imageNamed:@"audio_off"]
                                          forState:UIControlStateNormal];
    }
    self.enableAudioButton.enabled = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recoverFromDisconnection)
                                             name    :@"kCameraNetworkConnectedNotification"
                                             object  :nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reconnectNotification:)
                                             name    :@"kCameraReconnectNotification"
                                             object  :nil];
    
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    delegate.delegate = self;
    
    NSString *authorization = [[[GIDSignIn sharedInstance].currentUser valueForKeyPath:@"authentication.accessToken"] description];
    AppLogInfo(AppLogTagAPP, @"authorization: %@", authorization);
    _authorization = authorization;

    if (_Living) {
        if (_authorization) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self createLiveBroadCast];
            });
        } else {
            [self liveErrorHandle:100 andMessage:@"未通过授权"];
        }
    }
}

-(void)reconnectNotification:(NSNotification*)notification
{
    _notificationView = (GCDiscreetNotificationView*)notification.object;
}
    
-(void)viewWillLayoutSubviews {
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")
        && !_customIOS7AlertView.hidden) {
        [_customIOS7AlertView updatePositionForDialogView];
    }
    [super viewWillLayoutSubviews];
}


- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (self.isEnterBackground) {
        return;
    }
    
   
    
    
    AppLog(@"curDateStamp: %d", _camera.curDateStamp);
//    if ([self capableOf:WifiCamAbilityDateStamp] && _camera.curDateStamp != DATE_STAMP_OFF) {
//        _preview.userInteractionEnabled = NO;
//#ifdef HW_DECODE_H264
//        _h264View.userInteractionEnabled = NO;
//#endif
//    } else {
//        _preview.userInteractionEnabled = YES;
//#ifdef HW_DECODE_H264
//        _h264View.userInteractionEnabled = YES;
//#endif
//    }
    
    
    // Update the Timelapse icon
    if ([self capableOf:WifiCamAbilityTimeLapse]
        && _camera.previewMode == WifiCamPreviewModeTimelapseOff
        && _camera.curTimelapseInterval != 0) {
        self.timelapseStateImageView.hidden = NO;
        if (_camera.timelapseType == WifiCamTimelapseTypeVideo) {
            self.timelapseStateImageView.image = [UIImage imageNamed:@"timelapse_video"];
        } else {
            self.timelapseStateImageView.image = [UIImage imageNamed:@"timelapse_capture"];
        }
    } else {
        self.timelapseStateImageView.hidden = YES;
    }
    
    // Update the Slow-Motion icon
    if ([self capableOf:WifiCamAbilitySlowMotion]
        && _camera.previewMode == WifiCamPreviewModeVideoOff
        && _camera.curSlowMotion == 1) {
        self.slowMotionStateImageView.hidden = NO;
    } else {
        self.slowMotionStateImageView.hidden = YES;
    }
    
    // Update the Invert-Mode icon
    if ([self capableOf:WifiCamAbilityUpsideDown]
        && _camera.curInvertMode == 1) {
        self.invertModeStateImageView.hidden = NO;
    } else {
        self.invertModeStateImageView.hidden = YES;
    }
    
    
    // Burst-capture icon
    if ([self capableOf:WifiCamAbilityBurstNumber]
        && _camera.previewMode == WifiCamPreviewModeCameraOff) {
        [self updateBurstCaptureIcon:_camera.curBurstNumber];
    }
    
    // Movie Rec timer
    if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]
        && (_camera.previewMode == WifiCamPreviewModeVideoOn
            || (_camera.previewMode == WifiCamPreviewModeTimelapseOn
                /*&& _camera.timelapseType == WifiCamTimelapseTypeVideo*/))) {
                self.movieRecordTimerLabel.hidden = NO;
            } else {
                self.movieRecordTimerLabel.hidden = YES;
            }
    
    // Update the size icon after delete or capture
    if ([self capableOf:WifiCamAbilityImageSize]
        && _camera.previewMode == WifiCamPreviewModeCameraOff) {
        [self updateImageSizeOnScreen:_camera.curImageSize];
    } else if ([self capableOf:WifiCamAbilityVideoSize]
               && _camera.previewMode == WifiCamPreviewModeVideoOff) {
        [self updateVideoSizeOnScreen:_camera.curVideoSize];
    } else if (_camera.previewMode == WifiCamPreviewModeTimelapseOff) {
        if (_camera.timelapseType == WifiCamTimelapseTypeStill) {
            [self updateImageSizeOnScreen:_camera.curImageSize];
        } else {
            [self updateVideoSizeOnScreen:_camera.curVideoSize];
        }
    }
    
    // Movie rec
    if ([self capableOf:WifiCamAbilityMovieRecord]) {
        videoRecOnListener = new VideoRecOnListener(self);
        [_ctrl.comCtrl addObserver:ICATCH_EVENT_VIDEO_ON
                          listener:videoRecOnListener
                       isCustomize:NO];
    }
    
    if (_camera.enableAutoDownload) {
        fileDownloadListener = new FileDownloadListener(self);
        [_ctrl.comCtrl addObserver:ICATCH_EVENT_FILE_DOWNLOAD
                          listener:fileDownloadListener
                       isCustomize:NO];
    }
    
    // Zoom In/Out
    uint maxZoomRatio = [_ctrl.propCtrl retrieveMaxZoomRatio];
    uint curZoomRatio = [_ctrl.propCtrl retrieveCurrentZoomRatio];
    AppLog(@"maxZoomRatio: %d", maxZoomRatio);
    AppLog(@"curZoomRatio: %d", curZoomRatio);
    self.zoomSlider.minimumValue = 1.0;
    self.zoomSlider.maximumValue = maxZoomRatio/10.0;
    self.zoomSlider.value = curZoomRatio/10.0;
    
    
    // Check SD card
    if (![_ctrl.propCtrl checkSDExist]) {
        [self showProgressHUDNotice:NSLocalizedString(@"NoCard", nil) showTime:2.0];
    } else if ((_camera.previewMode == WifiCamPreviewModeCameraOff && _camera.storageSpaceForImage <= 0)
               || (_camera.previewMode == WifiCamPreviewModeVideoOff && _camera.storageSpaceForVideo==0)) {
        [self showProgressHUDNotice:NSLocalizedString(@"CARD_FULL", nil) showTime:2.0];
    }
    
    if (_PVRun) {
        return;
    }
    self.PVRun = YES;
    _noPreviewLabel.hidden = YES;
    
    switch (_camera.previewMode) {
        case WifiCamPreviewModeCameraOff:
        case WifiCamPreviewModeCameraOn:
            [self runPreview:ICATCH_VIDEO_PREVIEW_MODE];
            break;
            
       /*
        case WifiCamPreviewModeTimelapseOff:
        case WifiCamPreviewModeTimelapseOn:
            if (_camera.timelapseType == WifiCamTimelapseTypeVideo) {
                // mark by allen.chuang 2015.1.15 ICOM-2692
                //if( [_ctrl.propCtrl changeTimelapseType:ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE] == WCRetSuccess)
                //    AppLog(@"change to ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE success");
                [self runPreview:ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE];
            } else {
                // mark by allen.chuang 2015.1.15 ICOM-2692
                //if( [_ctrl.propCtrl changeTimelapseType:ICATCH_TIMELAPSE_STILL_PREVIEW_MODE] == WCRetSuccess)
                //    AppLog(@"change to ICATCH_TIMELAPSE_STILL_PREVIEW_MODE success");
                [self runPreview:ICATCH_TIMELAPSE_STILL_PREVIEW_MODE];
            }
            
            break;
            20220115
        */
        case WifiCamPreviewModeVideoOff:
        case WifiCamPreviewModeVideoOn:
            [self runPreview:ICATCH_VIDEO_PREVIEW_MODE];
            
            break;
            
        default:
            break;
    }
    
}

- (void)viewWillDisappear:(BOOL)animated {
    TRACE();
    if (self.currentVideoData.length == 0) {
        self.savedCamera.thumbnail = (id)_preview.image;
    }
    
    [super viewWillDisappear:animated];
    [self hideZoomController:YES];
    
    //    AppLog(@"self.PVRun = NO");
    // Stop preview
    //    self.PVRun = NO;
    
    [self removeObservers];
    
    if (!_customIOS7AlertView.hidden) {
        _customIOS7AlertView.hidden = YES;
    }
    if (!_normalAlert.hidden) {
        [_normalAlert dismissWithClickedButtonIndex:0 animated:NO];
    }
    
    // Save data to sqlite
    NSError *error = nil;
    if (![self.savedCamera.managedObjectContext save:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         */
        AppLog(@"Unresolved error %@, %@", error, [error userInfo]);
#ifdef DEBUG
        abort();
#endif
    } else {
        AppLog(@"Saved to sqlite.");
    }
    
    
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kCameraNetworkConnectedNotification" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kCameraReconnectNotification" object:nil];
}

- (void)dealloc {
    NSLog(@"**DEALLOC**");
    [self p_deconstructPreviewData];
    [[SDK instance] destroySDK];
}

- (BOOL)capableOf:(WifiCamAbility)ability {
    return (_camera.ability & ability) == ability ? YES : NO;
}


-(void)recoverFromDisconnection {
    WifiCamManager *app = [WifiCamManager instance];
    self.wifiCam = [app.wifiCams objectAtIndex:0];
    self.camera = _wifiCam.camera;
    self.ctrl = _wifiCam.controler;
    self.staticData = [WifiCamStaticData instance];
    
    [self p_constructPreviewData];
    [self p_initPreviewGUI];
    
    [self viewDidAppear:YES];
}


#pragma mark - Initialization
- (void)p_constructPreviewData {
    BOOL onlyStillFunction = YES;
    
    self.previewGroup = dispatch_group_create();
    self.audioQueue = dispatch_queue_create("WifiCam.GCD.Queue.Preview.Audio", 0);
    self.videoQueue = dispatch_queue_create("WifiCam.GCD.Queue.Preview.Video", 0);
    
//    self.AudioRun = YES;
    if (!self.previewSemaphore) {
        self.previewSemaphore = dispatch_semaphore_create(1);
    }
    NSString *stillCaptureSoundUri = [[NSBundle mainBundle] pathForResource:@"Capture_Shutter" ofType:@"WAV"];
    id url = [NSURL fileURLWithPath:stillCaptureSoundUri];
//    OSStatus errcode =
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &_stillCaptureSound);
//    NSAssert1(errcode == 0, @"Failed to load sound ", @"Capture_Shutter.WAV");
    
    NSString *delayCaptureBeepUri = [[NSBundle mainBundle] pathForResource:@"DelayCapture_BEEP" ofType:@"WAV"];
    url = [NSURL fileURLWithPath:delayCaptureBeepUri];
//    errcode =
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &_delayCaptureSound);
//    NSAssert1(errcode == 0, @"Failed to load sound ", @"DelayCapture_BEEP.WAV");
    
    NSString *changeModeSoundUri = [[NSBundle mainBundle] pathForResource:@"ChangeMode" ofType:@"WAV"];
    url = [NSURL fileURLWithPath:changeModeSoundUri];
//    errcode =
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &_changeModeSound);
//    NSAssert1(errcode == 0, @"Failed to load sound ", @"ChangeMode.WAV");
    
    NSString *videoCaptureSoundUri = [[NSBundle mainBundle] pathForResource:@"StartStopVideoRec" ofType:@"WAV"];
    url = [NSURL fileURLWithPath:videoCaptureSoundUri];
//    errcode =
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &_videoCaptureSound);
//    NSAssert1(errcode == 0, @"Failed to load sound ", @"StartStopVideoRec.WAV");
    
    NSString *burstCaptureSoundUri = [[NSBundle mainBundle] pathForResource:@"BurstCapture&TimelapseCapture" ofType:@"WAV"];
    url = [NSURL fileURLWithPath:burstCaptureSoundUri];
//    errcode =
    AudioServicesCreateSystemSoundID((__bridge CFURLRef)url, &_burstCaptureSound);
//    NSAssert1(errcode == 0, @"Failed to load sound ", @"BurstCapture&TimelapseCapture.WAV");
    
    self.alertTableArray = [[NSMutableArray alloc] init];
    
    if ([self capableOf:WifiCamAbilityTimeLapse]) {
        [self p_initTimelapseRec];
        onlyStillFunction = NO;
    } else {
        [self.timelapseToggle removeFromSuperview];
        [self.timelapseStateImageView removeFromSuperview];
    }
    
    if ([self capableOf:WifiCamAbilityMovieRecord]) {
        if ([self capableOf:WifiCamAbilityVideoSize]) {
            if( _camera.cameraMode == MODE_TIMELAPSE_VIDEO
               || _camera.cameraMode == MODE_TIMELAPSE_VIDEO_OFF){
                self.tbVideoSizeArray = [_ctrl.propCtrl prepareDataForTimeLapseVideoSize:_camera.curVideoSize];
            }else
                self.tbVideoSizeArray = [_ctrl.propCtrl prepareDataForVideoSize:_camera.curVideoSize];
        }
        [self p_initMovieRec];
        onlyStillFunction = NO;
    }
    
    if ([self capableOf:WifiCamAbilityStillCapture]){
        if ([self capableOf:WifiCamAbilityImageSize]) {
            self.tbPhotoSizeArray = [_ctrl.propCtrl prepareDataForImageSize:_camera.curImageSize];
        }
        if ([self capableOf:WifiCamAbilityDelayCapture]) {
            self.tbDelayCaptureTimeArray = [_ctrl.propCtrl prepareDataForDelayCapture:_camera.curCaptureDelay];
        }
        if (onlyStillFunction) {
            _camera.previewMode = WifiCamPreviewModeCameraOff;
        }
    }
    
    AppLog(@"_camera.cameraMode: %d", _camera.cameraMode);
    switch (_camera.cameraMode) {
        case MODE_VIDEO_OFF:
            _camera.previewMode = WifiCamPreviewModeVideoOff;
            break;
            
        case MODE_CAMERA:
            _camera.previewMode = WifiCamPreviewModeCameraOff;
            break;
            
        case MODE_IDLE:
            break;
            
        case MODE_SHARED:
            break;
            
        case MODE_TIMELAPSE_STILL_OFF:
            _camera.previewMode = WifiCamPreviewModeTimelapseOff;
            _camera.timelapseType = WifiCamTimelapseTypeStill;
            break;
            
        case MODE_TIMELAPSE_STILL:
            _camera.previewMode = WifiCamPreviewModeTimelapseOn;
            _camera.timelapseType = WifiCamTimelapseTypeStill;
            break;
            
        case MODE_TIMELAPSE_VIDEO_OFF:
            _camera.previewMode =WifiCamPreviewModeTimelapseOff;
            _camera.timelapseType =WifiCamTimelapseTypeVideo;
            break;
            
        case MODE_TIMELAPSE_VIDEO:
            _camera.previewMode = WifiCamPreviewModeTimelapseOn;
            _camera.timelapseType = WifiCamTimelapseTypeVideo;
            break;
            
        case MODE_VIDEO_ON:
            _camera.previewMode = WifiCamPreviewModeVideoOn;
            break;
            
        case MODE_UNDEFINED:
        default:
            break;
    }
    
    [self updatePreviewSceneByMode:_camera.previewMode];
}

- (void)p_initMovieRec {
    AppLog(@"%s", __func__);
    self.stopOn = [UIImage imageNamed:@"stop_on"];
    self.stopOff = [UIImage imageNamed:@"stop_off"];
    
    if (false) {
        [self addMovieRecListener];
        if (![_videoCaptureTimer isValid]) {
            self.videoCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                    target  :self
                                                                    selector:@selector(movieRecordingTimerCallback:)
                                                                    userInfo:nil
                                                                    repeats :YES];
            
            if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
                self.movieRecordElapsedTimeInSeconds = [_ctrl.propCtrl retrieveCurrentMovieRecordElapsedTime];
                AppLog(@"elapsedTimeInSeconds: %d", _movieRecordElapsedTimeInSeconds);
                self.movieRecordTimerLabel.text = [Tool translateSecsToString:_movieRecordElapsedTimeInSeconds];
            }
            
        }
        _camera.previewMode = WifiCamPreviewModeVideoOn;
    }
}

- (void)p_initTimelapseRec {
    BOOL isTimelapseAlreadyStarted = NO;
    
    if (_camera.stillTimelapseOn) {
        AppLog(@"stillTimelapse On");
        _camera.timelapseType = WifiCamTimelapseTypeStill;
        isTimelapseAlreadyStarted = YES;
    } else if (_camera.videoTimelapseOn) {
        AppLog(@"videoTimelapseOn On");
        _camera.timelapseType = WifiCamTimelapseTypeVideo;
        isTimelapseAlreadyStarted = YES;
    }
    
    if (isTimelapseAlreadyStarted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![_videoCaptureTimer isValid]) {
                self.videoCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                        target  :self
                                                                        selector:@selector(movieRecordingTimerCallback:)
                                                                        userInfo:nil
                                                                        repeats :YES];
                if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
                    self.movieRecordElapsedTimeInSeconds = [_ctrl.propCtrl retrieveCurrentMovieRecordElapsedTime];
                    AppLog(@"elapsedTimeInSeconds: %d", _movieRecordElapsedTimeInSeconds);
                    self.movieRecordTimerLabel.text = [Tool translateSecsToString:_movieRecordElapsedTimeInSeconds];
                }
            }
        });
        [self addTimelapseRecListener];
        _camera.previewMode = WifiCamPreviewModeTimelapseOn;
    }
}

- (void)p_initPreviewGUI {
    if ([self capableOf:WifiCamAbilityStillCapture
         && self.snapButton.hidden]) {
        self.snapButton.hidden = NO;
    }
    if (self.mpbToggle.hidden) {
        self.mpbToggle.hidden = NO;
    }
    self.snapButton.exclusiveTouch = YES;
    self.mpbToggle.exclusiveTouch = YES;
    self.cameraToggle.exclusiveTouch = YES;
    self.videoToggle.exclusiveTouch = YES;
    self.sizeButton.exclusiveTouch = YES;
    self.view.exclusiveTouch = YES;
}

- (void)p_deconstructPreviewData {
    AudioServicesDisposeSystemSoundID(_stillCaptureSound);
    AudioServicesDisposeSystemSoundID(_delayCaptureSound);
    AudioServicesDisposeSystemSoundID(_changeModeSound);
    AudioServicesDisposeSystemSoundID(_videoCaptureSound);
    AudioServicesDisposeSystemSoundID(_burstCaptureSound);
}

#pragma mark - Action Progress
- (MBProgressHUD *)progressHUD {
    if (!_progressHUD) {
        _progressHUD = [[MBProgressHUD alloc] initWithView:self.view.window];
        _progressHUD.minSize = CGSizeMake(60, 60);
        _progressHUD.minShowTime = 1;
        _progressHUD.dimBackground = YES;
        // The sample image is based on the
        // work by: http://www.pixelpressicons.com
        // licence: http://creativecommons.org/licenses/by/2.5/ca/
        self.progressHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MWPhotoBrowser.bundle/images/Checkmark.png"]];
        [self.view.window addSubview:_progressHUD];
    }
    return _progressHUD;
}

- (void)showProgressHUDNotice:(NSString *)message
                     showTime:(NSTimeInterval)time {
    if (message) {
        [self.progressHUD show:YES];
        self.progressHUD.labelText = message;
        self.progressHUD.mode = MBProgressHUDModeText;
        [self.progressHUD hide:YES afterDelay:time];
    } else {
        [self.progressHUD hide:YES];
    }
}

- (void)showProgressHUDWithMessage:(NSString *)message {
    self.progressHUD.labelText = message;
    self.progressHUD.mode = MBProgressHUDModeIndeterminate;
    [self.progressHUD show:YES];
}

- (void)showProgressHUDCompleteMessage:(NSString *)message {
    if (message) {
        [self.progressHUD show:YES];
        self.progressHUD.labelText = message;
        self.progressHUD.detailsLabelText = nil;
        self.progressHUD.mode = MBProgressHUDModeCustomView;
        [self.progressHUD hide:YES afterDelay:1.0];
    } else {
        [self.progressHUD hide:YES];
    }
}

- (void)hideProgressHUD:(BOOL)animated {
    [self.progressHUD hide:animated];
}

#pragma mark - Preview GUI





- (void)updateBurstCaptureIcon:(unsigned int)curBurstNumber {
    if (curBurstNumber != BURST_NUMBER_OFF) {
        NSDictionary *burstNumberStringTable = [[WifiCamStaticData instance] burstNumberStringDict];
        id imageName = [[burstNumberStringTable objectForKey:@(curBurstNumber)] lastObject];
        UIImage *continuousCaptureImage = [UIImage imageNamed:imageName];
        _burstCaptureStateImageView.image = continuousCaptureImage;
        
        self.burstCaptureStateImageView.hidden = NO;
    } else {
        self.burstCaptureStateImageView.hidden = YES;
    }
}

- (void)updateSizeItemWithTitle:(NSString *)title
                     andStorage:(NSString *)storage {
  
}

- (void)updateImageSizeOnScreen:(string)imageSize {
    NSArray *imageArray = [_ctrl.propCtrl prepareDataForStorageSpaceOfImage: imageSize];
    _camera.storageSpaceForImage = [[imageArray lastObject] unsignedIntValue];
    NSString *storage = [NSString stringWithFormat:@"%d", _camera.storageSpaceForImage];
    [self updateSizeItemWithTitle:[imageArray firstObject]
                       andStorage:storage];
}

- (void)updateVideoSizeOnScreen:(string)videoSize {
    NSArray *videoArray = [_ctrl.propCtrl prepareDataForStorageSpaceOfVideo: videoSize];
    _camera.storageSpaceForVideo = [[videoArray lastObject] unsignedIntValue];
    NSString *storage = [Tool translateSecsToString: _camera.storageSpaceForVideo];
    [self updateSizeItemWithTitle:[videoArray firstObject] andStorage:storage];
}

- (void)setToCameraOffScene
{
    self.snapButton.enabled = YES;
    self.mpbToggle.enabled = YES;
    self.settingButton.enabled = YES;
    [self.cameraToggle setEnabled:YES];
    [self.videoToggle setEnabled:YES];
    if ([self capableOf:WifiCamAbilityTimeLapse]) {
        [self.timelapseToggle setEnabled:YES];
    }
    
  
    // CaptureSize Item
    if ([self capableOf:WifiCamAbilityImageSize]) {
      
        self.tbPhotoSizeArray = [_ctrl.propCtrl prepareDataForImageSize:_camera.curImageSize];
        [self updateImageSizeOnScreen:_camera.curImageSize];
        
    }
    
    // timelapse icon
    if (self.timelapseStateImageView.hidden == NO) {
        self.timelapseStateImageView.hidden = YES;
    }
    // slow-motion
    if (self.slowMotionStateImageView.hidden == NO) {
        self.slowMotionStateImageView.hidden = YES;
    }
    // invert-mode
    if (_camera.curInvertMode == 1) {
        self.invertModeStateImageView.hidden = NO;
    } else {
        self.invertModeStateImageView.hidden = YES;
    }
    // Burst-Capture icon
    if ([self capableOf:WifiCamAbilityBurstNumber]) {
        //self.burstCaptureStateImageView.hidden = NO;
        [self updateBurstCaptureIcon:_camera.curBurstNumber];
    }
    // movie record timer label
    /*
     if (!self.movieRecordTimerLabel.hidden) {
     self.movieRecordTimerLabel.hidden = YES;
     }
     */
    
    
    // Video Toggle & Timelapse Toggle & Camera Toggle
    if ([self capableOf:WifiCamAbilityMovieRecord]) {
        if (self.videoToggle.hidden) {
            self.videoToggle.hidden = NO;
        }
        [self.videoToggle setImage:[UIImage imageNamed:@"video_off"]
                          forState:UIControlStateNormal];
        self.videoToggle.enabled = YES;
    }
    
    if ([self capableOf:WifiCamAbilityTimeLapse]) {
        if (self.timelapseToggle.hidden) {
            self.timelapseToggle.hidden = NO;
        }
        
        [self.timelapseToggle setImage:[UIImage imageNamed:@"timelapse_off"]
                              forState:UIControlStateNormal];
        self.timelapseToggle.enabled = YES;
    }
    
    if ([self capableOf:WifiCamAbilityStillCapture]) {
        if (self.cameraToggle.hidden) {
            self.cameraToggle.hidden = NO;
        }
        
        [self.cameraToggle setImage:[UIImage imageNamed:@"camera_on"]
                           forState:UIControlStateNormal];
        self.cameraToggle.enabled = YES;
        [self.snapButton setImage:[UIImage imageNamed:@"ic_camera1"]
                         forState:UIControlStateNormal];
    }
    
    
    //self.autoDownloadThumbImage.hidden = YES;
}

- (void)setToCameraOnScene {
    self.snapButton.enabled = NO;
    self.mpbToggle.enabled = NO;
    self.settingButton.enabled = NO;
    self.cameraToggle.enabled = NO;
    self.videoToggle.enabled = NO;
    self.ImageQualityButton.enabled = NO;
    if ([self capableOf:WifiCamAbilityTimeLapse]) {
        self.timelapseToggle.enabled = NO;
    }
}

- (void)setToVideoOffScene {
    [self.mpbToggle setEnabled:YES];
    [self.settingButton setEnabled:YES];
    [self.enableAudioButton setEnabled:YES];
    [self.ImageQualityButton setEnabled:YES];

    
    // CaptureSize Item
    if ([self capableOf:WifiCamAbilityVideoSize]) {
        
        self.tbVideoSizeArray = [_ctrl.propCtrl prepareDataForVideoSize:_camera.curVideoSize];
        [self updateVideoSizeOnScreen:_camera.curVideoSize];
    }
    
    
    
    // timelapse icon
    if (self.timelapseStateImageView.hidden == NO) {
        self.timelapseStateImageView.hidden = YES;
    }
    
    // slow-motion
    if (_camera.curSlowMotion == 1) {
        self.slowMotionStateImageView.hidden = NO;
    } else {
        self.slowMotionStateImageView.hidden = YES;
    }
    
    // invert-mode
    if (_camera.curInvertMode == 1) {
        self.invertModeStateImageView.hidden = NO;
    } else {
        self.invertModeStateImageView.hidden = YES;
    }
    
    // Burst-Capture icon
    if (!self.burstCaptureStateImageView.hidden) {
        self.burstCaptureStateImageView.hidden = YES;
    }
    
    // Camera Toggle &Timelapse Toggle & Video Toggle
    if ([self capableOf:WifiCamAbilityStillCapture]) {
        if (self.cameraToggle.isHidden) {
            self.cameraToggle.hidden = NO;
        }
        [self.cameraToggle setImage:[UIImage imageNamed:@"camera_off"]
                           forState:UIControlStateNormal];
        [self.cameraToggle setEnabled:YES];
    }
    
    if ([self capableOf:WifiCamAbilityTimeLapse]) {
        if (self.timelapseToggle.isHidden) {
            self.timelapseToggle.hidden = NO;
        }
        [self.timelapseToggle setImage:[UIImage imageNamed:@"timelapse_off"]
                              forState:UIControlStateNormal];
        [self.timelapseToggle setEnabled:YES];
    }
    
    if ([self capableOf:WifiCamAbilityMovieRecord]) {
        if (self.videoToggle.isHidden) {
            self.videoToggle.hidden = NO;
        }
        [self.videoToggle setImage:[UIImage imageNamed:@"video_on"]
                          forState:UIControlStateNormal];
        [self.videoToggle setEnabled:YES];
        [self.snapButton setImage:[UIImage imageNamed:@"stop_on"]
                         forState:UIControlStateNormal];
        
        // movie record timer label
        if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
            self.movieRecordTimerLabel.hidden = YES;
        }
    }
    
    if (self.autoDownloadThumbImage.image) {
        self.autoDownloadThumbImage.hidden = NO;
    }
    
#if 0
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *curLiveSize = [defaults stringForKey:@"LiveSize"];
   
#endif
}

- (void)setToVideoOnScene
{
    [self setToVideoOffScene];
    
    if ([self capableOf:WifiCamAbilityStillCapture]) {
        self.cameraToggle.enabled = NO;
    }
    self.videoToggle.enabled = NO;
    self.mpbToggle.enabled = NO;
    self.settingButton.enabled = NO;
    self.enableAudioButton.enabled = NO;
    self.ImageQualityButton.enabled = NO;
    if ([self capableOf:WifiCamAbilityTimeLapse]) {
        self.timelapseToggle.enabled = NO;
    }
    if ([self capableOf:WifiCamAbilityVideoSize]) {
        self.sizeButton.enabled = NO;
    }
    
    if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
        self.movieRecordTimerLabel.text = @"00:00:00";
        self.movieRecordTimerLabel.hidden = NO;
    }
}

- (void)setToTimelapseOffScene
{
    [self.mpbToggle setEnabled:YES];
    [self.settingButton setEnabled:YES];
    
    //[_ctrl.propCtrl updateAllProperty:_camera];
    int retVal = [_ctrl.propCtrl retrieveCurrentTimelapseInterval];
    if (retVal >= 0) {
        _camera.curTimelapseInterval = retVal;
    }
    
    retVal = [[SDK instance] retrieveTimelapseDuration];
    if (retVal >= 0) {
        _camera.curTimelapseDuration = retVal;
    }
    
  
    
    // CaptureSize Item
  
    if ([self capableOf:WifiCamAbilityVideoSize] || [self capableOf:WifiCamAbilityImageSize]) {
        
        
        // update current video size. V35 cannot support 4K,2K in timelapse mode, so camera will auto-change video size
        // add by Allen
        _camera.curVideoSize = [_ctrl.propCtrl retrieveCurrentVideoSize2];
        
        //self.tbVideoSizeArray = [_ctrl.propCtrl prepareDataForVideoSize:_camera.curVideoSize];
//        self.tbVideoSizeArray = [_ctrl.propCtrl prepareDataForTimeLapseVideoSize:_camera.curVideoSize];
        
        
        if (_camera.timelapseType == WifiCamTimelapseTypeVideo) {
            self.tbVideoSizeArray = [_ctrl.propCtrl prepareDataForTimeLapseVideoSize:_camera.curVideoSize];
            [self updateVideoSizeOnScreen:_camera.curVideoSize];
        } else {
            self.tbPhotoSizeArray = [_ctrl.propCtrl prepareDataForImageSize:_camera.curImageSize];
            [self updateImageSizeOnScreen:_camera.curImageSize];
        }
        
        
        
    }
    
    
   
    
    // timelapse icon
    if (_camera.curTimelapseInterval != 0) {
        self.timelapseStateImageView.hidden = NO;
    }
    
    
    // slow-motion
    if (self.slowMotionStateImageView.hidden == NO) {
        self.slowMotionStateImageView.hidden = YES;
    }
    
    //
    if (_camera.curInvertMode == 1) {
        self.invertModeStateImageView.hidden = NO;
    } else {
        self.invertModeStateImageView.hidden = YES;
    }
    
    // Burst-Capture icon
    if (!self.burstCaptureStateImageView.hidden) {
        self.burstCaptureStateImageView.hidden = YES;
    }
    
    // Camera Toggle & Video Toggle &Timelapse Toggle
    if ([self capableOf:WifiCamAbilityStillCapture]) {
        if (self.cameraToggle.isHidden) {
            self.cameraToggle.hidden = NO;
        }
        [self.cameraToggle setImage:[UIImage imageNamed:@"camera_off"]
                           forState:UIControlStateNormal];
        [self.cameraToggle setEnabled:YES];
    }
    
    if ([self capableOf:WifiCamAbilityMovieRecord]) {
        if (self.videoToggle.isHidden) {
            self.videoToggle.hidden = NO;
        }
        [self.videoToggle setImage:[UIImage imageNamed:@"video_off"]
                          forState:UIControlStateNormal];
        [self.videoToggle setEnabled:YES];
        
        // movie record timer label
        if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
            self.movieRecordTimerLabel.hidden = YES;
        }
        
    }
    
    if ([self capableOf:WifiCamAbilityTimeLapse]) {
        if (self.timelapseToggle.isHidden) {
            self.timelapseToggle.hidden = NO;
        }
        [self.timelapseToggle setImage:[UIImage imageNamed:@"timelapse_on"]
                              forState:UIControlStateNormal];
        [self.timelapseToggle setEnabled:YES];
        [self.snapButton setImage:[UIImage imageNamed:@"stop_on"]
                         forState:UIControlStateNormal];
    }
    
    self.autoDownloadThumbImage.hidden = YES;
}

- (void)setToTimelapseOnScene
{
    [self setToTimelapseOffScene];
    
    if ([self capableOf:WifiCamAbilityStillCapture]) {
        self.cameraToggle.enabled = NO;
    }
    if ([self capableOf:WifiCamAbilityMovieRecord]) {
        self.videoToggle.enabled = NO;
    }
    self.mpbToggle.enabled = NO;
    self.settingButton.enabled = NO;
    self.timelapseToggle.enabled = NO;
    if ([self capableOf:WifiCamAbilityVideoSize]) {
        self.sizeButton.enabled = NO;
    }
    
    if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
        self.movieRecordTimerLabel.text = @"00:00:00";
        self.movieRecordTimerLabel.hidden = NO;
    }
    
}

- (void)updatePreviewSceneByMode:(WifiCamPreviewMode)mode
{
    _camera.previewMode = mode;
    AppLog(@"camera.previewMode: %lu", (unsigned long)_camera.previewMode);
    switch (mode) {
        case WifiCamPreviewModeCameraOff:
            [self setToCameraOffScene];
            break;
        case WifiCamPreviewModeCameraOn:
            [self setToCameraOnScene];
            break;
        case WifiCamPreviewModeVideoOff:
            [self setToVideoOffScene];
            break;
        case WifiCamPreviewModeVideoOn:
            [self setToVideoOnScene];
            break;
        /*
        case WifiCamPreviewModeTimelapseOff:
            [self setToTimelapseOffScene];
            break;
        case WifiCamPreviewModeTimelapseOn:
            [self setToTimelapseOnScene];
            break;
        */
        default:
            break;
    }
}

#pragma mark - Preview
- (void)runPreview:(ICatchPreviewMode)mode
{
    if (self.isEnterBackground) {
        return;
    }
    
    AppLog(@"%s start(%d)", __func__, mode);
    self.videoPlayFlag = NO;
    
    self.previewMode = mode;
    dispatch_queue_t previewQ = dispatch_queue_create("WifiCam.GCD.Queue.Preview", DISPATCH_QUEUE_SERIAL);
    dispatch_time_t timeOutCount = dispatch_time(DISPATCH_TIME_NOW, 5ull * NSEC_PER_SEC);
    
    [self showProgressHUDWithMessage:nil];
    dispatch_async(previewQ, ^{
        if (dispatch_semaphore_wait(_previewSemaphore, timeOutCount) != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self showErrorAlertView];
            });
            return;
        }
        
        int ret = ICH_NULL;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PreferenceSpecifier:Live"] && (_camera.previewMode == WifiCamPreviewModeVideoOff || _camera.previewMode == WifiCamPreviewModeVideoOn)) {
            ret = [[SDK instance] startMediaStream:mode enableAudio:self.AudioRun enableLive:YES];
        } else {
            ret = [_ctrl.actCtrl startPreview:mode withAudioEnabled:self.AudioRun];
        }
        if (ret != ICH_SUCCEED) {
            dispatch_semaphore_signal(_previewSemaphore);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updatePreviewSceneByMode:_camera.previewMode];
                [self hideProgressHUD:YES];
                _preview.image = nil;
                _noPreviewLabel.hidden = NO;
                if (ret == ICH_STREAM_NOT_SUPPORT) {
                    _noPreviewLabel.text = NSLocalizedString(@"PreviewNotSupported", nil);
                } else {
                    _noPreviewLabel.text = NSLocalizedString(@"StartPVFailed", nil);
                }
                _preview.userInteractionEnabled = NO;
#ifdef HW_DECODE_H264
                _h264View.userInteractionEnabled = NO;
#endif
            });
            return;
            
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updatePreviewSceneByMode:_camera.previewMode];
                [self hideProgressHUD:YES];
                _noPreviewLabel.hidden = YES;
                _preview.userInteractionEnabled = YES;
#ifdef HW_DECODE_H264
                _h264View.userInteractionEnabled = YES;
#endif
                if (![_ctrl.propCtrl checkSDExist]) {
                    [self showProgressHUDNotice:NSLocalizedString(@"NoCard", nil) showTime:2.0];
                } else if (((_camera.previewMode == WifiCamPreviewModeCameraOff && _camera.storageSpaceForImage <= 0)
                            || ((_camera.previewMode == WifiCamPreviewModeVideoOff || _camera.previewMode == WifiCamPreviewModeVideoOn) && _camera.storageSpaceForVideo==0)) && [_ctrl.propCtrl connected]) {
                    [self showProgressHUDNotice:NSLocalizedString(@"CARD_FULL", nil) showTime:2.0];
                } else {
                    
                }
                
#if 1
                [self showLiveGUIIfNeeded:_camera.previewMode];
#else
                if ([[SDK instance] isStreamSupportPublish]) {
                    _liveSwitch.hidden = NO;
                    _liveTitle.hidden = NO;
                   
                } else {
                    _liveSwitch.hidden = YES;
                    _liveTitle.hidden = YES;
                }
#endif
            });
            
            WifiCamSDKEventListener *listener = new WifiCamSDKEventListener(self, @selector(streamCloseCallback));
            self.streamObserver = [[WifiCamObserver alloc] initWithListener:listener
                                                                  eventType:ICATCH_EVENT_MEDIA_STREAM_CLOSED
                                                               isCustomized:NO isGlobal:NO];
            [[SDK instance] addObserver:_streamObserver];
        }
        
        if ([_ctrl.propCtrl audioStreamEnabled] && self.AudioRun) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.enableAudioButton.tag = 0;
                [self.enableAudioButton setBackgroundImage:[UIImage imageNamed:@"audio_on"]
                                                  forState:UIControlStateNormal];
                self.enableAudioButton.enabled = YES;
            });
            dispatch_group_async(self.previewGroup, self.audioQueue, ^{[self playbackAudio];});
        } else {
            self.AudioRun = NO;
            AppLog(@"Streaming doesn't contains audio.");
        }
        
        
        if ([_ctrl.propCtrl videoStreamEnabled]) {
            dispatch_group_async(self.previewGroup, self.videoQueue, ^{[self playbackVideo];});
        } else {
            AppLog(@"Streaming doesn't contains video.");
        }
        
        dispatch_group_notify(_previewGroup, previewQ, ^{
            [[SDK instance] removeObserver:_streamObserver];
            delete _streamObserver.listener;
            _streamObserver.listener = NULL;
            self.streamObserver = nil;
            
            [_ctrl.actCtrl stopPreview];
            dispatch_semaphore_signal(_previewSemaphore);
        });
    });
}


#pragma mark - Preview
- (void)ChangePreviewMode:(ICatchPreviewMode)mode
{
    if (self.isEnterBackground) {
        return;
    }
    
    self.previewMode = mode;
 
    dispatch_semaphore_signal(_previewSemaphore);
    dispatch_async(dispatch_get_main_queue(), ^{
                [self updatePreviewSceneByMode:_camera.previewMode];
                [self hideProgressHUD:YES];
            });
}


-(BOOL)dataIsValidJPEG:(NSData *)data
{
    if (!data || data.length < 2) return NO;
    
    NSInteger totalBytes = data.length;
    const char *bytes = (const char*)[data bytes];
    
    return (bytes[0] == (char)0xff &&
            bytes[1] == (char)0xd8 &&
            bytes[totalBytes-2] == (char)0xff &&
            bytes[totalBytes-1] == (char)0xd9);
}

- (BOOL)dataIsIFrame:(NSData *)data {
    if (!data || data.length < 5) return NO;

//    char array[] = {0x00, 0x00, 0x00, 0x01, 0x65};
    const char *bytes = (const char*)[data bytes];
//    printf("%02x, %02x, %02x, %02x, %02x \n", bytes[0], bytes[1], bytes[2], bytes[3], bytes[4]);
    return bytes[4] == 0x65 ? YES : NO;
}

-(BOOL)initH264Env:(ICatchVideoFormat)format {
    
    AppLog(@"w:%d, h: %d", format.getVideoW(), format.getVideoH());
    
    _spsSize = format.getCsd_0_size()-4;
    _sps = (uint8_t *)malloc(_spsSize);
    memcpy(_sps, format.getCsd_0()+4, _spsSize);
    /*
     printf("sps:");
     for(int i=0;i<_spsSize;++i) {
     printf("0x%x ", _sps[i]);
     }
     printf("\n");
     */
    
    _ppsSize = format.getCsd_1_size()-4;
    _pps = (uint8_t *)malloc(_ppsSize);
    memcpy(_pps, format.getCsd_1()+4, _ppsSize);
    /*
     printf("pps:");
     for(int i=0;i<_ppsSize;++i) {
     printf("0x%x ", _pps[i]);
     }
     printf("\n");
     */
    
    AppLog(@"sps:%ld, pps: %ld", (long)_spsSize, (long)_ppsSize);
    
    const uint8_t* const parameterSetPointers[2] = { _sps, _pps };
    const size_t parameterSetSizes[2] = { static_cast<size_t>(_spsSize), static_cast<size_t>(_ppsSize) };
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &_decoderFormatDescription);
    if(status != noErr) {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", (int)status);
    } else {
        CFDictionaryRef attrs = NULL;
        const void *keys[] = { kCVPixelBufferPixelFormatTypeKey };
        //      kCVPixelFormatType_420YpCbCr8Planar is YUV420
        //      kCVPixelFormatType_420YpCbCr8BiPlanarFullRange is NV12
        uint32_t v = kCVPixelFormatType_32BGRA;
        const void *values[] = { CFNumberCreate(NULL, kCFNumberSInt32Type, &v) };
        attrs = CFDictionaryCreate(NULL, keys, values, 1, NULL, NULL);
        
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        callBackRecord.decompressionOutputRefCon = NULL;
        
        VTDecompressionSessionCreate(kCFAllocatorDefault,
                                     _decoderFormatDescription,
                                     NULL, attrs,
                                     &callBackRecord,
                                     &_deocderSession);
        CFRelease(attrs);
    }
    
    return YES;
}

-(void)clearH264Env {
    if(_deocderSession) {
        VTDecompressionSessionInvalidate(_deocderSession);
        CFRelease(_deocderSession);
        _deocderSession = NULL;
    }
    
    if(_decoderFormatDescription) {
        CFRelease(_decoderFormatDescription);
        _decoderFormatDescription = NULL;
    }
    free(_sps);
    free(_pps);
    _spsSize = _ppsSize = 0;
}

-(void)decodeAndDisplayH264Frame:(NSData *)frame {
    CMBlockBufferRef blockBuffer = NULL;
    CMSampleBufferRef sampleBuffer = NULL;
    
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                         (void*)frame.bytes, frame.length,
                                                         kCFAllocatorNull,
                                                         NULL, 0, frame.length,
                                                         0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        const size_t sampleSizeArray[] = {frame.length};
        
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        CFRelease(blockBuffer);
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        if (status == kCMBlockBufferNoErr) {
            if ([_avslayer isReadyForMoreMediaData]) {
                dispatch_sync(dispatch_get_main_queue(),^{
                    [_avslayer enqueueSampleBuffer:sampleBuffer];
                });
            }
            CFRelease(sampleBuffer);
        }
    }
}

// MARK: - save last video frame
- (CVPixelBufferRef)decodeToPixelBufferRef:(NSData*)vp {
    CVPixelBufferRef outputPixelBuffer = NULL;
    
    CMBlockBufferRef blockBuffer = NULL;
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault,
                                                          (void*)vp.bytes, vp.length,
                                                          kCFAllocatorNull,
                                                          NULL, 0, vp.length,
                                                          0, &blockBuffer);
    if(status == kCMBlockBufferNoErr) {
        CMSampleBufferRef sampleBuffer = NULL;
        const size_t sampleSizeArray[] = {vp.length};
        status = CMSampleBufferCreateReady(kCFAllocatorDefault,
                                           blockBuffer,
                                           _decoderFormatDescription ,
                                           1, 0, NULL, 1, sampleSizeArray,
                                           &sampleBuffer);
        if (status == kCMBlockBufferNoErr && sampleBuffer) {
            VTDecodeFrameFlags flags = 0;
            VTDecodeInfoFlags flagOut = 0;
            OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_deocderSession,
                                                                      sampleBuffer,
                                                                      flags,
                                                                      &outputPixelBuffer,
                                                                      &flagOut);
            
            if(decodeStatus == kVTInvalidSessionErr) {
                NSLog(@"IOS8VT: Invalid session, reset decoder session");
            } else if(decodeStatus == kVTVideoDecoderBadDataErr) {
                NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)decodeStatus);
            } else if(decodeStatus != noErr) {
                NSLog(@"IOS8VT: decode failed status=%d", (int)decodeStatus);
            }
            
            CFRelease(sampleBuffer);
        }
        CFRelease(blockBuffer);
    }
    
    return outputPixelBuffer;
}

- (UIImage *)imageFromPixelBufferRef:(NSData *)data {
    CVPixelBufferRef pixelBuffer = [self decodeToPixelBufferRef:data];
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    UIImage *image = [UIImage imageWithCIImage:ciImage];
//    AppLog("last image: %@", image);
    return image;
}

- (NSMutableData *)currentVideoData {
    if (_currentVideoData == nil) {
        _currentVideoData = [NSMutableData data];
    }
    
    return _currentVideoData;
}

- (void)recordCurrentVideoFrame:(NSData *)data {
    if ([self dataIsIFrame:data]) {
        self.currentVideoData.length = 0;
        [self.currentVideoData appendData:data];
    }
}

- (void)saveLastVideoFrame:(UIImage *)image {
    CGSize size = CGSizeMake(120, 120);
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    self.savedCamera.thumbnail = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
}

-(void)playbackVideoH264:(ICatchVideoFormat) format {
//    NSMutableData *videoFrameData = nil;
#ifdef HW_DECODE_H264
    NSRange headerRange = NSMakeRange(0, 4);
    NSMutableData *headFrame = nil;
    uint32_t nalSize = 0;
#else
    // Decode using FFmpeg
    VideoFrameExtractor *ff_h264_decoder = [[VideoFrameExtractor alloc] initWithSize:format.getVideoW()
                                                                           andHeight:format.getVideoH()];
#endif
    
    while (_PVRun) {
#ifdef HW_DECODE_H264
        if (_readyGoToSetting) {
            AppLog(@"Sleep 1 second.");
            [NSThread sleepForTimeInterval:1.0];
            continue;
        }
        
        //flush avslayer when active from background
        if (self.avslayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
            [self.avslayer flush];
        }
        
        // HW decode
        [self initH264Env:format];
        for(;;) {
            @autoreleasepool {
                // 1st frame contains sps & pps data.
#if RUN_DEBUG
                NSDate *begin = [NSDate date];
                WifiCamAVData *avData = [[SDK instance] getVideoData2];
                NSDate *end = [NSDate date];
                NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
                AppLog(@"[V]Get %lu, elapse: %f", (unsigned long)avData.data.length, elapse);
#else
                NSDate *begin = [NSDate date];
                WifiCamAVData *avData = [[SDK instance] getVideoData2];
#endif
                if (avData.data.length > 0) {
                    self.curVideoPTS = avData.time;
                    
                    NSUInteger loc = (4+_spsSize)+(4+_ppsSize);
                    nalSize = (uint32_t)(avData.data.length - loc - 4);
                    NSRange iRange = NSMakeRange(loc, avData.data.length - loc);
                    const uint8_t lengthBytes[] = {(uint8_t)(nalSize>>24),
                        (uint8_t)(nalSize>>16), (uint8_t)(nalSize>>8), (uint8_t)nalSize};
                    headFrame = [NSMutableData dataWithData:[avData.data subdataWithRange:iRange]];
                    [headFrame replaceBytesInRange:headerRange withBytes:lengthBytes];
                    NSDate *end1 = [NSDate date];
                    
                    [self decodeAndDisplayH264Frame:headFrame];
                    NSDate *end = [NSDate date];
                    AppLog(@"getVideoDataTime: %f, decodeTime: %f, PTS: %f", [end1 timeIntervalSinceDate:begin] * 1000, [end timeIntervalSinceDate:end1] * 1000, avData.time);
                    
                    [self recordCurrentVideoFrame:headFrame];
                    break;
                }
            }
        }
        while (_PVRun) {
            @autoreleasepool {
#if RUN_DEBUG
                NSDate *begin = [NSDate date];
                WifiCamAVData *avData = [[SDK instance] getVideoData2];
                NSDate *end = [NSDate date];
                NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
                AppLog(@"[V]Get %lu, elapse: %f", (unsigned long)avData.data.length, elapse);
#else
                WifiCamAVData *avData = [[SDK instance] getVideoData2];
#endif
                if (avData.data.length > 0) {
                    self.curVideoPTS = avData.time;
                    nalSize = (uint32_t)(avData.data.length - 4);
                    const uint8_t lengthBytes[] = {(uint8_t)(nalSize>>24),
                        (uint8_t)(nalSize>>16), (uint8_t)(nalSize>>8), (uint8_t)nalSize};
                    [avData.data replaceBytesInRange:headerRange withBytes:lengthBytes];
                    self.videoPlayFlag = YES;
                    [self decodeAndDisplayH264Frame:avData.data];
                    
                    [self recordCurrentVideoFrame:avData.data];
                }
            }
        }
        
        if (self.currentVideoData.length > 0) {
            [self saveLastVideoFrame:[self imageFromPixelBufferRef:self.currentVideoData]];
        }
        
        [self clearH264Env];
#else
        // Decode using FFmpeg
        videoFrameData = [[SDK instance] getVideoData];
        if (videoFrameData) {
            [ff_h264_decoder fillData:(uint8_t *)videoFrameData.bytes
                                 size:videoFrameData.length];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *receivedImage = ff_h264_decoder.currentImage;
                if (_PVRun && receivedImage) {
                    _preview.image = receivedImage;
                }
                
            });
            
        }
#endif
    }
}

-(void)playbackVideoMJPEG {
//    NSMutableData *videoFrameData = nil;
//    UIImage *receivedImage = nil;
    
    while (_PVRun) {
        @autoreleasepool {
            if (_readyGoToSetting) {
                AppLog(@"Sleep 1 second.");
                [NSThread sleepForTimeInterval:1.0];
                continue;
            }
#if RUN_DEBUG
            NSDate *begin = [NSDate date];
            WifiCamAVData *avData = [[SDK instance] getVideoData2];
            NSDate *end = [NSDate date];
            NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
            AppLog(@"[V]Get %lu, elapse: %f", (unsigned long)avData.data.length, elapse);
#else
            WifiCamAVData *avData = [[SDK instance] getVideoData2];
#endif
            if (avData.data.length > 0) {
                self.curVideoPTS = avData.time;
                if (![self dataIsValidJPEG:avData.data]) {
                    AppLog(@"Invalid JPEG.");
                    continue;
                }
                
                UIImage *receivedImage = [[UIImage alloc] initWithData:avData.data];
                dispatch_sync(dispatch_get_main_queue(), ^{
                    if (_PVRun && receivedImage) {
                        self.videoPlayFlag = YES;
//                        TRACE();
                        _preview.image = receivedImage;
                    }
                });
                
                //            videoFrameData = nil;
                receivedImage = nil;
            }
        }
    }
}

- (void)playbackVideo {
    
    /*
     dispatch_queue_t mainQueue = dispatch_get_main_queue();
     NSMutableData *videoFrameData = nil;
     UIImage *receivedImage = nil;
     */
    
    ICatchVideoFormat format = [_ctrl.propCtrl retrieveVideoFormat];
    if (format.getCodec() == ICATCH_CODEC_JPEG) {
        AppLog(@"playbackVideoMJPEG");
#ifdef HW_DECODE_H264
        dispatch_async(dispatch_get_main_queue(), ^{
            _preview.hidden = NO;
            //_avslayer.hidden = YES;
            _h264View.hidden = YES;
        });
#endif
        [self playbackVideoMJPEG];
        
    } else if (format.getCodec() == ICATCH_CODEC_H264) {
        
        AppLog(@"playbackVideoH264");
#ifdef HW_DECODE_H264
        // HW decode
        dispatch_async(dispatch_get_main_queue(), ^{
            //_avslayer.hidden = NO;
            _h264View.hidden = NO;
            _avslayer.bounds = _preview.bounds;
            _avslayer.position = CGPointMake(CGRectGetMidX(_preview.bounds), CGRectGetMidY(_preview.bounds));
            _preview.hidden = YES;
        });
#endif
        [self playbackVideoH264:format];
    } else {
        AppLog(@"Unknown codec.");
    }

    AppLog(@"Break video");
}

- (void)playbackAudio {
    /*
     NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
     NSString *cacheDirectory = [paths objectAtIndex:0];
     NSString *toFilePath = [cacheDirectory stringByAppendingPathComponent:@"test.raw"];
     AppLog(@"TO : %@", toFilePath);
     FILE *toFileHandle = fopen(toFilePath.UTF8String, "wb");
     */
//    NSData *audioBufferData = nil;
//    NSMutableData *audioBuffer3Data = [[NSMutableData alloc] init];
    self.al = [[HYOpenALHelper alloc] init];
    ICatchAudioFormat format = [_ctrl.propCtrl retrieveAudioFormat];
    
    AppLog(@"freq: %d, chl: %d, bit:%d", format.getFrequency(), format.getNChannels(), format.getSampleBits());
    
    if (![_al initOpenAL:format.getFrequency() channel:format.getNChannels() sampleBit:format.getSampleBits()]) {
        AppLog(@"Init OpenAL failed.");
        return;
    }
    
    while (_PVRun) {
        @autoreleasepool {
            if (_readyGoToSetting || !_AudioRun) {
                [NSThread sleepForTimeInterval:1.0];
                continue;
            }
            
            NSDate *begin = [NSDate date];
            WifiCamAVData *wifiCamData = [[SDK instance] getAudioData2];
            NSDate *end = [NSDate date];
            NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
            AppLog(@"[A]Get %lu, elapse: %f", (unsigned long)wifiCamData.data.length, elapse);
            
            if (wifiCamData.data.length > 0 && self.videoPlayFlag) {
                [_al insertPCMDataToQueue:wifiCamData.data.bytes
                                     size:wifiCamData.data.length];
                [_al play];
            }
            
            //            if (wifiCamData.time >= _curVideoPTS + 0.1 && _curVideoPTS != 0) {
            //                [NSThread sleepForTimeInterval:0.003];
            //            }
            //            if((wifiCamData.time >= _curVideoPTS - 0.25 && _curVideoPTS != 0) ||
            //               (wifiCamData.time <= _curVideoPTS + 0.25 && _curVideoPTS != 0)) {
            //                [_al play];
            //            } else {
            //                [_al pause];
            //            }
            //        }
            
//                    int count = [_al getInfo];
//                    if(count < 4) {
//                        if (count == 1) {
//                            [_al play];
//                        }
//            
//                        [audioBuffer3Data setLength:0];
//            
//                        for (int i=0; i<3; ++i) {
//            
//                            NSDate *begin = [NSDate date];
//                            WifiCamAVData *wifiCamData = [[SDK instance] getAudioData2];
//                            NSDate *end = [NSDate date];
//                            NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
//                            AppLog(@"[A]Get %lu, elapse: %f", (unsigned long)wifiCamData.data.length, elapse);
//            
//                            if (wifiCamData) {
//                                [audioBuffer3Data appendData:wifiCamData.data];
//                            }
//                        }
//                        
//                        if(audioBuffer3Data.length>0) {
//                            [_al insertPCMDataToQueue:audioBuffer3Data.bytes
//                                                 size:audioBuffer3Data.length];
//                        }
//                    }
        }
    }
    [_al clean];
    self.al = nil;
    /*
     fwrite(audioBufferData.bytes, sizeof(char), audioBufferData.length, toFileHandle);
     fclose(toFileHandle);
     */
    AppLog(@"Break audio");
}

+ (NSString*)formatTypeToString:(ICatchPreviewMode)formatType {
    NSString *result = nil;

    switch(formatType) {
        case ICATCH_STILL_PREVIEW_MODE:
            result = @"ICATCH_STILL_PREVIEW_MODE";
            break;
        case ICATCH_VIDEO_PREVIEW_MODE:
            result = @"ICATCH_VIDEO_PREVIEW_MODE";
            break;
        case ICATCH_TIMELAPSE_STILL_PREVIEW_MODE:
            result = @"ICATCH_TIMELAPSE_STILL_PREVIEW_MODE";
            break;
        case ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE:
            result = @"ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE";
            break;
        default:
            [NSException raise:NSGenericException format:@"Unexpected FormatType."];
    }

    return result;
}

+ (NSString*)formatTypeToString2:(WifiCamPreviewMode)formatType {
    NSString *result = nil;

    switch(formatType) {
        case WifiCamPreviewModeCameraOff:
            result = @"WifiCamPreviewModeCameraOff";
            break;
        case WifiCamPreviewModeCameraOn:
            result = @"WifiCamPreviewModeCameraOn";
            break;
        case WifiCamPreviewModeVideoOff:
            result = @"WifiCamPreviewModeVideoOff";
            break;
        case WifiCamPreviewModeVideoOn:
            result = @"WifiCamPreviewModeVideoOn";
            break;
        default:
            [NSException raise:NSGenericException format:@"Unexpected FormatType."];
    }

    return result;
}

- (IBAction)getmode:(id)sender
{
   
   
    
}

- (void) ShowAlert:(NSString *)Message {
    UIAlertController * alert=[UIAlertController alertControllerWithTitle:nil
                                                                  message:@""
                                                           preferredStyle:UIAlertControllerStyleAlert];
    UIView *firstSubview = alert.view.subviews.firstObject;
    UIView *alertContentView = firstSubview.subviews.firstObject;
    for (UIView *subSubView in alertContentView.subviews) {
        subSubView.backgroundColor = [UIColor colorWithRed:0/255.0f green:0/255.0f blue:0/255.0f alpha:1.0f];
    }
    [alertContentView addConstraint:([NSLayoutConstraint constraintWithItem: alertContentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem: nil attribute:NSLayoutAttributeNotAnAttribute multiplier: 1 constant: 230])];
    
    NSMutableAttributedString *AS = [[NSMutableAttributedString alloc] initWithString:Message];
    [AS addAttribute: NSFontAttributeName value: [UIFont systemFontOfSize:15]  range: NSMakeRange(0,AS.length)];
    [alert setValue:AS forKey:@"attributedTitle"];
    
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:^{
        }];
    });
}

- (void)checkIQPassword:(UIView *)view
{
     
    UIAlertController * alert = [UIAlertController
                                 alertControllerWithTitle:NSLocalizedString(@"please_input_password",nil)
                                 message:nil
                                 preferredStyle:UIAlertControllerStyleAlert];

    //Add Buttons

    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = NSLocalizedString(@"current_password",nil);
        [textField addConstraint:([NSLayoutConstraint constraintWithItem: textField attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem: nil attribute:NSLayoutAttributeNotAnAttribute multiplier: 1 constant: 30])];
        
        textField.secureTextEntry = YES;
    }];
    
    UIAlertAction* changePwdButton = [UIAlertAction
                                actionWithTitle:NSLocalizedString(@"change_password",nil)
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {
                                        [self changeIQPassword];
                                }];
    
    UIAlertAction* yesButton = [UIAlertAction
                                actionWithTitle:NSLocalizedString(@"sure",nil)
                                style:UIAlertActionStyleDefault
                                handler:^(UIAlertAction * action) {
                                    //Handle your yes please button action here
                                        NSString *temp =  [[alert textFields][0] text];
                                        
        
                                        NSString *string;
                                        //[_userDefaults setObject:string forKey:@"test"];
                                        //[_userDefaults synchronize];
                                      
                                        if([self->_userDefaults stringForKey:@"IQ_password"].length ==0){
                                            [self->_userDefaults setObject:@"password" forKey:@"IQ_password"];
                                            [self->_userDefaults synchronize];
                                            string = [self->_userDefaults stringForKey:@"IQ_password"];
                                        }else{
                                            string = [self->_userDefaults stringForKey:@"IQ_password"];
                                        }
        
                                        if([temp isEqualToString:string]){
                                            self->_IQ_isCheckPassword = YES;
                                            view.hidden = NO;
                                        }
                                        else{
                                            [self ShowAlert:NSLocalizedString(@"iq_password_error", nil)];
                                        }
                                }];

    UIAlertAction* noButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"cancel",nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                                   //cancel
                               }];

    //Add your buttons to alert controller
    
    [alert addAction:yesButton];
    [alert addAction:noButton];
    [alert addAction:changePwdButton];
    

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)changeIQPassword
{
    UIAlertController * alert = [UIAlertController
                                alertControllerWithTitle:NSLocalizedString(@"change_password",nil)
                                message:nil
                                preferredStyle:UIAlertControllerStyleAlert];

   //Add Buttons

   [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
       textField.placeholder = NSLocalizedString(@"input_old_password",nil);
       [textField addConstraint:([NSLayoutConstraint constraintWithItem: textField attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem: nil attribute:NSLayoutAttributeNotAnAttribute multiplier: 1 constant: 30])];
       textField.secureTextEntry = YES;
   }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField1) {
        textField1.placeholder = NSLocalizedString(@"input_new_password",nil);
        [textField1 addConstraint:([NSLayoutConstraint constraintWithItem: textField1 attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem: nil attribute:NSLayoutAttributeNotAnAttribute multiplier: 1 constant: 30])];
        textField1.secureTextEntry = YES;
    }];
    
   
   

   
   UIAlertAction* yesButton = [UIAlertAction
                               actionWithTitle:NSLocalizedString(@"sure",nil)
                               style:UIAlertActionStyleDefault
                               handler:^(UIAlertAction * action) {
                               NSString *string;
                               NSString *old_pwd=[[alert textFields][0] text];
                               NSString *new_pwd=[[alert textFields][1] text];
                               if([new_pwd length]==0){
                                   [self ShowAlert:NSLocalizedString(@"new_password_null", nil)];
                                   return;
                               }
                             
                               if([self->_userDefaults stringForKey:@"IQ_password"].length ==0){
                                   [self->_userDefaults setObject:@"password" forKey:@"IQ_password"];
                                   [self->_userDefaults synchronize];
                                   string = [self->_userDefaults stringForKey:@"IQ_password"];
                               }else{
                                   string = [self->_userDefaults stringForKey:@"IQ_password"];
                               }
       
                               
                               if([old_pwd isEqualToString:string]){
                                    self->_IQ_isCheckPassword = NO;
                                   [self->_userDefaults setObject:new_pwd forKey:@"IQ_password"];
                                   [self->_userDefaults synchronize];
                                   [self ShowAlert:NSLocalizedString(@"change_password_sucess", nil)];
                               }else{
                                   [self ShowAlert:NSLocalizedString(@"iq_password_error", nil)];
                               }
                                    
                               }];

   UIAlertAction* noButton = [UIAlertAction
                              actionWithTitle:NSLocalizedString(@"cancel",nil)
                              style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * action) {
                                  //Handle no, thanks button
                              }];

   //Add your buttons to alert controller
   
 
   [alert addAction:noButton];
   [alert addAction:yesButton];
   [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)changeIqPwdButton:(id)sender
{
    [self changeIQPassword];
}

    
- (IBAction)showViewImageQuality:(id)sender
{
    if(![self IQ_isCheckPassword]){
        [self checkIQPassword:_ImageQualityView];
    }else{
        _ImageQualityView.hidden = NO;
    }
}

- (IBAction)CloseImageQuality:(id)sender
{
    _ImageQualityView.hidden = YES;
    [_ctrl.propCtrl saveIQvalue];
}



- (IBAction)closeSetIQValueView:(id)sender
{
    _setIQValueView.hidden = YES;
    _ImageQualityView.hidden = NO;
}


- (IBAction)setIQtype:(id)sender
{
   // [_ctrl.propCtrl changeBrightness:128];
    _setBLCSwitch.hidden = YES;
    _setWB_AUTO.hidden = YES;
    _setWB_DAYLIGHT.hidden = YES;
    _setWB_CLOUDY.hidden = YES;
    _setWB_INCADESCENT.hidden = YES;
    _setWB_FLOURESCENT_H.hidden = YES;
    switch ([sender tag]){
        case 0:{
            _curIQMode = BRIGHTNESS;
            _setIQValueSlider.maximumValue = 255;
            _setIQValueView.hidden = NO;
            _setIQValueSlider.hidden = NO;
            _showIQValueLabel.hidden = NO;
            _showIQsilderLabel.hidden = NO;
            NSString *tempvalue = [_ctrl.propCtrl retrieveIQbrightnessValue];
            _showIQValueLabel.text = tempvalue;
            _setIQValueSlider.value = [tempvalue floatValue];
            [_showIQsilderLabel setText:NSLocalizedString(@"SETTING_BRIGHTNESS",nil)];
            break;
            
        }
        case 1:{
            _curIQMode = HUE;
            _setIQValueSlider.maximumValue = 360;
            _setIQValueView.hidden = NO;
            _setIQValueSlider.hidden = NO;
            _showIQValueLabel.hidden = NO;
            _showIQsilderLabel.hidden = NO;
            NSString *tempvalue1 = [_ctrl.propCtrl retrieveIQhueValue];
            _showIQValueLabel.text = tempvalue1;
            _setIQValueSlider.value = [tempvalue1 floatValue];
            [_showIQsilderLabel setText:NSLocalizedString(@"SETTING_HUE",nil)];
            break;
            
        }
        case 2:{
            _curIQMode = SATURATION;
            _setIQValueSlider.maximumValue = 255;
            _setIQValueView.hidden = NO;
            _setIQValueSlider.hidden = NO;
            _showIQValueLabel.hidden = NO;
            _showIQsilderLabel.hidden = NO;
            NSString *tempvalue2 = [_ctrl.propCtrl retrieveIQsaturationValue];
            _showIQValueLabel.text = tempvalue2;
            _setIQValueSlider.value = [tempvalue2 floatValue];
            [_showIQsilderLabel setText:NSLocalizedString(@"SETTING_SATURATION",nil)];
            break;
        }
        case 3:{
            _curIQMode = WHTIE_BALANCE;
            _setIQValueView.hidden = NO;
            _setIQValueSlider.hidden = YES;
            _showIQValueLabel.hidden = YES;
            _showIQsilderLabel.hidden = YES;
            _setWB_AUTO.hidden = NO;
            _setWB_DAYLIGHT.hidden = NO;
            _setWB_CLOUDY.hidden = NO;
            _setWB_INCADESCENT.hidden = NO;
            _setWB_FLOURESCENT_H.hidden = NO;
            [_setWB_AUTO setTitle:NSLocalizedString(@"SETTING_AWB_AUTO",nil) forState:UIControlStateNormal];
            [_setWB_DAYLIGHT setTitle:NSLocalizedString(@"SETTING_AWB_DAYLIGHT",nil) forState:UIControlStateNormal];
            [_setWB_CLOUDY setTitle:NSLocalizedString(@"SETTING_AWB_CLOUDY",nil) forState:UIControlStateNormal];
            [_setWB_INCADESCENT setTitle:NSLocalizedString(@"SETTING_AWB_INCANDESCENT",nil) forState:UIControlStateNormal];
            [_setWB_FLOURESCENT_H setTitle:NSLocalizedString(@"SETTING_AWB_FLUORESECENT",nil) forState:UIControlStateNormal];
            break;
        }
        case 4:{
            _curIQMode = BLC;
            _setIQValueView.hidden = NO;
            _setIQValueSlider.hidden = YES;
            _showIQValueLabel.hidden = YES;
            _showIQsilderLabel.hidden = NO;
            _setBLCSwitch.hidden = NO;
            BOOL tempvalue3 = [_ctrl.propCtrl retrieveIQBLCValue];
            [_setBLCSwitch setOn:(BOOL)tempvalue3];
            [_showIQsilderLabel setText:NSLocalizedString(@"SETTING_BLC",nil)];
            break;
        }
       
        
    }
    
}

- (IBAction)changeIQ_BLC_Switch:(id)sender
{
    ([sender isOn])?[_ctrl.propCtrl changeBLC:YES]:[_ctrl.propCtrl changeBLC:NO];
}

- (IBAction)changeIQvalueSlider:(id)sender
{
    switch (_curIQMode){
        case BRIGHTNESS:{
            [_ctrl.propCtrl changeBrightness:_setIQValueSlider.value];
            _showIQValueLabel.text = [[NSString alloc] initWithFormat:@"%d",(int)_setIQValueSlider.value];
            break;
        }
        case HUE:{
            [_ctrl.propCtrl changeHue:_setIQValueSlider.value];
            _showIQValueLabel.text = [[NSString alloc] initWithFormat:@"%d",(int)_setIQValueSlider.value];
            break;
        }
        case SATURATION:{
            [_ctrl.propCtrl changeSaturation:_setIQValueSlider.value];
            _showIQValueLabel.text = [[NSString alloc] initWithFormat:@"%d",(int)_setIQValueSlider.value];
            break;
        }
    }
}

- (IBAction)changeWBtype:(id)sender
{
    NSInteger value = 0;
    value = [sender tag];
    [_ctrl.propCtrl changeWhiteBalance:(int)value];
}

- (IBAction)captureAction:(id)sender
{
    // Capture
    switch(_camera.previewMode) {
        case WifiCamPreviewModeCameraOff:
            [self PhotoCapture];
            break;
        case WifiCamPreviewModeVideoOff:
            [self startMovieRec];
            break;
        case WifiCamPreviewModeVideoOn:
            [self stopMovieRec];
            break;
        case WifiCamPreviewModeCameraOn:
            break;
        /*
        case WifiCamPreviewModeTimelapseOff:
            if (_camera.curTimelapseInterval != 0 && _camera.curTimelapseDuration>0) {
                [self startTimelapseRec];
            } else {
                [self showTimelapseOffAlert];
            }
            break;
        case WifiCamPreviewModeTimelapseOn:
            [self stopTimelapseRec];
            break;
        */
        default:
            break;
    }
}

- (void)showTimelapseOffAlert {
    [self showProgressHUDNotice:NSLocalizedString(@"TimelapseOff", nil) showTime:2.0];
}

- (void)stillCapture {
    if (![self capableOf:WifiCamAbilityNewCaptureWay]) {
        [self showProgressHUDWithMessage:nil];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updatePreviewSceneByMode:WifiCamPreviewModeCameraOn];
        });
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateImageSizeOnScreen:_camera.curImageSize];
//        });

        if (![_ctrl.propCtrl checkSDExist]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:NSLocalizedString(@"NoCard", nil)
                                   showTime:1.0];
                [self updatePreviewSceneByMode:WifiCamPreviewModeCameraOff];
            });
            return;
        }
        if (_camera.storageSpaceForImage==0/*![[SDK instance] checkstillCapture]*/ && [_ctrl.propCtrl connected]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:NSLocalizedString(@"CARD_FULL", nil)
                                   showTime:1.0];
                [self updatePreviewSceneByMode:WifiCamPreviewModeCameraOff];
            });
            return;
        }
        
        if (![[SDK instance] checkstillCapture]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:NSLocalizedString(@"STREAM_CAPTURE_FAILED", nil)
                                   showTime:1.0];
                [self updatePreviewSceneByMode:WifiCamPreviewModeCameraOff];
            });
            return;
        }
        
        self.burstCaptureCount = [[_staticData.burstNumberDict objectForKey:@(_camera.curBurstNumber)] integerValue];
        NSInteger delayCaptureCount = [[_staticData.delayCaptureDict objectForKey:@(_camera.curCaptureDelay)] integerValue]*2 - 1;
        
        // Stop streaming right now?
        if (// Doesn't support delay-capture, stop right now.
            ![self capableOf:WifiCamAbilityDelayCapture]
            // Support delay-capture, but it's OFF, stop right now.
            || _camera.curCaptureDelay == CAP_DELAY_NO
            // Doesn't support ***(stop after delay), stop right now.
            || ![self capableOf:WifiCamAbilityLatestDelayCapture]) {
            
            if (![self capableOf:WifiCamAbilityBurstNumber] || _burstCaptureCount == 0 || _burstCaptureCount > 0) {
                AudioServicesPlaySystemSound(_stillCaptureSound);
            }
            
            if (![self capableOf:WifiCamAbilityNewCaptureWay]) {
                AppLog(@"Stop PV");
                self.PVRun = NO;
                dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
                if (dispatch_semaphore_wait(_previewSemaphore, time) != 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideProgressHUD:YES];
                        [self showErrorAlertView];
                        [self updatePreviewSceneByMode:WifiCamPreviewModeCameraOff];
                    });
                    return;
                }
            }
        } else {
            AppLog(@"Don't stop right now.");
        }
        
        
        // Capture
        stillCaptureDoneListener = new StillCaptureDoneListener(self);
        [_ctrl.comCtrl addObserver:ICATCH_EVENT_CAPTURE_COMPLETE
                          listener:stillCaptureDoneListener
                       isCustomize:NO];
        if( [self capableOf:WifiCamAbilityLatestDelayCapture] ){
            [_ctrl.actCtrl triggerCapturePhoto];
            
            // Delay-capture sound effect
            if ([self capableOf:WifiCamAbilityDelayCapture] && delayCaptureCount > 0) {
                NSUInteger edgedCount = delayCaptureCount/2;
                
                BOOL isRush = NO;
                while (delayCaptureCount > 0) {
                    AudioServicesPlaySystemSound(_delayCaptureSound);
                    
                    if (delayCaptureCount > edgedCount && !isRush) {
                        [NSThread sleepForTimeInterval:0.5];AppLog(@"sleep 0.5s");
                    } else {
                        if (!isRush) {
                            delayCaptureCount *= 2;
                        }
                        [NSThread sleepForTimeInterval:0.25];AppLog(@"sleep 0.25s");
                        isRush = YES;
                    }
                    --delayCaptureCount;
                }
                
                AppLog(@"Stop streaming ASAP before camera take a picture.");
                AudioServicesPlaySystemSound(_stillCaptureSound);
                
                if ([self capableOf:WifiCamAbilityLatestDelayCapture] && ![self capableOf:WifiCamAbilityNewCaptureWay]) {
                    AppLog(@"Stop PV");
                    self.PVRun = NO;
                    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 5ull * NSEC_PER_SEC);
                    if (dispatch_semaphore_wait(_previewSemaphore, time) != 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self hideProgressHUD:YES];
                            [self showErrorAlertView];
                            [self updatePreviewSceneByMode:WifiCamPreviewModeCameraOff];
                        });
                    }
                }
            } else if ([self capableOf:WifiCamAbilityBurstNumber] && _burstCaptureCount > 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.burstCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:0.15
                                                                            target  :self
                                                                            selector:@selector(burstCaptureTimerCallback:)
                                                                            userInfo:nil
                                                                            repeats :YES];
                });
            }
        } else // use old capture procedure
            [_ctrl.actCtrl capturePhoto];
        

    });
}
- (void)PhotoCapture {
    if (![self capableOf:WifiCamAbilityBurstNumber] || _burstCaptureCount == 0 || _burstCaptureCount > 0) {
        AudioServicesPlaySystemSound(_stillCaptureSound);
    }
    if (![self capableOf:WifiCamAbilityNewCaptureWay]) {
        AppLog(@"Stop PV");
        self.PVRun = NO;
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if (dispatch_semaphore_wait(_previewSemaphore, time) != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self showErrorAlertView];
                [self updatePreviewSceneByMode:WifiCamPreviewModeCameraOff];
            });
            return;
        }
    }
    
}

- (void)startMovieRec {
    AudioServicesPlaySystemSound(_videoCaptureSound);
    [self showProgressHUDWithMessage:nil];
    AppLog(@"startMovieRec");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateVideoSizeOnScreen:_camera.curVideoSize];
        });
        
        if (![_ctrl.propCtrl checkSDExist]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:NSLocalizedString(@"NoCard", nil)
                                   showTime:1.0];
            });
            return;
        }
        if (_camera.storageSpaceForVideo==0 && [_ctrl.propCtrl connected]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:NSLocalizedString(@"CARD_FULL", nil)
                                   showTime:1.0];
            });
            return;
        }
        
        if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
            AppLog(@"Support to get recorded time!");
            videoRecPostTimeListener = new VideoRecPostTimeListener(self);
            [_ctrl.comCtrl addObserver:(ICatchEventID)0x5001
                              listener:videoRecPostTimeListener
                           isCustomize:YES];
        } else {
            AppLog(@"Don't support to get recorded time.");
        }

        TRACE();
        BOOL ret = [_ctrl.actCtrl startMovieRecord];
        TRACE();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret) {
                [self updatePreviewSceneByMode:WifiCamPreviewModeVideoOn];
                [self addMovieRecListener];
                
                if (![self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
                    if (![_videoCaptureTimer isValid]) {
                        self.videoCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                                target  :self
                                                                                selector:@selector(movieRecordingTimerCallback:)
                                                                                userInfo:nil
                                                                                repeats :YES];
                    }
                }
                [self hideProgressHUD:YES];
                _Recording = YES;
            } else {
                [self showProgressHUDNotice:@"Failed to begin movie recording." showTime:2.0];
                if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
                    [_ctrl.comCtrl removeObserver:(ICatchEventID)0x5001
                                         listener:videoRecPostTimeListener
                                      isCustomize:YES];
                    if (videoRecPostTimeListener) {
                        delete videoRecPostTimeListener;
                        videoRecPostTimeListener = NULL;
                    }
                }
            }
        });
    });
}

- (void)stopMovieRec
{
    AudioServicesPlaySystemSound(_videoCaptureSound);
    [self showProgressHUDWithMessage:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
            [_ctrl.comCtrl removeObserver:(ICatchEventID)0x5001
                                 listener:videoRecPostTimeListener
                              isCustomize:YES];
            if (videoRecPostTimeListener) {
                delete videoRecPostTimeListener;
                videoRecPostTimeListener = NULL;
            }
        }
        TRACE();
        BOOL ret = [_ctrl.actCtrl stopMovieRecord];
        TRACE();
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret) {
                if (!_Living) {
                    [self updatePreviewSceneByMode:WifiCamPreviewModeVideoOff];
                } else {
                    _camera.previewMode = WifiCamPreviewModeVideoOff;
                }
                [self remMovieRecListener];
                if ([_videoCaptureTimer isValid]) {
                    [_videoCaptureTimer invalidate];
                    self.movieRecordElapsedTimeInSeconds = 0;
                }
                [self hideProgressHUD:YES];
                _Recording = NO;
            } else {
                [self showProgressHUDNotice:@"Failed to stop movie recording."
                                   showTime:2.0];
            }
        });
    });
}

- (void)startTimelapseRec {
    AudioServicesPlaySystemSound(_videoCaptureSound);
    [self showProgressHUDWithMessage:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_camera.timelapseType == WifiCamTimelapseTypeStill) {
                [self updateImageSizeOnScreen:_camera.curImageSize];
            } else {
                [self updateVideoSizeOnScreen:_camera.curVideoSize];
            }
        });

        if (![_ctrl.propCtrl checkSDExist]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:NSLocalizedString(@"NoCard", nil)
                                   showTime:1.5];
            });
            
            return;
        }
        if ([_ctrl.propCtrl connected]) {
            if (_camera.timelapseType == WifiCamTimelapseTypeStill && _camera.storageSpaceForImage==0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showProgressHUDNotice:NSLocalizedString(@"CARD_FULL", nil)
                                       showTime:1.0];
                });
                return;
            } else if (_camera.timelapseType == WifiCamTimelapseTypeVideo && _camera.storageSpaceForVideo==0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showProgressHUDNotice:NSLocalizedString(@"CARD_FULL", nil)
                                       showTime:1.0];
                });
                return;
            } else {
                
            }
        }
        
        BOOL ret = [_ctrl.actCtrl startTimelapseRecord];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret) {
                [self updatePreviewSceneByMode:WifiCamPreviewModeTimelapseOn];
                [self addTimelapseRecListener];
                if (![_videoCaptureTimer isValid]) {
                    self.videoCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                            target  :self
                                                                            selector:@selector(movieRecordingTimerCallback:)
                                                                            userInfo:nil
                                                                            repeats :YES];
                }
                [self hideProgressHUD:YES];
            } else {
                [self showProgressHUDNotice:@"Failed to begin time-lapse recording" showTime:2.0];
            }
            
        });
    });
}

- (void)stopTimelapseRec {
    AudioServicesPlaySystemSound(_videoCaptureSound);
    [self showProgressHUDWithMessage:nil];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL ret = [_ctrl.actCtrl stopTimelapseRecord];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret) {
                [self remTimelapseRecListener];
                [self hideProgressHUD:YES];
            } else {
                [self showProgressHUDNotice:@"Failed to stop time-lapse recording" showTime:2.0];
            }
            
            if ([_videoCaptureTimer isValid]) {
                [_videoCaptureTimer invalidate];
                self.movieRecordElapsedTimeInSeconds = 0;
            }
            [self updatePreviewSceneByMode:WifiCamPreviewModeTimelapseOff];
        });
    });
}

- (void)movieRecordingTimerCallback:(NSTimer *)sender {
    UIImage *image = nil;
    
    if (_videoCaptureStopOn) {
        self.videoCaptureStopOn = NO;
        image = _stopOn;
    } else {
        self.videoCaptureStopOn = YES;
        image = _stopOff;
    }
    //if (_movieRecordElapsedTimeInSeconds < _camera.storageSpaceForVideo
    //    || _camera.previewMode == WifiCamPreviewModeTimelapseOn) {
        ++self.movieRecordElapsedTimeInSeconds;
    //}
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.snapButton setImage:image forState:UIControlStateNormal];
    });
    
}


- (void)burstCaptureTimerCallback:(NSTimer *)sender {
    AppLog(@"_burstCaptureCount: %lu", (unsigned long)_burstCaptureCount);
    if (self.burstCaptureCount-- <= 0) {
        [sender invalidate];
    } else {
        AppLog(@"burst capture... %lu", (unsigned long)_burstCaptureCount);
        AudioServicesPlaySystemSound(_burstCaptureSound);
    }
}

- (IBAction)showZoomController:(UITapGestureRecognizer *)sender {
    if ([self capableOf:WifiCamAbilityDateStamp] && _camera.curDateStamp != DATE_STAMP_OFF) {
        return;
    }
    if ([self capableOf:WifiCamAbilityZoom] && _zoomSlider.hidden) {
        [self hideZoomController:NO];
        if (![_hideZoomControllerTimer isValid]) {
            _hideZoomControllerTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                                        target:self
                                                                      selector:@selector(autoHideZoomController)
                                                                      userInfo:nil
                                                                       repeats:NO];
        }
    } else {
        [self hideZoomController:YES];
    }
}

- (void)hideZoomController: (BOOL)value {
    _zoomSlider.hidden = value;
   
}

- (void)autoHideZoomController
{
    [self hideZoomController:YES];
}






- (void)showBusyNotice
{
    NSString *busyInfo = nil;
    
    if (_camera.previewMode == WifiCamPreviewModeCameraOn) {
        busyInfo = @"STREAM_ERROR_CAPTURING";
    } else if (_camera.previewMode == WifiCamPreviewModeVideoOn) {
        busyInfo = @"STREAM_ERROR_RECORDING";
    } else if (_camera.previewMode == WifiCamPreviewModeTimelapseOn) {
        busyInfo = @"STREAM_ERROR_CAPTURING";
    }
    [self showProgressHUDNotice:NSLocalizedString(busyInfo, nil) showTime:2.0];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"goSettingSegue"]) {
        UINavigationController *navVC = [segue destinationViewController];
        SettingViewController *settingVC = (SettingViewController *)navVC.topViewController;
        settingVC.delegate = self;
    }
}

- (IBAction)settingAction:(id)sender {
    TRACE();
    //    dispatch_suspend(_audioQueue);
    //    dispatch_suspend(_videoQueue);
//    if( _camera.previewMode != WifiCamPreviewModeCameraOff &&  _camera.previewMode != WifiCamPreviewModeCameraOn)
//    [self stopYoutubeLive];
        self.PVRun = NO;
    self.readyGoToSetting = YES;
    [self performSegueWithIdentifier:@"goSettingSegue" sender:sender];
}

-(void)goHome {
    TRACE();
    self.readyGoToSetting = NO;
    //    dispatch_resume(_audioQueue);
    //    dispatch_resume(_videoQueue);
}

- (IBAction)mpbAction:(id)sender
{
    [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (![_ctrl.propCtrl checkSDExist]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:NSLocalizedString(@"NoCard", nil) showTime:2.0];
            });
            return;
        }
        
//        [self stopYoutubeLive];
        self.PVRun = NO;
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if ((dispatch_semaphore_wait(_previewSemaphore, time) != 0)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self showErrorAlertView];
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                dispatch_semaphore_signal(_previewSemaphore);
                [self hideProgressHUD:YES];
                [self performSegueWithIdentifier:@"goMpbSegue" sender:sender];
                
            });
        }
    });
}

- (IBAction)changeToCameraState:(id)sender {
    
    if (_camera.previewMode == WifiCamPreviewModeCameraOff) {
        return;
    }
    [self showProgressHUDWithMessage:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AudioServicesPlaySystemSound(_changeModeSound);
        _camera.previewMode = WifiCamPreviewModeCameraOff;
        [self ChangePreviewMode:ICATCH_VIDEO_PREVIEW_MODE];
        
    });
    /*dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AudioServicesPlaySystemSound(_changeModeSound);
//        [self stopYoutubeLive];
        self.PVRun = NO;
        _camera.previewMode = WifiCamPreviewModeCameraOff;
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if (dispatch_semaphore_wait(_previewSemaphore, time) != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self showErrorAlertView];
            });
        } else {
            dispatch_semaphore_signal(_previewSemaphore);
            self.PVRun = YES;
            [self ChangePreviewMode:ICATCH_VIDEO_PREVIEW_MODE];
        }
    });*/
}

- (IBAction)changeToVideoState:(id)sender {
    if (_camera.previewMode == WifiCamPreviewModeVideoOff) {
        return;
    }
    
    [self showProgressHUDWithMessage:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AudioServicesPlaySystemSound(_changeModeSound);
        _camera.previewMode = WifiCamPreviewModeVideoOff;
            [self ChangePreviewMode:ICATCH_VIDEO_PREVIEW_MODE];
        
    });
}

- (IBAction)changeToTimelapseState:(UIButton *)sender {
    if (_camera.previewMode == WifiCamPreviewModeTimelapseOff) {
        return;
    }
    
    [self showProgressHUDWithMessage:nil];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AudioServicesPlaySystemSound(_changeModeSound);
//        [self stopYoutubeLive];
        self.PVRun = NO;
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if (dispatch_semaphore_wait(_previewSemaphore, time) != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self showErrorAlertView];
            });
        } else {
            dispatch_semaphore_signal(_previewSemaphore);
            self.PVRun = YES;
            _camera.previewMode = WifiCamPreviewModeTimelapseOff;
            if (_camera.timelapseType == WifiCamTimelapseTypeVideo) {
                [self runPreview:ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE];
            } else {
                [self runPreview:ICATCH_TIMELAPSE_STILL_PREVIEW_MODE];
            }
        }
    });
    
}

- (void)setButtonEnable:(BOOL)value
{
    self.snapButton.enabled = value;
    self.mpbToggle.enabled = value;
    self.settingButton.enabled = value;
    self.cameraToggle.enabled = value;
    self.videoToggle.enabled = value;
    self.timelapseToggle.enabled = value;
    self.sizeButton.enabled = value;
    self.ImageQualityButton.enabled = value;
   
}





- (void)didReceiveMemoryWarning
{
    AppLog(@"ReceiveMemoryWarning");
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations.
    return interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)showErrorAlertView
{
    AppLog(@"Timeout");
    self.normalAlert = [[UIAlertView alloc] initWithTitle:nil
                                       message           :NSLocalizedString(@"ActionTimeOut.", nil)
                                       delegate          :self
                                       cancelButtonTitle :NSLocalizedString(@"Sure"/*@"Exit"*/, nil)
                                       otherButtonTitles :nil, nil];
    _normalAlert.tag = APP_RECONNECT_ALERT_TAG;
    [_normalAlert show];
}


- (void)addMovieRecListener
{
    videoRecOffListener = new VideoRecOffListener(self);
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_VIDEO_OFF
                      listener:videoRecOffListener isCustomize:NO];
    sdCardFullListener = new SDCardFullListener(self);
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_SDCARD_FULL
                      listener:sdCardFullListener isCustomize:NO];
    
    
    if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
        [self addObserver:self forKeyPath:@"movieRecordElapsedTimeInSeconds"
                  options:NSKeyValueObservingOptionNew context:nil];
    }
}

- (void)remMovieRecListener
{
    [_ctrl.comCtrl removeObserver:ICATCH_EVENT_VIDEO_OFF
                         listener:videoRecOffListener
                      isCustomize:NO];
    if (videoRecOffListener) {
        delete videoRecOffListener;
        videoRecOffListener = NULL;
    }
    [_ctrl.comCtrl removeObserver:ICATCH_EVENT_SDCARD_FULL
                         listener:sdCardFullListener isCustomize:NO];
    if (sdCardFullListener) {
        delete sdCardFullListener;
        sdCardFullListener = NULL;
    }
    
    if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
        if( [self observationInfo]){
            @try{
                [self removeObserver:self forKeyPath:@"movieRecordElapsedTimeInSeconds"];
            }@catch (NSException *exception) {}
        }
        //[self removeObserver:self forKeyPath:@"movieRecordElapsedTimeInSeconds"];
    }
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"movieRecordElapsedTimeInSeconds"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSUInteger sec = [[change objectForKey:NSKeyValueChangeNewKey] unsignedIntegerValue];
            self.movieRecordTimerLabel.text = [Tool translateSecsToString:sec];
        });
    }
}

- (void)addTimelapseRecListener
{
    timelapseStopListener = new TimelapseStopListener(self);
    timelapseCaptureStartedListener = new TimelapseCaptureStartedListener(self);
    timelapseCaptureCompleteListener = new TimelapseCaptureCompleteListener(self);
    sdCardFullListener = new SDCardFullListener(self);
    
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_TIMELAPSE_STOP
                      listener:timelapseStopListener isCustomize:NO];
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_CAPTURE_START
                      listener:timelapseCaptureStartedListener isCustomize:NO];
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_CAPTURE_COMPLETE
                      listener:timelapseCaptureCompleteListener isCustomize:NO];
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_SDCARD_FULL
                      listener:sdCardFullListener isCustomize:NO];
    if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
        [self addObserver:self forKeyPath:@"movieRecordElapsedTimeInSeconds"
                  options:NSKeyValueObservingOptionNew context:nil];
        
    }
}

- (void)remTimelapseRecListener
{
    [_ctrl.comCtrl removeObserver:ICATCH_EVENT_TIMELAPSE_STOP
                         listener:timelapseStopListener isCustomize:NO];
    [_ctrl.comCtrl removeObserver:ICATCH_EVENT_CAPTURE_START
                         listener:timelapseCaptureStartedListener isCustomize:NO];
    [_ctrl.comCtrl removeObserver:ICATCH_EVENT_CAPTURE_COMPLETE
                         listener:timelapseCaptureCompleteListener isCustomize:NO];
    [_ctrl.comCtrl removeObserver:ICATCH_EVENT_SDCARD_FULL
                         listener:sdCardFullListener isCustomize:NO];
    
    if (timelapseStopListener) {
        delete timelapseStopListener; timelapseStopListener = NULL;
    }
    if (timelapseCaptureStartedListener) {
        delete timelapseCaptureStartedListener; timelapseCaptureStartedListener = NULL;
    }
    if (timelapseCaptureCompleteListener) {
        delete timelapseCaptureCompleteListener; timelapseCaptureCompleteListener = NULL;
    }
    if (sdCardFullListener) {
        delete sdCardFullListener; sdCardFullListener = NULL;
    }
    if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
        if( [self observationInfo]){
            @try{
                [self removeObserver:self forKeyPath:@"movieRecordElapsedTimeInSeconds"];
            }@catch (NSException *exception) {}
        }
        //[self removeObserver:self forKeyPath:@"movieRecordElapsedTimeInSeconds"];
    }
}

- (IBAction)returnBackToHome:(id)sender {
    
    [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)];
    [self stopYoutubeLive];
    self.PVRun = NO;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if ((dispatch_semaphore_wait(_previewSemaphore, time) != 0)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self showErrorAlertView];
            });
            return;
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                dispatch_semaphore_signal(_previewSemaphore);
                [self hideProgressHUD:YES];
                //[self.navigationController popToRootViewControllerAnimated:YES];
                [self.view.window.rootViewController dismissViewControllerAnimated:YES completion: ^{
                    [[SDK instance] destroySDK];
                }];
//                [self dismissViewControllerAnimated:YES completion:^{
//                    [[SDK instance] destroySDK];
//                }];
            });
        }
    });
}

- (void)selectDelayCaptureTimeAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row != _tbDelayCaptureTimeArray.lastIndex) {
        
        [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            _tbDelayCaptureTimeArray.lastIndex = indexPath.row;
            
            unsigned int curCaptureDelay = [_ctrl.propCtrl parseDelayCaptureInArray:indexPath.row];
            /*
             if (curCaptureDelay != CAP_DELAY_NO) {
             // Disable burst capture
             _camera.curBurstNumber = BURST_NUMBER_OFF;
             [_ctrl.propCtrl changeBurstNumber:BURST_NUMBER_OFF];
             }
             */
            
            [_ctrl.propCtrl changeDelayedCaptureTime:curCaptureDelay];
            //_camera.curCaptureDelay = curCaptureDelay;
            
            // Re-Get
            //_camera.curBurstNumber = [_ctrl.propCtrl retrieveBurstNumber];
            //_camera.curTimelapseInterval = [_ctrl.propCtrl retrieveCurrentTimelapseInterval];
            [_ctrl.propCtrl updateAllProperty:_camera];
            
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self updateBurstCaptureIcon:_camera.curBurstNumber];
                
            });
            
        });
    }
}

- (void)selectImageSizeAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row != _tbPhotoSizeArray.lastIndex) {
        
        //self.PVRun = NO;
        [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            /*
             dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
             if ((dispatch_semaphore_wait(_previewSemaphore, time) != 0)) {
             dispatch_async(dispatch_get_main_queue(), ^{
             [self hideProgressHUD:YES];
             [self showErrorAlertView];
             });
             
             } else {
             */
            
            _tbPhotoSizeArray.lastIndex = indexPath.row;
            string curImageSize = [_ctrl.propCtrl parseImageSizeInArray:indexPath.row];
            
            [_ctrl.propCtrl changeImageSize:curImageSize];
            //_camera.curImageSize = curImageSize;
            
            [_ctrl.propCtrl updateAllProperty:_camera];
            
            //dispatch_semaphore_signal(_previewSemaphore);
            //self.PVRun = YES;
            //[self runPreview:ICATCH_STILL_PREVIEW_MODE];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self updateImageSizeOnScreen:curImageSize];
                
            });
            //}
        });
        
        
        /*
         _tbPhotoSizeArray.lastIndex = indexPath.row;
         
         string curImageSize = [_ctrl.propCtrl parseImageSizeInArray:indexPath.row];
         _camera.curImageSize = curImageSize;
         [_ctrl.propCtrl changeImageSize:curImageSize];
         [self updateImageSizeOnScreen:curImageSize];
         */
    }
}

- (void)selectVideoSizeAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row != _tbVideoSizeArray.lastIndex) {
        [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            if ([_ctrl.propCtrl isSupportMethod2ChangeVideoSize]) {
                AppLog(@"New Method");
                self.PVRun = NO;
                
                dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
                if ((dispatch_semaphore_wait(_previewSemaphore, time) != 0)) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideProgressHUD:YES];
                        [self showErrorAlertView];
                    });
                    
                } else {
                    _tbVideoSizeArray.lastIndex = indexPath.row;
                    string curVideoSize = "";
                    if( _camera.previewMode == WifiCamPreviewModeTimelapseOff || _camera.previewMode == WifiCamPreviewModeTimelapseOn)
                        curVideoSize = [_ctrl.propCtrl parseTimeLapseVideoSizeInArray:indexPath.row];
                    else
                        curVideoSize = [_ctrl.propCtrl parseVideoSizeInArray:indexPath.row];
                    //string curVideoSize = [_ctrl.propCtrl parseVideoSizeInArray:indexPath.row];
                    
                    
                    [_ctrl.propCtrl changeVideoSize:curVideoSize];
                    [_ctrl.propCtrl updateAllProperty:_camera];
                    
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        _noPreviewLabel.hidden = YES;
                        [self updateVideoSizeOnScreen:curVideoSize];
                        //                        [self hideProgressHUD:YES];
                        _preview.userInteractionEnabled = YES;
#ifdef HW_DECODE_H264
                        _h264View.userInteractionEnabled = YES;
#endif
                    });
                    
                    
                    // Is support Slow-Motion under this video size?
                    // Update the Slow-Motion icon
                    if ([self capableOf:WifiCamAbilitySlowMotion]
                        && _camera.previewMode == WifiCamPreviewModeVideoOff) {
                        
                        _camera.curSlowMotion = [_ctrl.propCtrl retrieveCurrentSlowMotion];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            if (_camera.curSlowMotion == 1) {
                                self.slowMotionStateImageView.hidden = NO;
                            } else {
                                self.slowMotionStateImageView.hidden = YES;
                            }
                        });
                    }
                    
                    self.PVRun = YES;
                    dispatch_semaphore_signal(_previewSemaphore);
                    
                    if( _camera.previewMode == WifiCamPreviewModeTimelapseOff || _camera.previewMode == WifiCamPreviewModeTimelapseOn){
                        if (_camera.timelapseType == WifiCamTimelapseTypeVideo) {
                            if( [_ctrl.propCtrl changeTimelapseType:ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE] == WCRetSuccess)
                                AppLog(@"change to ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE success");
                            [self runPreview:ICATCH_TIMELAPSE_VIDEO_PREVIEW_MODE];
                        } else {
                            if( [_ctrl.propCtrl changeTimelapseType:ICATCH_TIMELAPSE_STILL_PREVIEW_MODE]== WCRetSuccess)
                                AppLog(@"change to ICATCH_TIMELAPSE_STILL_PREVIEW_MODE success");
                            [self runPreview:ICATCH_TIMELAPSE_STILL_PREVIEW_MODE];
                        }
                    }
                    else
                        [self runPreview:ICATCH_VIDEO_PREVIEW_MODE];
                    
                }
            } else {
                AppLog(@"Old Method");
                
                _tbVideoSizeArray.lastIndex = indexPath.row;
                string curVideoSize;
                if( _camera.previewMode == WifiCamPreviewModeTimelapseOff || _camera.previewMode == WifiCamPreviewModeTimelapseOn)
                    curVideoSize = [_ctrl.propCtrl parseTimeLapseVideoSizeInArray:indexPath.row];
                else
                    curVideoSize = [_ctrl.propCtrl parseVideoSizeInArray:indexPath.row];
                
                [_ctrl.propCtrl changeVideoSize:curVideoSize];
                [_ctrl.propCtrl updateAllProperty:_camera];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self hideProgressHUD:YES];
                    [self updateVideoSizeOnScreen:curVideoSize];
                });
            }
            
        });
        
    }
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                        duration:(NSTimeInterval)duration {
    
    if (!_avslayer.hidden) {
        self.avslayer.bounds = _preview.bounds;
        self.avslayer.position = CGPointMake(CGRectGetMidX(_preview.bounds), CGRectGetMidY(_preview.bounds));
        [self showLiveGUIIfNeeded:_camera.previewMode];
    }
    
    CGFloat y = -15;
    if (_notificationView.isShowing) {
        y = 15;
    }
    _notificationView.center = CGPointMake(self.view.bounds.size.width / 2, y);

    /*
    switch (toInterfaceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            AppLog(@"rotate to left/right");
            //            self.navigationController.navigationBarHidden = YES;
            //            self.preview.contentMode = UIViewContentModeScaleAspectFill;
            
            break;
            
        default:
            AppLog(@"rotate to portrait");
            //            self.navigationController.navigationBarHidden = NO;
            //            self.preview.contentMode = UIViewContentModeScaleAspectFit;
            break;
    }
    */
}

//-(BOOL)prefersStatusBarHidden {
//    if (self.view.frame.size.width < self.view.frame.size.height) {
//        return NO;
//    } else {
//        return YES;
//    }
//}

-(void)removeObservers {
    
    if ([self capableOf:WifiCamAbilityMovieRecord] && videoRecOnListener) {
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_VIDEO_ON
                             listener:videoRecOnListener
                          isCustomize:NO];
        delete videoRecOnListener;
        videoRecOnListener = NULL;
    }
    
    if (_camera.enableAutoDownload && fileDownloadListener) {
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_FILE_DOWNLOAD
                             listener:fileDownloadListener
                          isCustomize:NO];
        delete fileDownloadListener;
        fileDownloadListener = NULL;
    }
}

#pragma mark - ICatchWificamListener

- (void)updateMovieRecState:(MovieRecState)state
{
    if (state == MovieRecStoped) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //            [self remMovieRecListener];
            [_ctrl.comCtrl removeObserver:ICATCH_EVENT_VIDEO_OFF
                                 listener:videoRecOffListener
                              isCustomize:NO];
            if (videoRecOffListener) {
                delete videoRecOffListener;
                videoRecOffListener = NULL;
            }
            
            if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
                if( [self observationInfo]){
                    @try{
                        [self removeObserver:self forKeyPath:@"movieRecordElapsedTimeInSeconds"];
                    }@catch (NSException *exception) {}
                }
                //[self removeObserver:self forKeyPath:@"movieRecordElapsedTimeInSeconds"];
            }
            // Mark by Allen.Chuang 2015.1.28 ICOM-2754 , camera will stop record by itself.
            //[_ctrl.actCtrl stopMovieRecord];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updatePreviewSceneByMode:WifiCamPreviewModeVideoOff];
                
                if ([_videoCaptureTimer isValid]) {
                    [_videoCaptureTimer invalidate];
                    self.movieRecordElapsedTimeInSeconds = 0;
                }
            });
        });
    } else if (state == MovieRecStarted) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [_ctrl.actCtrl startMovieRecord];
            [self addMovieRecListener];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updatePreviewSceneByMode:WifiCamPreviewModeVideoOn];
                
                if (![_videoCaptureTimer isValid]) {
                    self.videoCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                            target  :self
                                                                            selector:@selector(movieRecordingTimerCallback:)
                                                                            userInfo:nil
                                                                            repeats :YES];
                }
            });
            
        });
    }
}


- (void)stopStillCapture
{
    TRACE();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_CAPTURE_COMPLETE
                             listener:stillCaptureDoneListener
                          isCustomize:NO];
        if (stillCaptureDoneListener) {
            delete stillCaptureDoneListener;
            stillCaptureDoneListener = NULL;
        }
        if( ! [self capableOf:WifiCamAbilityLatestDelayCapture] ){
            AppLog(@"wait 1 second");
            [NSThread sleepForTimeInterval:1]; // old method must slow start media stream
        }
        _camera.previewMode = WifiCamPreviewModeCameraOff;
        
        if (![self capableOf:WifiCamAbilityNewCaptureWay]) {
            dispatch_semaphore_signal(_previewSemaphore);
            self.PVRun = YES;
            [self runPreview:ICATCH_STILL_PREVIEW_MODE];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self updatePreviewSceneByMode:_camera.previewMode];
            });
        }
    });
}

- (void)stopTimelapse
{
    ICatchCameraMode mode = [[SDK instance] retrieveCurrentCameraMode];
    
    BOOL ret = NO;
    if (mode == MODE_TIMELAPSE_STILL || mode == MODE_TIMELAPSE_VIDEO) {
        AppLog(@"got event and call stopTimelapseRecord again.");
        ret = [_ctrl.actCtrl stopTimelapseRecord];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (ret) {
            [self remTimelapseRecListener];
        }
        
        if ([_videoCaptureTimer isValid]) {
            [_videoCaptureTimer invalidate];
            self.movieRecordElapsedTimeInSeconds = 0;
        }
        [self updatePreviewSceneByMode:WifiCamPreviewModeTimelapseOff];
    });
}

- (void)timelapseStartedNotice {
    AudioServicesPlaySystemSound(_burstCaptureSound);
}

- (void)timelapseCompletedNotice
{
    
    /*
     dispatch_async(dispatch_get_main_queue(), ^{
     [self showProgressHUDCompleteMessage:NSLocalizedString(@"Done", nil)];
     });
     */
}

- (void)postMovieRecordTime
{
    TRACE();
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![_videoCaptureTimer isValid]) {
            self.videoCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                    target  :self
                                                                    selector:@selector(movieRecordingTimerCallback:)
                                                                    userInfo:nil
                                                                    repeats :YES];
        }
        
        [self hideProgressHUD:YES];
    });
    
    
}

- (void)postMovieRecordFileAddedEvent
{
    self.movieRecordElapsedTimeInSeconds = 0;
}

- (void)postFileDownloadEvent:(ICatchFile *)file {
    TRACE();
    printf("filePath: %s\n", file->getFilePath().c_str());
    printf("fileName: %s\n", file->getFileName().c_str());
    printf("fileDate: %s\n", file->getFileDate().c_str());
    printf("fileType: %d\n", file->getFileType());
    printf("fileSize: %llu\n", file->getFileSize());
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDWithMessage:nil];
    });
    
    ICatchFile *f = new ICatchFile(file->getFileHandle(), file->getFileType(), file->getFilePath(), file->getFileSize());
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_ctrl.fileCtrl downloadFile:f];
        UIImage *image = [_ctrl.actCtrl getAutoDownloadImage];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.autoDownloadThumbImage.image = image;
            self.autoDownloadThumbImage.hidden = NO;
            [self hideProgressHUD:YES];
        });
        
        delete f;
    });
}

-(void)sdFull {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_SDCARD_FULL
                             listener:sdCardFullListener isCustomize:NO];
        if (sdCardFullListener) {
            delete sdCardFullListener;
            sdCardFullListener = NULL;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showProgressHUDNotice:NSLocalizedString(@"CARD_FULL", nil)
                               showTime:1.5];
            
        });
    });
}

#pragma mark - WifiCamSDKEventListener
-(void)streamCloseCallback {
    AppLog(@"streamCloseCallback");
    [self stopYoutubeLive];
    self.PVRun = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDNotice:@"Streaming is stopped unexpected." showTime:2.0];
    });
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return _alertTableArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                   reuseIdentifier:nil];
    [cell.textLabel setText:[_alertTableArray objectAtIndex:indexPath.row]];
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (_curSettingState) {
        case SETTING_DELAY_CAPTURE:
            [self selectDelayCaptureTimeAtIndexPath:indexPath];
            break;
            
        case SETTING_STILL_CAPTURE:
            [self selectImageSizeAtIndexPath:indexPath];
            break;
            
        case SETTING_VIDEO_CAPTURE:
            [self selectVideoSizeAtIndexPath:indexPath];
            break;
            
        default:
            break;
    }
    
    [_customIOS7AlertView close];
}

- (void)tableView         :(UITableView *)tableView
        willDisplayCell   :(UITableViewCell *)cell
        forRowAtIndexPath :(NSIndexPath *)indexPath
{
    NSInteger lastIndex = 0;
    
    switch (_curSettingState) {
        case SETTING_DELAY_CAPTURE:
            lastIndex = _tbDelayCaptureTimeArray.lastIndex;
            break;
            
        case SETTING_STILL_CAPTURE:
            lastIndex = _tbPhotoSizeArray.lastIndex;
            break;
            
        case SETTING_VIDEO_CAPTURE:
            lastIndex = _tbVideoSizeArray.lastIndex;
            break;
            
        default:
            break;
    }
    
    if (indexPath.row == lastIndex) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag) {
        case APP_RECONNECT_ALERT_TAG:
            [self dismissViewControllerAnimated:YES completion:^{}];
            //exit(0);
            break;
    
        default:
            break;
    }
}


#pragma mark - AppDelegateProtocol
-(void)cleanContext {
    [self removeObservers];
    [self stopYoutubeLive];
    self.PVRun = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{

        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if ((dispatch_semaphore_wait(_previewSemaphore, time) != 0)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self showErrorAlertView];
            });
            
        } else {
            dispatch_async([[SDK instance] sdkQueue], ^{
                dispatch_semaphore_signal(_previewSemaphore);
                TRACE();
                if ([[SDK instance] isConnected]) {
                    return;
                } else {
                    [[SDK instance] destroySDK];
                }
            });
        }
    });
}

-(void)applicationDidEnterBackground:(UIApplication *)application {
    AppLog("enter background");
    [self removeObservers];
    [self stopYoutubeLive];
    self.PVRun = NO;
    self.isEnterBackground = YES;
    /*
    dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if ((dispatch_semaphore_wait(_previewSemaphore, time) != 0)) {
            AppLog(@"Timeout!");
        } else {
            dispatch_async([[SDK instance] sdkQueue], ^{
                AppLog(@"semaphore_signal");
                dispatch_semaphore_signal(_previewSemaphore);
                [[SDK instance] destroySDK];
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgressHUD:YES];
        });
    });
     */
    //[NSThread sleepForTimeInterval:0.5];
    [[SDK instance] destroySDK];
    /*
    dispatch_async([[SDK instance] sdkQueue], ^{
        AppLog(@"semaphore_signal");
        dispatch_semaphore_signal(_previewSemaphore);
        [[SDK instance] destroySDK];
    });*/
}

-(NSString *)notifyConnectionBroken {
    switch(_camera.previewMode) {
        case WifiCamPreviewModeVideoOn: {
            if ([self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
                [_ctrl.comCtrl removeObserver:(ICatchEventID)0x5001
                                     listener:videoRecPostTimeListener
                                  isCustomize:YES];
                if (videoRecPostTimeListener) {
                    delete videoRecPostTimeListener;
                    videoRecPostTimeListener = NULL;
                }
            }
            [self remMovieRecListener];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([_videoCaptureTimer isValid]) {
                    [_videoCaptureTimer invalidate];
                    self.movieRecordElapsedTimeInSeconds = 0;
                }
                [self updatePreviewSceneByMode:WifiCamPreviewModeVideoOff];
            });
        }
            break;
        case WifiCamPreviewModeTimelapseOn: {
            [self remTimelapseRecListener];
            dispatch_async(dispatch_get_main_queue(), ^{
                if ([_videoCaptureTimer isValid]) {
                    [_videoCaptureTimer invalidate];
                    self.movieRecordElapsedTimeInSeconds = 0;
                }
                [self updatePreviewSceneByMode:WifiCamPreviewModeTimelapseOff];
            });
        }
            
            break;
        default:
            break;
    }
    
    [self cleanContext];
    return self.savedCamera.wifi_ssid;
}

- (void)sdcardRemoveCallback
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDNotice:NSLocalizedString(@"CARD_REMOVED", nil) showTime:2.0];
    });
}

- (IBAction)liveSwitchClink:(id)sender {
    if (!_liveQueue) {
        _liveQueue = dispatch_queue_create("WifiCam.GCD.Queue.YoutubeLive", DISPATCH_QUEUE_SERIAL);
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UISwitch *live = (UISwitch *)sender;
        
        if ([live isOn]) {
            if (_Living) {
                return;
            }
            AppLogDebug(AppLogTagAPP, @"start Live ...");
            
            ICatchVideoFormat format = [_ctrl.propCtrl retrieveVideoFormat];
            if (format.getCodec() == ICATCH_CODEC_H264) {
                
                NSString *liveBroadcast = [[NSUserDefaults standardUserDefaults] stringForKey:@"PreferenceSpecifier:LiveBroadcast"];
                AppLogDebug(AppLogTagAPP, @"LiveBroadcast: %@", liveBroadcast);
                
                if ([liveBroadcast isEqualToString:@"立即直播"]) {
                    [self startYoutubeLive];
                } else {
                    if (_authorization) {
                        [self createLiveBroadCast];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            _Living = YES;
                            [self setToVideoOnScene];
                        });
                    } else {
                        SignInViewController *masterViewController = [[SignInViewController alloc] initWithNibName:@"SignInViewController" bundle:nil];
                        
                        UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:masterViewController];
                        nc.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            _Living = YES;
                            [self setToVideoOnScene];
                            [self presentViewController:nc animated:YES completion:nil];
                        });
                        
//                            [self.navigationController pushViewController:masterViewController animated:YES];
//                            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                                [self presentViewController:masterViewController animated:YES completion:^{
//                                    _Living = YES;
//                                }];
//                            });
                    }
                }
            } else {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Warning", nil) message:NSLocalizedString(@"LIVE_STREAM_FORMAT", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"Sure", nil) otherButtonTitles:nil, nil];
                [alert show];
                _liveSwitch.on = NO;
            }
        } else {
            if (!_Living) {
                return;
            }
            AppLogDebug(AppLogTagAPP, @"stop  Live ...");
            [self stopYoutubeLive];
        }
    });
}

- (void)startYoutubeLive:(NSString *)postUrl
{
    //1.获取授权，成功后得到credential
    //2.利用credential创建Live频道，成功后得到推流addr
    //  share...
    //3.开始推流
    dispatch_async(_liveQueue/*dispatch_queue_create("WifiCam.GCD.Queue.YoutubeLive", DISPATCH_QUEUE_SERIAL)*/, ^{
        int ret = [[SDK instance] startPublishStreaming:[postUrl UTF8String]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (ret != ICH_SUCCEED) {
                _Living = NO;
                
                [[SDK instance] stopPublishStreaming];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Tips", nil) message:NSLocalizedString(@"LIVE_FAILED", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"Sure", nil) otherButtonTitles:nil, nil];
                [alert show];
            }
        });
    });
}

- (void)startYoutubeLive
{
    //1.获取授权，成功后得到credential
    //2.利用credential创建Live频道，成功后得到推流addr
    //  share...
    //3.开始推流
    [self showProgressHUDWithMessage:NSLocalizedString(@"Start Live", nil)];

    dispatch_async(_liveQueue/*dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)*/, ^{
        int ret = [[SDK instance] startPublishStreaming:[[[NSUserDefaults standardUserDefaults] stringForKey:@"RTMPURL"] UTF8String]];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideProgressHUD:YES];
            
            if (ret != ICH_SUCCEED) {
                [[SDK instance] stopPublishStreaming];
                _liveSwitch.on = NO;
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Tips", nil) message:NSLocalizedString(@"LIVE_FAILED", nil) delegate:self cancelButtonTitle:NSLocalizedString(@"Sure", nil) otherButtonTitles:nil, nil];
                [alert show];
            } else {
                _Living = YES;
                [self setToVideoOnScene];
            }
        });
    });
    
    //4.开始直播，成功后得到Share addr
    //5.将Share addr生成二维码
    
//    "rtmp://a.rtmp.youtube.com/live2/7m5m-wuhz-ryaq-89ss"
//    dispatch_async(dispatch_queue_create("WifiCam.GCD.Queue.getQRCodebyUrl", DISPATCH_QUEUE_SERIAL), ^{
//        UIImage *urlImage = [self getQRCodebyUrl:@"http://www.baidu.com"];
//        if (urlImage) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                _autoDownloadThumbImage.image = urlImage;
//                _autoDownloadThumbImage.hidden = NO;
//            });
//        }
//    });
}

- (void)stopYoutubeLive
{
    //1.停止推流
    //2.停止直播
    if (_Living) {
        [self showProgressHUDWithMessage:NSLocalizedString(@"Stop Live", nil)];
        
        dispatch_async(_liveQueue/*dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)*/, ^{
            _liveSwitch.on = NO;
            int ret = [[SDK instance] stopPublishStreaming];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                _autoDownloadThumbImage.image = nil;
                _autoDownloadThumbImage.hidden = YES;
                _Living = NO;
                
                if (!_Recording) {
                    [self setToVideoOffScene];
                }

                if (ret != ICH_SUCCEED) {
                    [[SDK instance] stopPublishStreaming];
                }
            });
        });
    }
}

- (void)showShareUrlQRCode:(NSString *)url
{
    dispatch_async(dispatch_queue_create("WifiCam.GCD.Queue.getQRCodebyUrl", DISPATCH_QUEUE_SERIAL), ^{
        UIImage *urlImage = [self getQRCodebyUrl:url];
        if (urlImage) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                _autoDownloadThumbImage.image = urlImage;
                _autoDownloadThumbImage.hidden = NO;
            });
        }
    });
}

- (void)liveFailedUpdateGUI
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self hideProgressHUD:YES];
        _autoDownloadThumbImage.image = nil;
        _autoDownloadThumbImage.hidden = YES;
        _Living = NO;
        _liveSwitch.on = NO;
    });
}

- (void)liveErrorHandle:(NSInteger)obj andMessage:(id)mes
{
    NSString *title = nil;
    NSString *message = nil;

    switch (obj) {
        case LiveErrorCreateLiveBroadCast:
            title = NSLocalizedString(@"CreateLiveBroadCastFailed", nil);
            break;
          
        case LiveErrorCreateStreamingChannel:
            title = NSLocalizedString(@"CreateStreamingChannelFailed", nil);
            break;
            
        case LiveErrorBind:
            title = NSLocalizedString(@"BindFailed", nil);
            break;
            
        case LiveErrorCheckoutLiveBroadCastStatus:
            title = NSLocalizedString(@"CheckoutLiveBroadCastStatusFailed", nil);
            break;
            
        case LiveErrorTransitionLiveBroadCastStatus_1:
            title = NSLocalizedString(@"ActivetoTestingFailed", nil);
            break;
            
        case LiveErrorTransitionLiveBroadCastStatus_2:
            title = NSLocalizedString(@"TestingtoLiveFailed", nil);
            break;
            
        case LiveErrorGetLiveBroadcastStauts:
            title = NSLocalizedString(@"GetLiveBroadcastStautsFailed", nil);
            break;
        default:
            title = NSLocalizedString(@"LIVE_FAILED", nil);
            break;
    }
    
    [self liveFailedUpdateGUI];
    if ([mes isKindOfClass:[NSError class]]) {
        message = [NSString stringWithFormat:@"%@", mes];
    } else {
        message = mes;
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:NSLocalizedString(@"Sure", nil) otherButtonTitles:nil, nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        [alert show];
    });
}

- (UIImage *)getQRCodebyUrl:(NSString *)url
{
    // 1.实例化二维码滤镜
    CIFilter *filter = [CIFilter filterWithName:@"CIQRCodeGenerator"];
    
    // 2.恢复滤镜的默认属性 (因为滤镜有可能保存上一次的属性)
    [filter setDefaults];
    
    // 3.将字符串转换成NSdata @"http://www.baidu.com"
    NSData *data  = [url dataUsingEncoding:NSUTF8StringEncoding];
    
    // 4.通过KVO设置滤镜, 传入data, 将来滤镜就知道要通过传入的数据生成二维码
    [filter setValue:data forKey:@"inputMessage"];
    
    // 5.生成二维码
    CIImage *outputImage = [filter outputImage];
    
    return [UIImage  imageWithCIImage:outputImage];
}

#pragma mark - createLiveBroadCast

- (void)createLiveBroadCast
{
    [self showProgressHUDWithMessage:NSLocalizedString(@"Start Live", nil)];

    NSDate *date = [NSDate date];
    AppLogDebug(AppLogTagAPP, @"date ----> %@", date);
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    [dateFormatter setTimeZone:GTMzone];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.000'Z'"];
    
    NSString *actualStartTime = [dateFormatter stringFromDate:date];
    AppLogDebug(AppLogTagAPP, @"actualStartTime ----> %@", actualStartTime);
    
    NSString *liveDuration = [[NSUserDefaults standardUserDefaults] stringForKey:@"LiveDuration"];
    AppLogDebug(AppLogTagAPP, @"liveDuration: %@", liveDuration);
    AppLogDebug(AppLogTagAPP, @"livePostTimeoutInterval: %f", [[[NSUserDefaults standardUserDefaults] stringForKey:@"LivePostTimeoutInterval"] doubleValue]);
    
    NSString *scheduledEndTime = [dateFormatter stringFromDate:[date initWithTimeIntervalSinceNow:[liveDuration integerValue] * 60 * 60]];
    AppLogDebug(AppLogTagAPP, @"scheduledEndTime ----> %@", scheduledEndTime);
    
    NSDictionary *headers = @{ @"content-type": @"application/json",
                               @"authorization": [@"Bearer " stringByAppendingString:_authorization],
                               @"cache-control": @"no-cache",
                               @"postman-token": @"2be6f4af-116b-51bf-6f22-9c6fa390c18d" };
    NSDictionary *parameters = @{ @"snippet": @{ @"title": @"TestLiveCode",
                                                 @"actualStartTime": actualStartTime,
                                                 @"scheduledStartTime": actualStartTime,
                                                 @"scheduledEndTime": scheduledEndTime },
                                  @"status": @{ @"privacyStatus": @"public" },
                                  @"contentDetails": @{ @"projection": @"rectangular",
                                                        @"enableLowLatency": @YES } };
    
    NSData *postData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.googleapis.com/youtube/v3/liveBroadcasts?part=id%2Csnippet%2Cstatus%2CcontentDetails"]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:TimeInterval];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    [request setHTTPBody:postData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        AppLogInfo(AppLogTagAPP, @"%@", error);
                                                        [self liveErrorHandle:LiveErrorCreateLiveBroadCast andMessage:error];
                                                        return;
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        AppLogInfo(AppLogTagAPP, @"%@", httpResponse);
                                                        AppLogDebug(AppLogTagAPP, @"createLiveBroadCast ---> \n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                        
                                                        NSDictionary *myDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                                                        NSString *broadcastId = [myDictionary objectForKey:@"id"];
                                                        AppLogDebug(AppLogTagAPP, @"broadcastId : %@", broadcastId);
                                                        
                                                        _liveBroadcastId = broadcastId;
                                                        
                                                        [self createStreamingChannel:broadcastId];
                                                    }
                                                }];
    [dataTask resume];
}

- (void)createStreamingChannel:(NSString *)broadCastId
{
    NSString *resolution = @"720p";
    NSArray *sizeAr = [[[NSUserDefaults standardUserDefaults] stringForKey:@"LiveSize"] componentsSeparatedByString:@"x"];
    if (sizeAr[1]) {
        resolution = [sizeAr[1] stringByAppendingString:@"p"];
        AppLogDebug(AppLogTagAPP, @"resolution: %@", resolution);
    }
    
    NSString *frameRate = @"30fps";
    ICatchVideoFormat format = [[SDK instance] getVideoFormat];
    unsigned int fr = format.getFps();
    if (fr) {
        frameRate = [NSString stringWithFormat:@"%dfps", fr];
        AppLogDebug(AppLogTagAPP, @"frameRate: %@", frameRate);
    }
    
    AppLogDebug(AppLogTagAPP, @"br: %d", format.getBitrate());
    
    NSDictionary *headers = @{ @"content-type": @"application/json",
                               @"authorization": [@"Bearer " stringByAppendingString:_authorization],
                               @"cache-control": @"no-cache",
                               @"postman-token": @"2be6f4af-116b-51bf-6f22-9c6fa390c18d" };
    NSDictionary *parameters = @{ @"snippet": @{ @"title": @"TestStream" },
                                  @"cdn"    : @{ @"ingestionInfo": @{ @"streamName"       : @"MyTestStream",
                                                                      @"ingestionAddress" : @"rtmp://a.rtmp.youtube.com/live2"},
                                                 @"resolution"    : resolution,
                                                 @"ingestionType" : @"rtmp",
                                                 @"frameRate"     : frameRate,
                                                 }};
    
    NSData *postData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://www.googleapis.com/youtube/v3/liveStreams?part=snippet%2Ccdn"]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:TimeInterval];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    [request setHTTPBody:postData];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        AppLogInfo(AppLogTagAPP, @"%@", error);
                                                        [self liveErrorHandle:LiveErrorCreateStreamingChannel andMessage:error];
                                                        return;
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        AppLogInfo(AppLogTagAPP, @"%@", httpResponse);
                                                        AppLogDebug(AppLogTagAPP, @"createStreamingChannel ---> \n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                        
                                                        NSDictionary *myDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                                                        
                                                        NSString *streamsId = [myDictionary objectForKey:@"id"];
                                                        AppLogDebug(AppLogTagAPP, @"streamsId : %@", streamsId);
                                                        _liveStreamsId = streamsId;
                                                        
                                                        NSDictionary *cdnDict = [myDictionary objectForKey:@"cdn"];
                                                        AppLogDebug(AppLogTagAPP, @"cdnDict ======> %@", cdnDict);
                                                        
                                                        NSDictionary *ingestionInfo = [cdnDict objectForKey:@"ingestionInfo"];
                                                        AppLogDebug(AppLogTagAPP, @"ingestionInfo ======> %@", ingestionInfo);
                                                        
                                                        NSString *streamName = [ingestionInfo objectForKey:@"streamName"];
                                                        NSString *ingestionAddress = [ingestionInfo objectForKey:@"ingestionAddress"];
                                                        AppLogDebug(AppLogTagAPP, @"streamName ======> %@", streamName);
                                                        AppLogDebug(AppLogTagAPP, @"ingestionAddress ======> %@", ingestionAddress);
                                                        
                                                        NSString *postUrl = [NSString stringWithFormat:@"%@/%@", ingestionAddress, streamName];
                                                        AppLogInfo(AppLogTagAPP, @"postUrl : %@", postUrl);
                                                        _postUrl = postUrl;
                                                        
                                                        [self bindLiveBroadcastWithLivestreams:broadCastId andStreamsId:streamsId];
                                                    }
                                                }];
    [dataTask resume];
}

- (void)bindLiveBroadcastWithLivestreams:(NSString *)broadCastId andStreamsId:(NSString *)streamsId
{
    NSDictionary *headers = @{ @"content-type": @"application/json",
                               @"authorization": [@"Bearer " stringByAppendingString:_authorization],
                               @"cache-control": @"no-cache",
                               @"postman-token": @"2be6f4af-116b-51bf-6f22-9c6fa390c18d" };
    
    NSString *url = [@"https://www.googleapis.com/youtube/v3/liveBroadcasts/bind?part=id%2CcontentDetails&" stringByAppendingString:[NSString stringWithFormat:@"id=%@&streamId=%@", broadCastId, streamsId]];
    AppLogDebug(AppLogTagAPP, @"url : %@", url);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:TimeInterval];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        AppLogInfo(AppLogTagAPP, @"%@", error);
                                                        [self liveErrorHandle:LiveErrorBind andMessage:error];
                                                        return;
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        AppLogInfo(AppLogTagAPP, @"%@", httpResponse);
                                                        AppLogDebug(AppLogTagAPP, @"bindLiveBroadcastWithLivestreams ---> \n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                        
                                                        NSDictionary *myDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                                                        NSString *bindId = [myDictionary objectForKey:@"id"];
                                                        AppLogDebug(AppLogTagAPP, @"bindId : %@", bindId);
                                                        _bindId = bindId;
                                                        
                                                        NSString *shareUrl = [NSString stringWithFormat:@"https://www.youtube.com/watch?v=%@", bindId];
                                                        AppLogInfo(AppLogTagAPP, @"shareUrl : %@", shareUrl);
                                                        _shareUrl = shareUrl;
                                                        
                                                        [self startYoutubeLive:_postUrl];
                                                        if (_Living) {
                                                            [NSThread sleepForTimeInterval:TimeInterval];
                                                            [self checkoutLiveBroadCastStatus:streamsId];
                                                        } else {
                                                            [self liveFailedUpdateGUI];
                                                            return;
                                                        }
                                                    }
                                                }];
    [dataTask resume];
}

- (void)checkoutLiveBroadCastStatus:(NSString *)streamsId
{
    NSDictionary *headers = @{ //@"content-type": @"application/json",
                              @"authorization": [@"Bearer " stringByAppendingString:_authorization],
                              @"cache-control": @"no-cache",
                              @"postman-token": @"2be6f4af-116b-51bf-6f22-9c6fa390c18d" };
    
    NSString *url = [@"https://www.googleapis.com/youtube/v3/liveStreams?part=id%2Cstatus&" stringByAppendingString:[NSString stringWithFormat:@"id=%@",streamsId]];
    AppLogDebug(AppLogTagAPP, @"url : %@", url);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:TimeInterval];
    [request setHTTPMethod:@"GET"];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        AppLogInfo(AppLogTagAPP, @"%@", error);
                                                        [self liveErrorHandle:LiveErrorCheckoutLiveBroadCastStatus andMessage:error];
                                                        return;
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        AppLogInfo(AppLogTagAPP, @"%@", httpResponse);
                                                        AppLogDebug(AppLogTagAPP, @"checkoutLiveBroadCastStatus ---> \n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                        
                                                        NSDictionary *myDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                                                        NSString *streamStatus = [[[[myDictionary objectForKey:@"items"] firstObject] objectForKey:@"status"] objectForKey:@"streamStatus"];
                                                        AppLogDebug(AppLogTagAPP, @"streamStatus : %@", streamStatus);
                                                        _streamStatus = streamStatus;
                                                        
                                                        if (_Living) {
                                                            if ([_streamStatus isEqualToString:@"active"]) {
                                                                //                                                            dispatch_async(dispatch_queue_create("WifiCam.GCD.Queue.YoutubeLive-transitionLiveBroadCastStatus", DISPATCH_QUEUE_SERIAL), ^{
                                                                [self transitionLiveBroadCastStatus_1];
                                                                //                                                            });
                                                            } else {
                                                                [NSThread sleepForTimeInterval:TimeInterval];
                                                                [self checkoutLiveBroadCastStatus:streamsId];
                                                            }
                                                        } else {
                                                            [self liveFailedUpdateGUI];
                                                            return;
                                                        }
                                                    }
                                                }];
    [dataTask resume];
}

// active -> testing
- (void)transitionLiveBroadCastStatus_1
{
    NSDictionary *headers = @{ //@"content-type": @"application/json",
                              @"authorization": [@"Bearer " stringByAppendingString:_authorization],
                              @"cache-control": @"no-cache",
                              @"postman-token": @"2be6f4af-116b-51bf-6f22-9c6fa390c18d" };
    //    https://www.googleapis.com/youtube/v3/liveBroadcasts/transition?broadcastStatus=testing&id=TgaR-sHrnjM&part=id%2Csnippet%2CcontentDetails%2Cstatus
    NSString *url = [[NSString stringWithFormat:@"https://www.googleapis.com/youtube/v3/liveBroadcasts/transition?broadcastStatus=testing&id=%@", _liveBroadcastId] stringByAppendingString:@"&part=id%2Csnippet%2CcontentDetails%2Cstatus"];
    AppLogDebug(AppLogTagAPP, @"url : %@", url);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:TimeInterval];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        AppLogInfo(AppLogTagAPP, @"%@", error);
                                                        [self liveErrorHandle:LiveErrorTransitionLiveBroadCastStatus_1 andMessage:error];
                                                        return;
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        AppLogInfo(AppLogTagAPP, @"%@", httpResponse);
                                                        AppLogDebug(AppLogTagAPP, @"transitionLiveBroadCastStatus_1 ---> \n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                        
                                                        if (_Living) {
                                                            [NSThread sleepForTimeInterval:TimeInterval];
                                                            [self getLiveBroadcastStauts];
                                                        } else {
                                                            [self liveFailedUpdateGUI];
                                                            return;
                                                        }
                                                    }
                                                }];
    [dataTask resume];
}

// testing -> live
- (void)transitionLiveBroadCastStatus_2
{
    NSDictionary *headers = @{ //@"content-type": @"application/json",
                              @"authorization": [@"Bearer " stringByAppendingString:_authorization],
                              @"cache-control": @"no-cache",
                              @"postman-token": @"2be6f4af-116b-51bf-6f22-9c6fa390c18d" };
    
    //    https://www.googleapis.com/youtube/v3/liveBroadcasts/transition?broadcastStatus=live&id=TgaR-sHrnjM&part=id%2Csnippet%2CcontentDetails%2Cstatus
    NSString *url = [[NSString stringWithFormat:@"https://www.googleapis.com/youtube/v3/liveBroadcasts/transition?broadcastStatus=live&id=%@", _liveBroadcastId] stringByAppendingString:@"&part=id%2Csnippet%2CcontentDetails%2Cstatus"];
    AppLogDebug(AppLogTagAPP, @"url : %@", url);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:TimeInterval];
    [request setHTTPMethod:@"POST"];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        AppLogInfo(AppLogTagAPP, @"%@", error);
                                                        [self liveErrorHandle:LiveErrorTransitionLiveBroadCastStatus_2 andMessage:error];
                                                        return;
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        AppLogInfo(AppLogTagAPP, @"%@", httpResponse);
                                                        AppLogDebug(AppLogTagAPP, @"transitionLiveBroadCastStatus_2 ---> \n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                        [self showShareUrlQRCode:_shareUrl];
                                                    }
                                                }];
    [dataTask resume];
}

- (void)getLiveBroadcastStauts
{
    NSDictionary *headers = @{ //@"content-type": @"application/json",
                              @"authorization": [@"Bearer " stringByAppendingString:_authorization],
                              @"cache-control": @"no-cache",
                              @"postman-token": @"2be6f4af-116b-51bf-6f22-9c6fa390c18d" };
    
    //    https://www.googleapis.com/youtube/v3/liveBroadcasts/transition?broadcastStatus=live&id=TgaR-sHrnjM&part=id%2Csnippet%2CcontentDetails%2Cstatus
    NSString *url = [@"https://www.googleapis.com/youtube/v3/liveBroadcasts?part=id%2Cstatus" stringByAppendingString:[NSString stringWithFormat:@"&id=%@", _liveBroadcastId]];
    AppLogDebug(AppLogTagAPP, @"url : %@", url);
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                           cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                       timeoutInterval:TimeInterval];
    [request setHTTPMethod:@"GET"];
    [request setAllHTTPHeaderFields:headers];
    
    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                                    if (error) {
                                                        AppLogInfo(AppLogTagAPP, @"%@", error);
                                                        [self liveErrorHandle:LiveErrorGetLiveBroadcastStauts andMessage:error];
                                                        return;
                                                    } else {
                                                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
                                                        AppLogInfo(AppLogTagAPP, @"%@", httpResponse);
                                                        AppLogDebug(AppLogTagAPP, @"getLiveBroadcastStauts ---> \n%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
                                                        
                                                        NSDictionary *myDictionary = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
                                                        NSString *liveBroadcastStatus = [[[[myDictionary objectForKey:@"items"] firstObject] objectForKey:@"status"] objectForKey:@"lifeCycleStatus"];
                                                        AppLogDebug(AppLogTagAPP, @"liveBroadcastStatus : %@", liveBroadcastStatus);
                                                        _liveBroadcastStatus = liveBroadcastStatus;
                                                        
                                                        if (_Living) {
                                                            if ([_liveBroadcastStatus isEqualToString:@"testing"]) {
                                                                [self transitionLiveBroadCastStatus_2];
                                                            } else {
                                                                [NSThread sleepForTimeInterval:TimeInterval];
                                                                [self getLiveBroadcastStauts];
                                                            }
                                                        } else {
                                                            [self liveFailedUpdateGUI];
                                                            return;
                                                        }
                                                    }
                                                }];
    [dataTask resume];
}

@end
