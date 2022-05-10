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

//t #include "SignInViewController.h"
//t #import <GoogleSignIn/GoogleSignIn.h>
#import <ImageIO/CGImageProperties.h>
#import "SavemediaInAlbum.h"
#import "FileDes.h"



#define TimeInterval [[[NSUserDefaults standardUserDefaults] stringForKey:@"LivePostTimeoutInterval"] doubleValue]
CVImageBufferRef photoImageBuffer;
NSMutableArray *videotemp = [NSMutableArray array];

BOOL capturePhoto = NO;
BOOL recordVideo = NO;
SaveMediaInAlbum * saveMedia = [[SaveMediaInAlbum alloc] init];

static void didDecompress( void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    
 //   CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
//    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);

    
       

        if (status != noErr)
        {
            NSError *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
            AppLog(@"Decompressed error: %@", error);
        }
        else
        {
            AppLog(@"Decompressed sucessfully");
            // do something with your resulting CVImageBufferRef that is your decompressed frame
            CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
            CIContext *temporaryContext = [CIContext contextWithOptions:nil];
            CGImageRef videoImage = [temporaryContext
                                         createCGImage:ciImage
                                         fromRect:CGRectMake(0, 0,
                                         CVPixelBufferGetWidth(pixelBuffer),
                                         CVPixelBufferGetHeight(pixelBuffer))];

            UIImage *image = [[UIImage alloc] initWithCGImage:videoImage];
            if(capturePhoto){
               //UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
               [saveMedia savePhoto:image];
               capturePhoto = NO;
            }
            if(recordVideo){
                [videotemp addObject:image];
            }
            CGImageRelease(videoImage);
        }
   
    
    
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
    
    [self.settingButton setTintColor: [UIColor clearColor]];//test20220208
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
    CMTimebaseCreateWithSourceClock(CFAllocatorGetDefault(), CMClockGetHostTimeClock(), &controlTimebase);
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
    [self.recordingLabel setText:NSLocalizedString(@"recording",nil)];
    _ImageQualityButton.transform = CGAffineTransformMakeScale(1.3, 1.3);
    _deviceInfoButton.transform = CGAffineTransformMakeScale(1.3, 1.3);
    _mpbToggle.transform = CGAffineTransformMakeScale(1.3, 1.3);
    [self iniIQSetting];
    [self createAppAlbum];
    //if first in , show bootPage
    [self checkFristInApp];
  
   
}

- (void)openBootPage{
    
    _appBootView.hidden = NO;
    CGRect screenRect = [[UIScreen mainScreen] bounds];
    screenRect.origin.y = 20;
    self.navigationController.navigationBar.hidden = YES;
    UIGraphicsBeginImageContext(screenRect.size);
    [[UIImage imageNamed:@"leaderImg"] drawInRect:screenRect];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    self.appBootView.backgroundColor = [UIColor colorWithPatternImage:image];
    [self.bootPageButton setTitle:NSLocalizedString(@"I_know",nil) forState:UIControlStateNormal];
}

- (void)checkFristInApp
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"isFirstIn"]){
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"isFirstIn"];
            //iniBootPageView
            [self openBootPage];
        });
    }
}


- (void)iniIQSetting{
    
    _CloseIQViewButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    _CloseIQViewButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    _CloseIQViewButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    _CloseIQViewButton.imageEdgeInsets = UIEdgeInsetsMake(40,40,40,40);
    
    _CloseIQSettingViewButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
    _CloseIQSettingViewButton.contentHorizontalAlignment = UIControlContentHorizontalAlignmentFill;
    _CloseIQSettingViewButton.contentVerticalAlignment = UIControlContentVerticalAlignmentFill;
    _CloseIQSettingViewButton.imageEdgeInsets = UIEdgeInsetsMake(40,40,40,40);
    
    [_IQbrightnessButton setTitle:NSLocalizedString(@"SETTING_BRIGHTNESS",nil) forState:UIControlStateNormal];
    [_IQhueButton setTitle:NSLocalizedString(@"SETTING_HUE",nil) forState:UIControlStateNormal];
    [_IQsaturationButton setTitle:NSLocalizedString(@"SETTING_SATURATION",nil) forState:UIControlStateNormal];
    [_IQWhiteBalanceButton setTitle:NSLocalizedString(@"SETTING_AWB",nil) forState:UIControlStateNormal];
    [_IQrevertToDefaultButton setTitle:NSLocalizedString(@"RESET_IQ",nil) forState:UIControlStateNormal];

    [_changeIqPwdButton setTitle:NSLocalizedString(@"change_password",nil) forState:UIControlStateNormal];
    _changeIqPwdButton.titleLabel.font = [UIFont systemFontOfSize:14];
    _IQValueSlider.minimumValue = 0;
    _IQValueSlider.maximumValue = 255;
    _IQValueSlider.continuous = NO;
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
  /*t
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
    */
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
    [self.recordingLabel setHidden:YES];
    [self.deviceInfoButton setEnabled:YES];

    
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
    self.recordingLabel.hidden=NO;
    self.videoToggle.enabled = NO;
    self.mpbToggle.enabled = NO;
    self.settingButton.enabled = NO;
    self.enableAudioButton.enabled = NO;
    self.ImageQualityButton.enabled = NO;
    self.deviceInfoButton.enabled = NO;
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
        VTDecodeFrameFlags flags = kVTDecodeFrame_EnableAsynchronousDecompression;
        VTDecodeInfoFlags flagOut;
        NSDate* currentTime = [NSDate date];
        VTDecompressionSessionDecodeFrame(_deocderSession, sampleBuffer, flags,
                                          (void*)CFBridgingRetain(currentTime), &flagOut);
 
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
                    AppLog(@"nothing work");
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

- (IBAction)getDeviceInfoList:(id)sender
{
  //  [_ctrl.propCtrl ];
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"cancel",nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {

            // Cancel button tappped.
           
        }]];
        
        NSString *appVersion = [[[NSBundle mainBundle] infoDictionary]
                               objectForKey:@"CFBundleShortVersionString"];
    
        
    
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"appVersion",nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"appVersion",nil)
                                         message:appVersion
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* yesButton = [UIAlertAction
                                        actionWithTitle:NSLocalizedString(@"sure",nil)
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * action) {
                }];
            [alert addAction:yesButton];
            [self presentViewController:alert animated:YES completion:nil];
        }]];
    
        [actionSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"SETTING_ABOUT",nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            UIAlertController * alert = [UIAlertController
                                         alertControllerWithTitle:NSLocalizedString(@"appName",nil)
                                         message:[self->_ctrl.propCtrl retrieveDeviceInfo]
                                         preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* yesButton = [UIAlertAction
                                        actionWithTitle:NSLocalizedString(@"sure",nil)
                                        style:UIAlertActionStyleDefault
                                        handler:^(UIAlertAction * action) {
                                        }];
            [alert addAction:yesButton];
            [self presentViewController:alert animated:YES completion:nil];
        }]];

        // Present action sheet.
        [self presentViewController:actionSheet animated:YES completion:nil];
    
}

- (void) ShowAlert:(NSString *)Message {
    UIAlertController * alert=[UIAlertController alertControllerWithTitle:nil
                                                                  message:@""
                                                           preferredStyle:UIAlertControllerStyleAlert];
    UIView *firstSubview = alert.view.subviews.firstObject;
    UIView *alertContentView = firstSubview.subviews.firstObject;
    for (UIView *subSubView in alertContentView.subviews) {
        subSubView.backgroundColor = [UIColor colorWithRed:0/255.0f green:0/255.0f blue:0/255.0f alpha:1.0f];
        subSubView.tintColor = [UIColor colorWithRed:255 green:255 blue:255 alpha:1.0f];
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
                                            self->_isCheckIQPassword = YES;
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
                                    self->_isCheckIQPassword = NO;
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

- (IBAction)closeBootPage:(id)sender
{
    _appBootView.hidden = YES;
    self.navigationController.navigationBar.hidden = NO;
}

- (IBAction)changeIqPwdButton:(id)sender
{
    [self changeIQPassword];
}

    
- (IBAction)showViewImageQuality:(id)sender
{
    if(![self isCheckIQPassword]){
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
    _IQSettingView.hidden = YES;
    _ImageQualityView.hidden = NO;
}


- (IBAction)setIQtype:(id)sender
{
   // [_ctrl.propCtrl changeBrightness:128];
    
    _WB_AUTO.hidden = YES;
    _WB_DAYLIGHT.hidden = YES;
    _WB_CLOUDY.hidden = YES;
    _WB_INCADESCENT.hidden = YES;
    _WB_FLOURESCENT_H.hidden = YES;
    switch ([sender tag]){
        case 0:{
            _curIQMode = BRIGHTNESS;
            _IQValueSlider.maximumValue = 255;
            _IQSettingView.hidden = NO;
            _IQValueSlider.hidden = NO;
            _IQCurValueLabel.hidden = NO;
            _IQsilderLabel.hidden = NO;
            NSString *tempvalue = [_ctrl.propCtrl retrieveIQbrightnessValue];
            _IQCurValueLabel.text = tempvalue;
            _IQValueSlider.value = [tempvalue floatValue];
            [_IQsilderLabel setText:NSLocalizedString(@"SETTING_BRIGHTNESS",nil)];
            break;
            
        }
        case 1:{
            _curIQMode = HUE;
            _IQValueSlider.maximumValue = 360;
            _IQSettingView.hidden = NO;
            _IQValueSlider.hidden = NO;
            _IQCurValueLabel.hidden = NO;
            _IQsilderLabel.hidden = NO;
            NSString *tempvalue1 = [_ctrl.propCtrl retrieveIQhueValue];
            _IQCurValueLabel.text = tempvalue1;
            _IQValueSlider.value = [tempvalue1 floatValue];
            [_IQsilderLabel setText:NSLocalizedString(@"SETTING_HUE",nil)];
            break;
            
        }
        case 2:{
            _curIQMode = SATURATION;
            _IQValueSlider.maximumValue = 255;
            _IQSettingView.hidden = NO;
            _IQValueSlider.hidden = NO;
            _IQCurValueLabel.hidden = NO;
            _IQsilderLabel.hidden = NO;
            NSString *tempvalue2 = [_ctrl.propCtrl retrieveIQsaturationValue];
            _IQCurValueLabel.text = tempvalue2;
            _IQValueSlider.value = [tempvalue2 floatValue];
            [_IQsilderLabel setText:NSLocalizedString(@"SETTING_SATURATION",nil)];
            break;
        }
        case 3:{
            _curIQMode = WHTIE_BALANCE;
            _IQSettingView.hidden = NO;
            _IQValueSlider.hidden = YES;
            _IQCurValueLabel.hidden = YES;
            _IQsilderLabel.hidden = YES;
            _WB_AUTO.hidden = NO;
            _WB_DAYLIGHT.hidden = NO;
            _WB_CLOUDY.hidden = NO;
            _WB_INCADESCENT.hidden = NO;
            _WB_FLOURESCENT_H.hidden = NO;
            [_WB_AUTO setTitle:NSLocalizedString(@"SETTING_AWB_AUTO",nil) forState:UIControlStateNormal];
            [_WB_DAYLIGHT setTitle:NSLocalizedString(@"SETTING_AWB_DAYLIGHT",nil) forState:UIControlStateNormal];
            [_WB_CLOUDY setTitle:NSLocalizedString(@"SETTING_AWB_CLOUDY",nil) forState:UIControlStateNormal];
            [_WB_INCADESCENT setTitle:NSLocalizedString(@"SETTING_AWB_INCANDESCENT",nil) forState:UIControlStateNormal];
            [_WB_FLOURESCENT_H setTitle:NSLocalizedString(@"SETTING_AWB_FLUORESECENT",nil) forState:UIControlStateNormal];
            break;
        }
        case 4:{
            [_ctrl.propCtrl resetIQvalue];
            [self ShowAlert:NSLocalizedString(@"RESET_IQ_SUCCESS", nil)];
        }
      
       
        
    }
    
}



- (IBAction)changeIQvalueSlider:(id)sender
{
    switch (_curIQMode){
        case BRIGHTNESS:{
            [_ctrl.propCtrl changeBrightness:_IQValueSlider.value];
            _IQCurValueLabel.text = [[NSString alloc] initWithFormat:@"%d",(int)_IQValueSlider.value];
            break;
        }
        case HUE:{
            [_ctrl.propCtrl changeHue:_IQValueSlider.value];
            _IQCurValueLabel.text = [[NSString alloc] initWithFormat:@"%d",(int)_IQValueSlider.value];
            break;
        }
        case SATURATION:{
            [_ctrl.propCtrl changeSaturation:_IQValueSlider.value];
            _IQCurValueLabel.text = [[NSString alloc] initWithFormat:@"%d",(int)_IQValueSlider.value];
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
   /* if (![self capableOf:WifiCamAbilityNewCaptureWay]) {
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
    }*/
 
    //[self screenshotOfVideoStream:photoImageBuffer];
    //[self screenshotOfVideoStream];
   /* CFDictionaryRef attrs = NULL;
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
    CFRelease(attrs);*/
   
    
    capturePhoto = YES;

    [_ctrl.propCtrl PhotoCapture];
    
    
}





- (void)startMovieRec {
    AudioServicesPlaySystemSound(_videoCaptureSound);
    [self showProgressHUDWithMessage:nil];
    AppLog(@"startMovieRec");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateVideoSizeOnScreen:_camera.curVideoSize];
        });
        /*
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
        }*/
        dispatch_async(dispatch_get_main_queue(), ^{
            recordVideo = YES;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self videoWrite];
            });
            
            [self hideProgressHUD:YES];
            [self updatePreviewSceneByMode:WifiCamPreviewModeVideoOn];
            _Recording = YES;
            if (![self capableOf:WifiCamAbilityGetMovieRecordedTime]) {
                if (![_videoCaptureTimer isValid]) {
                     self.videoCaptureTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                                         target  :self
                                                                         selector:@selector(movieRecordingTimerCallback:)
                                                                         userInfo:nil
                                                                         repeats :YES];
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
        dispatch_async(dispatch_get_main_queue(), ^{
            recordVideo = NO;
            [self updatePreviewSceneByMode:WifiCamPreviewModeVideoOff];
            [self hideProgressHUD:YES];
            [self remMovieRecListener];
            if ([_videoCaptureTimer isValid]) {
                [_videoCaptureTimer invalidate];
                self.movieRecordElapsedTimeInSeconds = 0;
            }
            _Recording = NO;
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

- (void)createAppAlbum{
        NSString *albumTitle = NSLocalizedString(@"appName",nil);

        PHFetchResult<PHAssetCollection *> *collections = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
        for (PHAssetCollection *collection in collections) {
            if ([collection.localizedTitle isEqualToString:albumTitle]) {
                return;
            }
        }
    
        __block NSString *createdCollectionId = nil;

        [[PHPhotoLibrary sharedPhotoLibrary] performChangesAndWait:^{
            createdCollectionId = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:albumTitle].placeholderForCreatedAssetCollection.localIdentifier;
        } error:nil];
        
}



-(void)videoWrite{
    
    /*---Check video folder existed---*/
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,   NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths lastObject];
    
    NSString *dataFilePath = [documentsDirectory stringByAppendingPathComponent:@"video"];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:dataFilePath isDirectory:&isDir];

    if (!(isDir && existed)) {
        [fileManager createDirectoryAtPath:dataFilePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    /*--- video write---*/
    NSDate *date = [NSDate date];
    AppLogDebug(AppLogTagAPP, @"date ----> %@", date);
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    [dateFormatter setTimeZone:GTMzone];
    [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
    
    NSString *actualStartTime = [dateFormatter stringFromDate:date];
    NSString *temp =[actualStartTime stringByAppendingString:@".mp4"];
    NSString *document = @"Documents/video/";
    NSString *result = [document stringByAppendingString:temp];
    NSString *betaCompressionDirectory = [NSHomeDirectory() stringByAppendingPathComponent:result];
    
    CGSize size = CGSizeMake(736,1120);

    NSError *error = nil;

    unlink([betaCompressionDirectory UTF8String]);

    //—-initialize compression engine
    AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:betaCompressionDirectory]
    fileType:AVFileTypeQuickTimeMovie
    error:&error];
    NSParameterAssert(videoWriter);
    if (error){
        AppLog(@"error = %@", [error localizedDescription]);
    }
    NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecTypeH264, AVVideoCodecKey,
    [NSNumber numberWithInt:size.width], AVVideoWidthKey,
    [NSNumber numberWithInt:size.height], AVVideoHeightKey, nil];
    AppLog(@"video size = %f %f",size.width,size.height);
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    
    NSDictionary *sourcePixelBufferAttributesDictionary = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];

    AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor
    assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:sourcePixelBufferAttributesDictionary];
    NSParameterAssert(writerInput);
    NSParameterAssert([videoWriter canAddInput:writerInput]);

    if ([videoWriter canAddInput:writerInput]){
        AppLog(@"Can add this input");
    }
    else{
        AppLog(@"Can't add this input");
    }
    
    [videoWriter addInput:writerInput];

    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    // insert demo debugging code to write the same image repeated as a movie
    /*---get encrypt key---*/
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *key;
    if([defaults stringForKey:@"PB_password"].length==0){
        key = [FileDes randomStringWithLength:10];
        [defaults setObject:key forKey:@"PB_password"];
        [defaults synchronize];
    }else{
        key = [defaults stringForKey:@"PB_password"];
    }
    
    
    dispatch_queue_t dispatchQueue = dispatch_queue_create("mediaInputQueue", NULL);

    int __block frame = 0;
    UIImage  * __block uiImage=[videotemp objectAtIndex:0];
    [writerInput requestMediaDataWhenReadyOnQueue:dispatchQueue usingBlock:^{
        
        while ([writerInput isReadyForMoreMediaData]){
            @autoreleasepool {
        
                if ((videotemp.count==0)&&(!recordVideo)){
                    [writerInput markAsFinished];
                    [videoWriter finishWritingWithCompletionHandler:^(){
                            AppLog (@"finished writing");
                    }];                    [videotemp removeAllObjects];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [FileDes EncryptVideo:key videoUrl:[NSURL fileURLWithPath:betaCompressionDirectory] fileName:actualStartTime];
                    });
                    
                    break;
                }
          
                if (videotemp.count>0){
                    ++frame;
                    uiImage=[videotemp objectAtIndex:0];
                    CVPixelBufferRef buffer = (CVPixelBufferRef)[self pixelBufferFromUIImage:uiImage size:size];
                    if (buffer){
                        if (![adaptor appendPixelBuffer:buffer withPresentationTime:CMTimeMake(frame, 20)]){
                            AppLog(@"Fail appendPixelBuffer");
                        }
                        else{
                            AppLog(@"Success appendPixelBuffer:%d", frame);
                            [videotemp removeObjectAtIndex:0];
                        }
                        CFRelease(buffer);
                    }
                }
            }
        }
    }];
}
/*
- (void)saveVideotoAlbum:(NSString *)urlString
{
       ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
       [library writeVideoAtPathToSavedPhotosAlbum:[NSURL fileURLWithPath:urlString]
                                   completionBlock:^(NSURL *assetURL, NSError *error) {
                                       if (error) {
                                           NSLog(@"Save video fail:%@",error);
                                       } else {
                                           NSLog(@"Save video succeed.");
                                       }
                                   }];
}*/

- (CVPixelBufferRef )pixelBufferFromUIImage:(UIImage *)image size:(CGSize)size
{

    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:

                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,

                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey, nil];

    CVPixelBufferRef pxbuffer = NULL;

    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options, &pxbuffer);

    // CVReturn status = CVPixelBufferPoolCreatePixelBuffer(NULL, adaptor.pixelBufferPool, &pxbuffer);

    

    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    

    CVPixelBufferLockBaseAddress(pxbuffer, 0);

    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);

    NSParameterAssert(pxdata != NULL);

    

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();

    CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, 4*size.width, rgbColorSpace, kCGImageAlphaPremultipliedFirst);

    NSParameterAssert(context);

    

    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image.CGImage), CGImageGetHeight(image.CGImage)), image.CGImage);

    

    CGColorSpaceRelease(rgbColorSpace);

    CGContextRelease(context);

    
    

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);

    

    return pxbuffer;

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

-(void)decryptphotofile{
            
    
    /*---Check photo folder existed---*/
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,   NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths lastObject];
    
    NSString *dataFilePath = [documentsDirectory stringByAppendingPathComponent:@"media"];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    BOOL isDir = NO;
    BOOL existed = [fileManager fileExistsAtPath:dataFilePath isDirectory:&isDir];

    if (!(isDir && existed)) {
        [fileManager createDirectoryAtPath:dataFilePath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
        /*---media decrypt---*/
        NSString *documentPhoto = @"Documents/photo/";
        NSString  *photoPath = [NSHomeDirectory() stringByAppendingPathComponent:documentPhoto];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *key;
        if([defaults stringForKey:@"PB_password"].length==0){
            key = [FileDes randomStringWithLength:10];
            [defaults setObject:key forKey:@"PB_password"];
            [defaults synchronize];
        }else{
            key = [defaults stringForKey:@"PB_password"];
        }

        NSArray *documentsDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:photoPath error:nil];
        for (NSString *fileName in  documentsDirectoryContents) {
            NSString  *temp = [photoPath stringByAppendingPathComponent:fileName];
            NSData *img = [[NSData alloc] initWithContentsOfFile:temp];
            if(img==nil){
                AppLog(@"pfilePathnil!");
            }
            else{
                AppLog(@"pfilePathnonil!");
            }
            [FileDes desDecrypt:key imageData:img fileName:fileName];
          
        }
        NSString *documentVideo = @"Documents/video/";
        NSString  *videoPath = [NSHomeDirectory() stringByAppendingPathComponent:documentVideo];
        NSArray *documentsDirectoryContents2 = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:videoPath error:nil];
        for (NSString *fileName in  documentsDirectoryContents2) {
            NSString  *temp = [videoPath stringByAppendingPathComponent:fileName];
            NSData *img = [[NSData alloc] initWithContentsOfFile:temp];
            if(img==nil){
                AppLog(@"vfilePathnil!");
            }
            else{
                AppLog(@"vfilePathnonil!");
            }
            if([temp containsString:@"E.mp4"]){
                [FileDes DecryptVideo:key videoUrl:temp fileName:fileName];
            }
        }
    
    
   
    
}

- (IBAction)mpbAction:(id)sender
{
    
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)];
      
    });
    @autoreleasepool {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.03 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self decryptphotofile];
    });
        
        
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self hideProgressHUD:YES];
        NSMutableArray *photos = [[NSMutableArray alloc] init];
        NSMutableArray *thumbs = [[NSMutableArray alloc] init];
        //MWPhoto *photo, *thumb;
        BOOL displayActionButton = YES;
        BOOL displaySelectionButtons = NO;
        BOOL displayNavArrows = YES;
        BOOL enableGrid = YES;
        BOOL startOnGrid = YES;
        BOOL autoPlayOnAppear = NO;
       
        
        NSString *document = @"Documents/media/";
        NSString  *photoPath = [NSHomeDirectory() stringByAppendingPathComponent:document];

        
        NSArray *documentsDirectoryContents = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:photoPath error:nil] sortedArrayUsingSelector:@selector(compare:)];
            for (NSString *fileName in  documentsDirectoryContents) {
                AppLog("filenameis%@",fileName);
                NSString  *temp = [photoPath stringByAppendingPathComponent:fileName];
                if([temp containsString:@".png"]){
                    MWPhoto *photo =[MWPhoto photoWithURL:[NSURL fileURLWithPath:temp]];
                    photo.photoUrl = [NSURL fileURLWithPath:temp];
                    [photos addObject:photo];
                    [thumbs addObject:photo];
                }else if([temp containsString:@".mp4"]){
                    MWPhoto *video = [MWPhoto photoWithImage:[self getScreenShotImageFromVideoPath:temp]];
                    video.videoURL = [NSURL fileURLWithPath:temp];
                    video.photoUrl = [NSURL fileURLWithPath:temp];
                    [photos addObject:video];
                    [thumbs addObject:video];
                }
            }
  
        
        
        
        
        self.photos = photos;
        self.thumbs = thumbs;
        
        
        // Create browser
        MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
        browser.displayActionButton = displayActionButton;
        browser.displayNavArrows = displayNavArrows;
        browser.displaySelectionButtons = displaySelectionButtons;
        browser.alwaysShowControls = displaySelectionButtons;
        browser.zoomPhotosToFill = YES;
        browser.enableGrid = enableGrid;
        browser.startOnGrid = startOnGrid;
        browser.enableSwipeToDismiss = NO;
        browser.autoPlayOnAppear = autoPlayOnAppear;
        [browser setCurrentPhotoIndex:0];
        
        // Test custom selection images
        //    browser.customImageSelectedIconName = @"ImageSelected.png";
        //    browser.customImageSelectedSmallIconName = @"ImageSelectedSmall.png";
        
        // Reset selections
        if (displaySelectionButtons) {
            _selections = [NSMutableArray new];
            for (int i = 0; i < photos.count; i++) {
                [_selections addObject:[NSNumber numberWithBool:NO]];
            }
        }
        
        
        // Modal
        UINavigationController *nc = [[UINavigationController alloc] initWithRootViewController:browser];
        nc.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        nc.modalPresentationStyle = UIModalPresentationOverFullScreen;
        [self presentViewController:nc animated:YES completion:nil];

        
        // Test reloading of data after delay
        double delayInSeconds = 3;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        });
    });
     
    
    /*
    [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
   
      //if (![self->_ctrl.propCtrl checkSDExist]) {
            //dispatch_async(dispatch_get_main_queue(), ^{
            //    [self showProgressHUDNotice:NSLocalizedString(@"NoCard", nil) showTime:2.0];
           // });
          //  return;
        //}
        
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
    });*/
    }
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

-(UIImage *)getScreenShotImageFromVideoPath:(NSString *)filePath{

    UIImage *shotImage;
    //视频路径URL
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];

    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:fileURL options:nil];

    AVAssetImageGenerator *gen = [[AVAssetImageGenerator alloc] initWithAsset:asset];

    gen.appliesPreferredTrackTransform = YES;
    CMTime time = CMTimeMakeWithSeconds(0.0, 600);

    NSError *error = nil;

    CMTime actualTime;

    CGImageRef image = [gen copyCGImageAtTime:time actualTime:&actualTime error:&error];

    shotImage = [[UIImage alloc] initWithCGImage:image];

    CGImageRelease(image);

    return shotImage;

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
    //[self stopYoutubeLive];
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
   // [self stopYoutubeLive];
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
    //[self stopYoutubeLive];
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
    //[self stopYoutubeLive];
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

#pragma mark - MWPhotoBrowserDelegate

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return _photos.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < _photos.count)
        return [_photos objectAtIndex:index];
    return nil;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser thumbPhotoAtIndex:(NSUInteger)index {
    if (index < _thumbs.count)
        return [_thumbs objectAtIndex:index];
    return nil;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index {
    NSLog(@"Did start viewing photo at index %lu", (unsigned long)index);
}

- (BOOL)photoBrowser:(MWPhotoBrowser *)photoBrowser isPhotoSelectedAtIndex:(NSUInteger)index {
    return [[_selections objectAtIndex:index] boolValue];
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index selectedChanged:(BOOL)selected {
    [_selections replaceObjectAtIndex:index withObject:[NSNumber numberWithBool:selected]];
    NSLog(@"Photo at index %lu selected %@", (unsigned long)index, selected ? @"YES" : @"NO");
}

- (BOOL)photoBrowser:(MWPhotoBrowser *)photoBrowser
        deletePhotoAtIndex:(NSUInteger)index PhotoUrl:(NSURL *)photoUrl
{
    BOOL success = NO;
    NSArray  * fileName = [photoUrl.absoluteString componentsSeparatedByString:@"/media/"];
    NSString * document = @"Documents/media/";
    NSString * photoPath = [NSHomeDirectory() stringByAppendingPathComponent:document];
    NSString * mediaPath = [photoPath stringByAppendingPathComponent:fileName[1]];
    [[NSFileManager defaultManager] removeItemAtPath:mediaPath error:nil];
    if([fileName[1] containsString:@".png"]){
        NSString * photo = @"Documents/photo/";
        NSString * photoAlbumPath = [NSHomeDirectory() stringByAppendingPathComponent:photo];
        NSString * totalPath = [photoAlbumPath stringByAppendingPathComponent:fileName[1]];
        success = [[NSFileManager defaultManager] removeItemAtPath:totalPath error:nil];
    }else if([fileName[1] containsString:@".mp4"]){
        NSString * video = @"Documents/video/";
        NSString * videoAlbumPath = [NSHomeDirectory() stringByAppendingPathComponent:video];
        NSString * totalPath = [videoAlbumPath stringByAppendingPathComponent:fileName[1]];
        success = [[NSFileManager defaultManager] removeItemAtPath:totalPath error:nil];
    }
    [self.photos removeObjectAtIndex:index];
    [self.thumbs removeObjectAtIndex:index];
    return success;
}

- (void)photoBrowserDidFinishModalPresentation:(MWPhotoBrowser *)photoBrowser {
    // If we subscribe to this method we must dismiss the view controller ourselves
    AppLog(@"Did finish modal presentation");
    
    NSString *document = @"Documents/media/";
    NSString  *photoPath = [NSHomeDirectory() stringByAppendingPathComponent:document];

    NSArray *documentsDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:photoPath error:nil];
    for (NSString *fileName in  documentsDirectoryContents) {
        NSString  *temp = [photoPath stringByAppendingPathComponent:fileName];
        [[NSFileManager defaultManager] removeItemAtPath:temp error:nil];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
   
}


@end
