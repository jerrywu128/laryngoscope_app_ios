//
//  VideoPlaybackViewController.m
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-3-10.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#import "VideoPlaybackViewController.h"
#import "MpbPopoverViewController.h"
#import "VideoPlaybackSlideController.h"
#import "VideoPlaybackBufferingView.h"
#import "MBProgressHUD.h"
#import "HYOpenALHelper.h"
#import "AppDelegate.h"
#include "MpbSDKEventListener.h"
#import "GCDiscreetNotificationView.h"
#ifdef DEBUG1
#include "ICatchWificamConfig.h"
#endif
#include "WifiCamSDKEventListener.h"
#include "PCMDataPlayer.h"

@interface VideoPlaybackViewController () {
    UIPopoverController *_popController;
    /**
     *  20160503 zijie.feng
     *  Deprecated !
     */
#if USE_SYSTEM_IOS7_IMPLEMENTATION
    UIActionSheet *_actionsSheet;
#else
    UIAlertController *_actionsSheet;
#endif
    
    VideoPbProgressListener *videoPbProgressListener;
    VideoPbProgressStateListener *videoPbProgressStateListener;
    VideoPbDoneListener *videoPbDoneListener;
    VideoPbServerStreamErrorListener *videoPbServerStreamErrorListener;
}
@property(nonatomic) IBOutlet UIImageView *previewThumb;
@property(nonatomic) IBOutlet VideoPlaybackSlideController *slideController;
@property(nonatomic) IBOutlet UIView *bufferingBgView;
@property(nonatomic) IBOutlet VideoPlaybackBufferingView *bufferingView;
@property(nonatomic) IBOutlet UIView *pbCtrlPanel;
@property(nonatomic) IBOutlet UIButton *playbackButton;
@property(nonatomic) IBOutlet UILabel *videoPbTotalTime;
@property(nonatomic) IBOutlet UILabel *videoPbElapsedTime;
@property(nonatomic) IBOutlet UIBarButtonItem *deleteButton;
@property(nonatomic) IBOutlet UIBarButtonItem *actionButton;
@property(nonatomic) BOOL PlaybackRun;
@property(nonatomic, getter = isPlayed) BOOL played;
@property(nonatomic, getter = isPaused) BOOL paused;
@property(nonatomic) BOOL seeking;
@property(nonatomic) BOOL exceptionHappen;
@property(nonatomic, getter =  isControlHidden) BOOL controlHidden;
@property(nonatomic) dispatch_semaphore_t semaphore;
@property(nonatomic) NSTimer *pbTimer;
@property(nonatomic) double totalSecs;
@property(nonatomic) double playedSecs;
@property(nonatomic) double curVideoPTS;
@property(nonatomic) NSUInteger downloadedPercent;
@property(nonatomic) MBProgressHUD *progressHUD;
@property(nonatomic) HYOpenALHelper *al;
@property(nonatomic) PCMDataPlayer *pcmPl;
@property(nonatomic) WifiCam *wifiCam;
@property(nonatomic) WifiCamCamera *camera;
@property(nonatomic) WifiCamPhotoGallery *gallery;
@property(nonatomic) WifiCamControlCenter *ctrl;
@property(nonatomic, retain) GCDiscreetNotificationView *notificationView;
@property(nonatomic) dispatch_group_t playbackGroup;
@property(nonatomic) dispatch_queue_t videoPlaybackQ;
@property(nonatomic) dispatch_queue_t audioQueue;
@property(nonatomic) dispatch_queue_t videoQueue;
@property(nonatomic) int times;
@property(nonatomic) int times1;
@property(nonatomic) float totalElapse;
@property(nonatomic) float totalElapse1;
@property(nonatomic) float totalDuration;
//@property(nonatomic) WifiCamObserver *streamObserver;
@end

@implementation VideoPlaybackViewController

@synthesize previewImage;
@synthesize index;

#pragma mark - Lifecycle
- (void)viewDidLoad
{
    AppLog(@"%s", __func__);
    [super viewDidLoad];
    
    WifiCamManager *app = [WifiCamManager instance];
    self.wifiCam = [app.wifiCams objectAtIndex:0];
    self.camera = _wifiCam.camera;
    self.gallery = _wifiCam.gallery;
    self.ctrl = _wifiCam.controler;
    
    ICatchFile file = _gallery.videoTable.fileList.at(index);
    self.title = [[NSString alloc] initWithFormat:@"%s", file.getFileName().c_str()];
    /*
     AppLog(@"w:%f, h:%f", _previewThumb.bounds.size.width, _previewThumb.bounds.size.height);
     UIButton *playButton = [[UIButton alloc] initWithFrame:CGRectMake(_previewThumb.bounds.size.width/2-28,
     _previewThumb.bounds.size.height/2-28,
     56, 56)];
     [playButton setImage:[UIImage imageNamed:@"detail_play_normal"] forState:UIControlStateNormal];
     [self.view addSubview:playButton];
     */
    
    
    
    self.previewThumb = [[UIImageView alloc] initWithFrame:self.view.frame];
    _previewThumb.contentMode = UIViewContentModeScaleAspectFit;
    _previewThumb.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _previewThumb.backgroundColor = [UIColor blackColor];
    [self.view addSubview:_previewThumb];
//    [self.view sendSubviewToBack:_previewThumb];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToHideControl:)];
    [self.view addGestureRecognizer:tapGesture];
    
    _previewThumb.image = previewImage;
    _totalSecs = 0;
    _playedSecs = 0;
    
    
    self.semaphore = dispatch_semaphore_create(1);
    self.playbackGroup = dispatch_group_create();
    self.videoPlaybackQ = dispatch_queue_create("WifiCam.GCD.Queue.Playback.Q", 0);
    self.audioQueue = dispatch_queue_create("WifiCam.GCD.Queue.Playback.Audio", 0);
    self.videoQueue = dispatch_queue_create("WifiCam.GCD.Queue.Playback.Video", 0);
    
#ifdef DEBUG1
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    ICatchWificamConfig::getInstance()->enableDumpMediaStream(false, documentsDirectory.UTF8String);
#endif
    
    // Panel
    self.pbCtrlPanel = [[UIView alloc] initWithFrame:CGRectMake(0, self.view.frame.size.height - 52, self.view.frame.size.width, 52)];
    _pbCtrlPanel.backgroundColor = [UIColor blackColor];
    _pbCtrlPanel.alpha = 0.75;
    [self.view addSubview:_pbCtrlPanel];
    
    
    // Buffering bg
    self.bufferingBgView = [[UIView alloc] initWithFrame:CGRectMake(_pbCtrlPanel.frame.origin.x, _pbCtrlPanel.frame.origin.y - 10, _pbCtrlPanel.frame.size.width, 11)];
    _bufferingBgView.backgroundColor = [UIColor darkGrayColor];
    [self.view addSubview:_bufferingBgView];
    
    // Buffering view
    self.bufferingView = [[VideoPlaybackBufferingView alloc] initWithFrame:_bufferingBgView.frame];
    _bufferingView.backgroundColor = [UIColor clearColor];
    _bufferingView.value = 0;
    [self.view insertSubview:_bufferingView aboveSubview:_bufferingBgView];
    
    // Slider
    
    //self.slideController = [[VideoPlaybackSlideController alloc] init];
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        self.slideController = [[VideoPlaybackSlideController alloc] initWithFrame:CGRectMake(_pbCtrlPanel.frame.origin.x-5, _pbCtrlPanel.frame.origin.y - 17, _pbCtrlPanel.frame.size.width+10, 15)];
    } else {
        self.slideController = [[VideoPlaybackSlideController alloc] initWithFrame:CGRectMake(_pbCtrlPanel.frame.origin.x-5, _pbCtrlPanel.frame.origin.y - 12, _pbCtrlPanel.frame.size.width+10, 15)];
    }
    _slideController.minimumTrackTintColor = [UIColor redColor];
    _slideController.maximumTrackTintColor = [UIColor clearColor];
    [_slideController addTarget:self action:@selector(sliderValueChanged:)
               forControlEvents:UIControlEventValueChanged];
    [_slideController addTarget:self action:@selector(sliderTouchDown:)
               forControlEvents:UIControlEventTouchDown];
    [_slideController addTarget:self action:@selector(sliderTouchUpInside:)
               forControlEvents:UIControlEventTouchUpInside];
    [_slideController addTarget:self action:@selector(sliderTouchUpInside:)
               forControlEvents:UIControlEventTouchUpOutside];
    [_slideController addTarget:self action:@selector(sliderTouchUpInside:)
               forControlEvents:UIControlEventTouchCancel];
    _slideController.maximumValue = 0;
    _slideController.minimumValue = 0;
    if ([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) {
        [_slideController setThumbImage:[UIImage imageNamed:@"bullet_white"] forState:UIControlStateNormal];
    }
    _slideController.value = 0;
//    _slideController.continuous = NO;
    [self.view insertSubview:_slideController aboveSubview:_bufferingView];
    _slideController.enabled = NO;
    
    // Playback button
    self.playbackButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_playbackButton addTarget:self action:@selector(playbackButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
    _playbackButton.frame = CGRectMake(10.0, 10.0, 32.0, 32.0);
    [_playbackButton setImage:[UIImage imageNamed:@"videoplayer_control_play"] forState:UIControlStateNormal];
    [_pbCtrlPanel addSubview:_playbackButton];
    
    // Elapsed time
    self.videoPbElapsedTime = [[UILabel alloc] initWithFrame:CGRectMake(_playbackButton.frame.origin.x + 50, _playbackButton.frame.origin.y + 8, 80.0, 16.0)];
    _videoPbElapsedTime.text = @"00:00:00";
    _videoPbElapsedTime.textColor = [UIColor lightTextColor];
    _videoPbElapsedTime.font = [UIFont systemFontOfSize:14.0];
    [_pbCtrlPanel addSubview:_videoPbElapsedTime];
    
    // /
    UILabel *sliceLabel = [[UILabel alloc] initWithFrame:CGRectMake(_videoPbElapsedTime.frame.origin.x + 61, _videoPbElapsedTime.frame.origin.y, 10, 16.0)];
    sliceLabel.text = @"/";
    sliceLabel.textColor = [UIColor lightTextColor];
    sliceLabel.textAlignment = NSTextAlignmentCenter;
    sliceLabel.font = [UIFont systemFontOfSize:12.0];
    [_pbCtrlPanel addSubview:sliceLabel];
    
    // Total time
    self.videoPbTotalTime = [[UILabel alloc] initWithFrame:CGRectMake(sliceLabel.frame.origin.x + 11, _videoPbElapsedTime.frame.origin.y, 80.0, 14.0)];
    _videoPbTotalTime.text = @"--:--:--";
    _videoPbTotalTime.textColor = [UIColor lightTextColor];
    _videoPbTotalTime.font = [UIFont systemFontOfSize:14.0];
    [_pbCtrlPanel addSubview:_videoPbTotalTime];
    
    
    self.deleteButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deleteButtonPressed:)];
    self.actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction  target:self action:@selector(actionButtonPressed:)];
    self.navigationItem.rightBarButtonItems = @[_deleteButton, _actionButton];
    
    
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    delegate.delegate = self;
    
    /*
    UIProgressView *progress = [[UIProgressView alloc] initWithFrame:CGRectMake(_pbCtrlPanel.frame.origin.x, 100, _pbCtrlPanel.frame.size.width, 11)];
    progress.progress = 0.5;
    progress.progressTintColor = [UIColor lightGrayColor];
    progress.trackTintColor = [UIColor darkGrayColor];
    [self.view addSubview:progress];
    
    VideoPlaybackProgressView *slider = [[VideoPlaybackProgressView alloc] initWithFrame:CGRectMake(_pbCtrlPanel.frame.origin.x-5, 99, _pbCtrlPanel.frame.size.width+10, 13)];
    slider.value = 0.2;
    slider.maximumTrackTintColor = [UIColor clearColor];
    slider.minimumTrackTintColor = [UIColor redColor];
    [self.view addSubview:slider];
    */
}


-(void)initControlPanel {
    TRACE();
    _pbCtrlPanel.frame = CGRectMake(0, self.view.frame.size.height - 52, self.view.frame.size.width, 52);
    _bufferingBgView.frame = CGRectMake(_pbCtrlPanel.frame.origin.x, _pbCtrlPanel.frame.origin.y - 10, _pbCtrlPanel.frame.size.width, 11);
    _bufferingView.frame = _bufferingBgView.frame;
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        _slideController.frame = CGRectMake(_pbCtrlPanel.frame.origin.x-5, _pbCtrlPanel.frame.origin.y - 17, _pbCtrlPanel.frame.size.width+10, 15);
    } else {
        _slideController.frame = CGRectMake(_pbCtrlPanel.frame.origin.x-5, _pbCtrlPanel.frame.origin.y - 12, _pbCtrlPanel.frame.size.width+10, 15);
    }
    // Something weird happened on iOS7.
    [self.view bringSubviewToFront:_slideController];
}

-(void)landscapeControlPanel {
    [self initControlPanel];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recoverFromDisconnection)
                                                 name:@"kCameraNetworkConnectedNotification"
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDisconnection)
                                                 name:@"kCameraNetworkDisconnectedNotification"
                                               object:nil];
//    WifiCamSDKEventListener *listener = new WifiCamSDKEventListener(self, @selector(streamCloseCallback));
//    self.streamObserver = [[WifiCamObserver alloc] initWithListener:listener eventType:ICATCH_EVENT_MEDIA_STREAM_CLOSED isCustomized:NO isGlobal:NO];
//    [[SDK instance] addObserver:_streamObserver];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self playbackButtonPressed:self.playbackButton];
    
    
}

- (IBAction)returnBack:(id)sender {
    self.PlaybackRun = NO;
    [self showProgressHUDWithMessage:nil detailsMessage:nil
                                mode:MBProgressHUDModeIndeterminate];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if ((dispatch_semaphore_wait(_semaphore, time) != 0)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:@"Timeout!" showTime:2.0];
            });
        } else {
            if (_played) {
                self.played = ![_ctrl.pbCtrl stop];
                [self removePlaybackObserver];
            }
            [_pbTimer invalidate];
            
            // 避免RTP还没停止就去抓Thumbnail
            [NSThread sleepForTimeInterval:1.0];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                dispatch_semaphore_signal(self.semaphore);
                [_popController dismissPopoverAnimated:YES];
#if USE_SYSTEM_IOS7_IMPLEMENTATION
                [_actionsSheet dismissWithClickedButtonIndex:0 animated:NO];
#else
                [_actionsSheet dismissViewControllerAnimated:NO completion:nil];
#endif
                [self hideProgressHUD:NO];
                [self.navigationController setToolbarHidden:NO];
                [self hideGCDiscreetNoteView:YES];
                [self dismissViewControllerAnimated:YES completion:^{
                    
                }];
            });
        }
    });
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
//    [[SDK instance] removeObserver:_streamObserver];
//    delete _streamObserver.listener;
//    _streamObserver.listener = NULL;
//    self.streamObserver = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    TRACE();
}

-(void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                        duration:(NSTimeInterval)duration {
    [UIView beginAnimations:nil context:nil];
    [UIView setAnimationDuration:0.5];
    switch (toInterfaceOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
//            [self.navigationController setNavigationBarHidden:YES];
//            [[UIApplication sharedApplication] setStatusBarHidden:YES];
            [self landscapeControlPanel];
            break;
        default:
            [self.navigationController setNavigationBarHidden:NO];
            [[UIApplication sharedApplication] setStatusBarHidden:NO];
            if (_controlHidden) {
                _pbCtrlPanel.hidden = NO;
                _bufferingBgView.hidden = NO;
                _bufferingView.hidden = NO;
                _slideController.hidden = NO;
                self.controlHidden = NO;
            }
            [self initControlPanel];
            break;
    }
    _notificationView.center = CGPointMake(self.view.center.x, _notificationView.center.y);
    [UIView commitAnimations];
}

-(void)recoverFromDisconnection
{
    TRACE();
    [self.navigationController popToRootViewControllerAnimated:YES];
    self.played = NO;

    [self playbackButtonPressed:self.playbackButton];
}

-(void)handleDisconnection
{
    TRACE();
    [self stopVideoPb];
//    if (_played) {
//        [self removePlaybackObserver];
//        self.PlaybackRun = NO;
//        self.played = [_ctrl.pbCtrl stop];
//    }
}

#pragma mark - Observer
- (void)addPlaybackObserver
{
    videoPbProgressListener = new VideoPbProgressListener(self);
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_VIDEO_PLAYBACK_CACHING_PROGRESS
                      listener:videoPbProgressListener
                   isCustomize:NO];
    videoPbProgressStateListener = new VideoPbProgressStateListener(self);
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_VIDEO_PLAYBACK_CACHING_CHANGED
                      listener:videoPbProgressStateListener
                   isCustomize:NO];
    videoPbDoneListener = new VideoPbDoneListener(self);
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_VIDEO_STREAM_PLAYING_ENDED
                      listener:videoPbDoneListener
                   isCustomize:NO];
    videoPbServerStreamErrorListener = new VideoPbServerStreamErrorListener(self);
    [_ctrl.comCtrl addObserver:ICATCH_EVENT_SERVER_STREAM_ERROR
                      listener:videoPbServerStreamErrorListener
                   isCustomize:NO];
}

- (void)removePlaybackObserver
{
    if (videoPbProgressListener) {
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_VIDEO_PLAYBACK_CACHING_PROGRESS
                             listener:videoPbProgressListener
                          isCustomize:NO];
        delete videoPbProgressListener; videoPbProgressListener = NULL;
    }
    if (videoPbProgressStateListener) {
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_VIDEO_PLAYBACK_CACHING_CHANGED
                             listener:videoPbProgressStateListener
                          isCustomize:NO];
        delete videoPbProgressStateListener; videoPbProgressStateListener = NULL;
    }
    if (videoPbDoneListener) {
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_VIDEO_STREAM_PLAYING_ENDED
                             listener:videoPbDoneListener
                          isCustomize:NO];
        delete videoPbDoneListener; videoPbDoneListener = NULL;
    }
    if (videoPbServerStreamErrorListener) {
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_SERVER_STREAM_ERROR
                             listener:videoPbServerStreamErrorListener
                          isCustomize:NO];
        delete videoPbServerStreamErrorListener; videoPbServerStreamErrorListener = NULL;
    }
    
}

- (void)updateVideoPbProgress:(double)value
{
    self.bufferingView.value = value/self.totalSecs;
    dispatch_async(dispatch_get_main_queue(), ^{
        [_bufferingView setNeedsDisplay];
    });
}

- (void)updateVideoPbProgressState:(BOOL)caching
{
    if (!_played || _paused) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        if (caching) {
            //[_al pause];
            [self showGCDNoteWithMessage:@"Buffering ..." withAnimated:YES withAcvity:YES];
        } else {
            //[_al play];
            [self hideGCDiscreetNoteView:YES];
        }
    });
}

- (void)stopVideoPb
{
    if (_played) {
        self.PlaybackRun = NO;
        [self showProgressHUDWithMessage:nil detailsMessage:nil
                                    mode:MBProgressHUDModeIndeterminate];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
            if (dispatch_semaphore_wait(_semaphore, time) != 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self showProgressHUDNotice:@"Timeout!" showTime:2.0];
                });
            } else {
                self.played = ![_ctrl.pbCtrl stop];
                [self removePlaybackObserver];
                dispatch_async(dispatch_get_main_queue(), ^{
                    _deleteButton.enabled = YES;
                    _actionButton.enabled = YES;
                    
                    dispatch_semaphore_signal(self.semaphore);
                    [_playbackButton setImage:[UIImage imageNamed:@"videoplayer_control_play"]
                                     forState:UIControlStateNormal];
                    [_pbTimer invalidate];
                    _videoPbElapsedTime.text = @"00:00:00";
                    _bufferingView.value = 0; [_bufferingView setNeedsDisplay];
                    self.curVideoPTS = 0;
                    self.playedSecs = 0;
                    _slideController.value = 0;
                    _slideController.enabled = NO;
                    [self hideProgressHUD:YES];
                });
            }
        });
    }
    
}

- (void)showServerStreamError
{
    AppLog(@"server error!");
    self.exceptionHappen = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDNotice:NSLocalizedString(@"CameraPbError", nil)
                           showTime:2.0];
    });
    [self stopVideoPb];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if([keyPath isEqualToString:@"downloadedPercent"]) {
        [self updateProgressHUDWithMessage:nil detailsMessage:nil];
    }
}

#pragma mark - Action Progress

- (MBProgressHUD *)progressHUD {
    if (!_progressHUD) {
        _progressHUD = [[MBProgressHUD alloc] initWithView:self.view.window];
        _progressHUD.minSize = CGSizeMake(120, 120);
        _progressHUD.minShowTime = 1;
        _progressHUD.dimBackground = YES;
        
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
    self.navigationController.navigationBar.userInteractionEnabled = YES;
}

- (void)showProgressHUDWithMessage:(NSString *)message
                    detailsMessage:(NSString *)dMessage
                              mode:(MBProgressHUDMode)mode{
    if (_progressHUD.alpha == 0 ) {
        self.progressHUD.labelText = message;
        self.progressHUD.detailsLabelText = dMessage;
        self.progressHUD.mode = mode;
        [self.progressHUD show:YES];
        
        self.navigationController.navigationBar.userInteractionEnabled = NO;
    }
}

- (void)showProgressHUDCompleteMessage:(NSString *)message {
    if (message) {
        if (self.progressHUD.isHidden) [self.progressHUD show:YES];
        self.progressHUD.labelText = message;
        self.progressHUD.detailsLabelText = nil;
        self.progressHUD.mode = MBProgressHUDModeCustomView;
        [self.progressHUD hide:YES afterDelay:1.0];
    } else {
        [self.progressHUD hide:YES];
    }
    self.navigationController.navigationBar.userInteractionEnabled = YES;
}

- (void)updateProgressHUDWithMessage:(NSString *)message
                      detailsMessage:(NSString *)dMessage {
    if (message) {
        self.progressHUD.labelText = message;
    }
    if (dMessage) {
        self.progressHUD.detailsLabelText = dMessage;
    }
    self.progressHUD.progress = _downloadedPercent / 100.0;
}

- (void)hideProgressHUD:(BOOL)animated {
    [self.progressHUD hide:animated];
    self.navigationController.navigationBar.userInteractionEnabled = YES;
    self.navigationController.toolbar.userInteractionEnabled = YES;
}

#pragma mark - VideoPB
- (IBAction)sliderValueChanged:(VideoPlaybackSlideController *)slider {
    TRACE();
    /*
    if (_played) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.seeking = YES;
            BOOL retVal = [_ctrl.pbCtrl seek:slider.value];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (retVal) {
                    AppLog(@"Seek succeed.");
                    self.playedSecs = slider.value;
                    self.curVideoPTS = _playedSecs;
                    _videoPbElapsedTime.text = [Tool translateSecsToString:_playedSecs];
                } else {
                    AppLog(@"Seek failed.");
                    [self showProgressHUDNotice:@"Seek failed" showTime:2.0];
                }
                self.pbTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                              target  :self
                                                              selector:@selector(updateTimeInfo:)
                                                              userInfo:nil
                                                              repeats :YES];
            });
            self.seeking = NO;
        });
    }
     */

    _videoPbElapsedTime.text = [Tool translateSecsToString:slider.value];

}

- (IBAction)sliderTouchDown:(id)sender {
    TRACE();
    if (_played) {
        [_pbTimer invalidate];
        [self hideGCDiscreetNoteView:YES];
    }
}

- (IBAction)sliderTouchUpInside:(VideoPlaybackSlideController *)slider {
    TRACE();
    if (_played) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            self.seeking = YES;
            BOOL retVal = [_ctrl.pbCtrl seek:slider.value];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (retVal) {
                    AppLog(@"Seek succeed.");
                    self.playedSecs = slider.value;
                    self.curVideoPTS = _playedSecs;
                    _videoPbElapsedTime.text = [Tool translateSecsToString:_playedSecs];
                } else {
                    AppLog(@"Seek failed.");
                    [self showProgressHUDNotice:@"Seek failed" showTime:2.0];
                }
                self.pbTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                              target  :self
                                                              selector:@selector(updateTimeInfo:)
                                                              userInfo:nil
                                                              repeats :YES];
                self.seeking = NO;
            });
        });
    }
}

- (void)updateTimeInfo:(NSTimer *)sender {
    if (!_seeking) {
        self.playedSecs = _curVideoPTS;
        
        float sliderPercent = _playedSecs/_totalSecs; // slider value
        dispatch_async(dispatch_get_main_queue(), ^{
            _videoPbElapsedTime.text = [Tool translateSecsToString:_playedSecs];
//            AppLog(@"_playedSecs: %f", _playedSecs);
            _slideController.value = [@(_playedSecs) floatValue];
            
            if (sliderPercent > _bufferingView.value) {
                _bufferingView.value = sliderPercent;
                [_bufferingView setNeedsDisplay];
            }
        });
    } else {
        AppLog(@"seeking");
    }
#if RUN_DEBUG
    if (++_times == 200) {
        AppLog(@"Time Interval: %fs, getDataTime: %fms, \nstotalElapse: %fms, totalDuration: %fms, D-value: %fms, times: %d", _times * 0.1, _totalElapse1/_times1, _totalElapse/_times1, _totalDuration/_times1, _totalElapse/_times1 - _totalElapse1/_times1, _times1/*_totalDuration - _totalElapse*/);
        _times = 0;
        _times1 = 0;
        _totalDuration = 0.0;
        _totalElapse = 0.0;
        _totalElapse1 = 0.0;
    }
#else
#endif
}

- (IBAction)playbackButtonPressed:(UIButton *)pbButton {
    [self showProgressHUDWithMessage:nil
                      detailsMessage:nil
                                mode:MBProgressHUDModeIndeterminate];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if(dispatch_semaphore_wait(self.semaphore, time) != 0)  {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDNotice:@"Timeout!" showTime:2.0];
            });
        } else {
            dispatch_semaphore_signal(self.semaphore);
            
            if (_played && !_paused) {
                // Pause
                AppLog(@"call pause");
                self.paused = [_ctrl.pbCtrl pause];
                dispatch_async(dispatch_get_main_queue(), ^{
                    _deleteButton.enabled = YES;
                    _actionButton.enabled = YES;
                    if (_paused) {
                        [_pbTimer invalidate];
                        [pbButton setImage:[UIImage imageNamed:@"videoplayer_control_play"]
                                  forState:UIControlStateNormal];
                    }
                    [self hideProgressHUD:YES];
                });
            } else {
                self.PlaybackRun = YES;
                //if (_playedSecs <= 0) {
                if (!_played) {
                    // Play
                    dispatch_async(_videoPlaybackQ, ^{
                        ICatchFile file = _gallery.videoTable.fileList.at(index);
                        AppLog(@"call play");
                        self.totalSecs = [_ctrl.pbCtrl play:&file];
                        if (_totalSecs <= 0) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [self showProgressHUDNotice:@"Failed to play" showTime:2.0];
                            });
                            return;
                        }
                        _slideController.enabled = YES;
                        self.played = YES;
                        self.paused = NO;
                        self.exceptionHappen = NO;
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            _deleteButton.enabled = NO;
                            _actionButton.enabled = NO;
                            [pbButton setImage:[UIImage imageNamed:@"videoplayer_control_pause"]
                                      forState:UIControlStateNormal];
                            _videoPbElapsedTime.text = @"00:00:00";
                            _videoPbTotalTime.text = [Tool translateSecsToString:_totalSecs];
                            _slideController.maximumValue = _totalSecs;
                            [self addPlaybackObserver];
                            if (self.view.frame.size.width < self.view.frame.size.height) {
                                [self initControlPanel];
                            } else {
                                [self landscapeControlPanel];
                            }
                            self.pbTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                          target  :self
                                                                          selector:@selector(updateTimeInfo:)
                                                                          userInfo:nil
                                                                          repeats :YES];
                            [self hideProgressHUD:YES];
                            [self showGCDNoteWithMessage:@"Buffering ..."
                                            withAnimated:YES withAcvity:YES];
                        });
                        
                        if ([_ctrl.pbCtrl audioPlaybackStreamEnabled]) {
                            dispatch_group_async(_playbackGroup, _audioQueue, ^{[self playAudio1];});
                        } else {
                            AppLog(@"Playback doesn't contains audio.");
                        }
                        if ([_ctrl.pbCtrl videoPlaybackStreamEnabled]) {
                            dispatch_group_async(_playbackGroup, _videoQueue, ^{[self playVideo];});
                        } else {
                            AppLog(@"Playback doesn't contains video.");
                        }

                        dispatch_group_notify(_playbackGroup, _videoPlaybackQ, ^{
                            
                        });
                        
                    });
                } else {
                    // Resume
                    AppLog(@"call resume");
                    self.paused = ![_ctrl.pbCtrl resume];
                    if (!_paused) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            _deleteButton.enabled = NO;
                            _actionButton.enabled = NO;
                            if (![_pbTimer isValid]) {
                                self.pbTimer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                                              target  :self
                                                                              selector:@selector(updateTimeInfo:)
                                                                              userInfo:nil
                                                                              repeats :YES];
                            }
                            [pbButton setImage:[UIImage imageNamed:@"videoplayer_control_pause"]
                                      forState:UIControlStateNormal];
                            [self hideProgressHUD:YES];
                        });
                    }
                }
            }
            
        }
    });
}

- (void)playVideo
{
    UIImage *receivedImage = nil;
//    NSTimeInterval oneMinute = 0;
//    __block uint frameCount = 0;
    
    while (_PlaybackRun/* && _played && !_paused*/) {
        @autoreleasepool {
#if RUN_DEBUG
            NSDate *begin = [NSDate date];
            WifiCamAVData *wifiCamData = [_ctrl.propCtrl prepareDataForPlaybackVideoFrame];
            
            /*
             if (_exceptionHappen) {
             break;
             }
             if ((wifiCamData.state != ICH_SUCCEED) && (wifiCamData.state != ICH_TRY_AGAIN)) {
             if ((wifiCamData.state != ICH_VIDEO_STREAM_CLOSED)
             && (wifiCamData.state != ICH_AUDIO_STREAM_CLOSED)) {
             AppLog(@"wifiCamData.state: %d", wifiCamData.state);
             
             } else {
             AppLog(@"Exception happened!");
             self.exceptionHappen = YES;
             }
             break;
             }
             */
            
            
            if (wifiCamData.data.length > 0) {
                self.curVideoPTS = wifiCamData.time;
                receivedImage = [[UIImage alloc] initWithData:wifiCamData.data];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (receivedImage) {
                        _previewThumb.image = receivedImage;
                    }
                });
                receivedImage = nil;
                //            ++frameCount;
            }
            NSDate *end = [NSDate date];
            NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
            AppLog(@"[V]Get %lu, elapse: %f", (unsigned long)wifiCamData.data.length, elapse * 1000);
#else
            if (_paused) {
                [NSThread sleepForTimeInterval:1.0];
                continue;
            }
            
            WifiCamAVData *wifiCamData = [_ctrl.propCtrl prepareDataForPlaybackVideoFrame];
            
            if (wifiCamData.data.length > 0) {
                self.curVideoPTS = wifiCamData.time;
                receivedImage = [[UIImage alloc] initWithData:wifiCamData.data];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (receivedImage) {
                        _previewThumb.image = receivedImage;
                    }
                });
                receivedImage = nil;
            }
#endif
            //        NSDate *end = [NSDate date];
            //        NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
            //        oneMinute += elapse;
            //        if (oneMinute >= 0.99) {
            //            AppLog(@"[MJPG] frameCount: %d", frameCount);
            //            frameCount = 0;
            //            oneMinute = 0;
            //        }
        }
    }
    AppLog(@"quit video");
}

- (void)playAudio1
{
    NSMutableData *audioBuffer = [[NSMutableData alloc] init];

    ICatchAudioFormat format = [_ctrl.propCtrl retrievePlaybackAudioFormat];
    AppLog(@"Codec:%x, freq: %d, chl: %d, bit:%d", format.getCodec(), format.getFrequency(), format.getNChannels(), format.getSampleBits());
    
    _pcmPl = [[PCMDataPlayer alloc] initWithFreq:format.getFrequency() channel:format.getNChannels() sampleBit:format.getSampleBits()];
    if (!_pcmPl) {
        AppLog(@"Init audioQueue failed.");
        return;
    }
    
    while (_PlaybackRun) {
        @autoreleasepool {
            if (_paused) {
                [NSThread sleepForTimeInterval:1.0];
                continue;
            }
            
            NSDate *begin = [NSDate date];
            [audioBuffer setLength:0];
            
            for (int i = 0; i < 4; i++) {
                NSDate *begin1 = [NSDate date];
                ICatchFrameBuffer *buff = [_ctrl.propCtrl prepareDataForPlaybackAudioTrack1];
                NSDate *end1 = [NSDate date];
                NSTimeInterval elapse1 = [end1 timeIntervalSinceDate:begin1] * 1000;
                RunLog(@"getNextAudioFrame time: %fms", elapse1);
                _totalElapse1 += elapse1;
                
                if (buff != NULL) {
                    [audioBuffer appendBytes:buff->getBuffer() length:buff->getFrameSize()];
                    if (audioBuffer.length > MIN_SIZE_PER_FRAME) {
                        break;
                    }
                }
            }
            
            if (audioBuffer.length > 0) {
                [_pcmPl play:(void *)audioBuffer.bytes length:audioBuffer.length];
            }
            
            NSDate *end = [NSDate date];
            NSTimeInterval elapse = [end timeIntervalSinceDate:begin] * 1000;
            float duration = audioBuffer.length/4.0/format.getFrequency() * 1000;
            RunLog(@"[A]Get %lu, elapse: %fms, duration: %fms", (unsigned long)audioBuffer.length, elapse, duration);
            _totalElapse += elapse;
            _totalDuration += duration;
            _times1 ++;
        }
    }
    
    if (_pcmPl) {
        [_pcmPl stop];
    }
    _pcmPl = nil;
    
    AppLog(@"quit audio");
}

- (void)playAudio
{
    NSMutableData *audioDataBuffer = [[NSMutableData alloc] init];
    
    self.al = [[HYOpenALHelper alloc] init];
    ICatchAudioFormat format = [_ctrl.propCtrl retrievePlaybackAudioFormat];
    AppLog(@"Codec:%x, freq: %d, chl: %d, bit:%d", format.getCodec(), format.getFrequency(), format.getNChannels(), format.getSampleBits());

    if (![_al initOpenAL:format.getFrequency() channel:format.getNChannels() sampleBit:format.getSampleBits()]) {
        AppLog(@"Init openAL failed.");
        return;
    }
    
    while (_PlaybackRun) {
        @autoreleasepool {
            if (_paused) {
                [NSThread sleepForTimeInterval:1.0];
                continue;
            }
            
            NSDate *begin = [NSDate date];
            [audioDataBuffer setLength:0];
            
            for (int i = 0; i < 4; i++) {
                ICatchFrameBuffer *buf = [_ctrl.propCtrl prepareDataForPlaybackAudioTrack1];
                if (buf != NULL) {
                    [audioDataBuffer appendBytes:buf->getBuffer() length:buf->getFrameSize()];
                }
            }
            
            NSDate *end1 = [NSDate date];
            AppLog(@"getNextAudioFrame time: %fms", [end1 timeIntervalSinceDate:begin] * 1000);
            
            if (audioDataBuffer.length > 0) {
                [_al insertPCMDataToQueue:audioDataBuffer.bytes size:audioDataBuffer.length];
                if ([_al getInfo]) {
                    [_al play];
                }
            }
            
            NSDate *end = [NSDate date];
            NSTimeInterval elapse = [end timeIntervalSinceDate:begin] * 1000;
            float duration = audioDataBuffer.length/4.0/format.getFrequency() * 1000;
            AppLog(@"[A]Get %lu, elapse: %fms, duration: %fms, setData: %fms", (unsigned long)audioDataBuffer.length, elapse, duration, [end timeIntervalSinceDate:end1] * 1000);
            _totalElapse += elapse;
            _totalDuration += duration;
        }
    }

    AppLog(@"quit audio");
    [_al clean];
    self.al = nil;
}
//- (void)playAudio
//{
////    NSData *audioBufferData = nil;
//    double audioT = 0.0;
//    double averageT = 0.0;
//    int times = 4;
//    WifiCamAVData *audioBufferData = nil;
//    NSMutableData *audioBuffer = [[NSMutableData alloc] init];
//    self.al = [[HYOpenALHelper alloc] init];
//    ICatchAudioFormat format = [_ctrl.propCtrl retrievePlaybackAudioFormat];
//    AppLog(@"Codec:%x, freq: %d, chl: %d, bit:%d", format.getCodec(), format.getFrequency(), format.getNChannels(), format.getSampleBits());
//    
//    if (![_al initOpenAL:format.getFrequency() channel:format.getNChannels() sampleBit:format.getSampleBits()]) {
//        AppLog(@"Init openAL failed.");
//        return;
//    }
//    
//    while (_PlaybackRun/* && _played && !_paused && !_exceptionHappen*/) {
//        NSDate *begin = [NSDate date];
//        
//        int count = [_al getInfo];
//        if(count < times + 1) {
//            if (count == 1) {
//                [_al play];
//            }
//           
//            audioT = 0.0;
//            [audioBuffer setLength:0];
//            
//            for (int i=0; i<times; ++i) {
//                
////                NSDate *begin = [NSDate date];
//                audioBufferData = [_ctrl.propCtrl prepareDataForPlaybackAudioTrack];
////                NSDate *end = [NSDate date];
////                NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
////                AppLog(@"[A]Get %lu, elapse: %f", (unsigned long)audioBufferData.data.length, elapse);
//                
//                if (audioBufferData) {
//                    audioT += audioBufferData.time;
//                    [audioBuffer appendData:audioBufferData.data];
//                }
//            }
//            
//            if(audioBuffer.length>0) {
//                [_al insertPCMDataToQueue:audioBuffer.bytes
//                                     size:audioBuffer.length];
//            }
//            averageT = audioT/times;
//            
//        } else {
////            [_al play];
//            if ((_curVideoPTS - averageT <= 0.15 || averageT - _curVideoPTS <= 0.15 ) && _curVideoPTS != 0) {
////                [NSThread sleepForTimeInterval:0.005];
//                [_al play];
//            }
//            
////            if (averageT - _curVideoPTS >= 0.15 && _curVideoPTS != 0) {
////                [_al pause];
////            }
//            else if (averageT - _curVideoPTS > 0.15 && _curVideoPTS != 0){
////                [NSThread sleepForTimeInterval:0.002];
//                times ++;
//                [_al pause];
//            } else if (_curVideoPTS - averageT > 0.15 && _curVideoPTS != 0) {
//                times --;
//            }
//        }
//        
//        NSDate *end = [NSDate date];
//        NSTimeInterval elapse = [end timeIntervalSinceDate:begin] * 1000;
//        float duration = audioBuffer.length/4.0/format.getFrequency() * 1000;
//        AppLog(@"[A]Get %lu, elapse: %fms, duration: %fms", (unsigned long)audioBuffer.length, elapse, duration);
//        _totalElapse += elapse;
//        _totalDuration += duration;
//    }
//    AppLog(@"quit audio, %d, %d, %d", _played, _paused, _exceptionHappen);
//    
////        NSDate *begin = [NSDate date];
////        WifiCamAVData *wifiCamData = [_ctrl.propCtrl prepareDataForPlaybackAudioTrack];
////        NSDate *end = [NSDate date];
////        NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
////        AppLog(@"[A]Get %lu, elapse: %f", (unsigned long)wifiCamData.data.length, elapse);
////        
////        if (wifiCamData.data.length > 0) {
////            [_al insertPCMDataToQueue:wifiCamData.data.bytes
////                                 size:wifiCamData.data.length];
////            if((wifiCamData.time >= _curVideoPTS - 0.25 && _curVideoPTS != 0) ||
////               (wifiCamData.time <= _curVideoPTS + 0.25 && _curVideoPTS != 0)) {
////                [_al play];
////            } else {
////                [_al pause];
////            }
////        }
////        
////    }
////    AppLog(@"quit audio, %d, %d, %d", _played, _paused, _exceptionHappen);
//    
//    [_al clean];
//    self.al = nil;
//
//}

- (IBAction)deleteButtonPressed:(UIBarButtonItem *)sender {
    if (_played && !_paused) {
        [self playbackButtonPressed:_playbackButton];
    }
    if (_popController.popoverVisible) {
        [_popController dismissPopoverAnimated:YES];
    }
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        UIViewController *vc = [[UIViewController alloc] init];
        UIButton *testButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 260.0f, 47.0f)];
        [testButton setTitle:NSLocalizedString(@"SureDelete", @"") forState:UIControlStateNormal];
        [testButton setBackgroundImage:[[UIImage imageNamed:@"iphone_delete_button.png"] stretchableImageWithLeftCapWidth:8.0f
                                                                                                             topCapHeight:0.0f]
                              forState:UIControlStateNormal];
        [testButton addTarget:self action:@selector(deleteDetail:) forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:testButton];
        
        UIPopoverController *popController = [[UIPopoverController alloc] initWithContentViewController:vc];
        popController.popoverContentSize = CGSizeMake(260.0f, 47.0f);
        _popController = popController;
        [_popController presentPopoverFromBarButtonItem:_deleteButton
                               permittedArrowDirections:UIPopoverArrowDirectionAny
                                               animated:YES];
    } else {
        
#if USE_SYSTEM_IOS7_IMPLEMENTATION
        _actionsSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                      destructiveButtonTitle:NSLocalizedString(@"SureDelete", @"")
                                           otherButtonTitles:nil, nil];
        _actionsSheet.tag = ACTION_SHEET_DELETE_ACTIONS;
        [_actionsSheet showFromBarButtonItem:sender animated:YES];
#else
        _actionsSheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        [_actionsSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil]];
        [_actionsSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"SureDelete", @"") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            [self deleteDetail:self];
        }]];
        
        [self presentViewController:_actionsSheet animated:YES completion:nil];
#endif
        
    }
}

- (IBAction)deleteDetail:(id)sender
{
    if ([sender isKindOfClass:[UIButton self]]) {
        [_popController dismissPopoverAnimated:YES];
    }
    
    [self showProgressHUDWithMessage:NSLocalizedString(@"Deleting", nil) detailsMessage:nil mode:MBProgressHUDModeIndeterminate];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL deleteResult = NO;
        
        [self stopVideoPb];
        [NSThread sleepForTimeInterval:0.5]; // mark - 20170817[BSP-1267]
        if([_delegate respondsToSelector:@selector(videoPlaybackController:deleteVideoAtIndex:)]) {
            deleteResult = [self.delegate videoPlaybackController:self deleteVideoAtIndex:index];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (deleteResult) {
                [self hideProgressHUD:YES];
//                [self.navigationController popToRootViewControllerAnimated:YES];
                [self dismissViewControllerAnimated:YES completion:nil];
            } else {
                [self showProgressHUDNotice:NSLocalizedString(@"DeleteError", nil) showTime:2.0];
            }
            
        });
        
    });
}
-(NSString *)makeupNoDownloadMessageWithSize:(unsigned long long)sizeInKB
{
    AppLog(@"%s", __func__);
    NSString *message = nil;
    NSString *humanDownloadFileSize = [_ctrl.comCtrl translateSize:sizeInKB];
    double freeDiscSpace = [_ctrl.comCtrl freeDiskSpaceInKBytes];
    NSString *leftSpace = [_ctrl.comCtrl translateSize:freeDiscSpace];
    message = [NSString stringWithFormat:@"%@\n Download:%@, Free:%@", NSLocalizedString(@"NotEnoughSpaceError", nil), humanDownloadFileSize, leftSpace];
    message = [message stringByAppendingString:@"\n Needs double free space"];
    return message;
}

- (IBAction)actionButtonPressed:(UIBarButtonItem *)sender {
    if (_played && !_paused) {
        [self playbackButtonPressed:_playbackButton];
    }
    
    if (_popController.popoverVisible) {
        [_popController dismissPopoverAnimated:YES];
    }
    bool cannotDownload =0;
    ICatchFile file = _gallery.videoTable.fileList.at(index);
    unsigned long long size = file.getFileSize() >> 20;
    double downloadTime = ((double)size)/60;
    //downloadTime = MAX(1, downloadTime);
    double freeDiscSpace = [_ctrl.comCtrl freeDiskSpaceInKBytes];
    double totaldownloadSize =file.getFileSize()/1024; // convert o KBytes
    NSString *confrimButtonTitle = nil;
    NSString *message = nil;
    if (totaldownloadSize < freeDiscSpace/2.0) {
        message = NSLocalizedString(@"DownloadConfirmMessage", nil);
        message = [message stringByReplacingOccurrencesOfString:@"%1"
                                                     withString:[[NSString alloc] initWithFormat:@"%d", 1]];
        message = [message stringByReplacingOccurrencesOfString:@"%2"
                                                     withString:[[NSString alloc] initWithFormat:@"%.2f", downloadTime]];
        confrimButtonTitle = NSLocalizedString(@"SureDownload", @"");
        cannotDownload = 0;
    } else {
        message = [self makeupNoDownloadMessageWithSize:totaldownloadSize];
        cannotDownload = 1;
    }
    
    
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        MpbPopoverViewController *contentViewController = [[MpbPopoverViewController alloc] initWithNibName:@"MpbPopover" bundle:nil];
        contentViewController.msg = message;
        
        if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
            contentViewController.msgColor = [UIColor blackColor];
        } else {
            contentViewController.msgColor = [UIColor whiteColor];
        }
        
        UIButton *downloadConfirmButton = [[UIButton alloc] initWithFrame:CGRectMake(5.0f, 120.0f, 260.0f, 47.0f)];
        [downloadConfirmButton setTitle:confrimButtonTitle
                               forState:UIControlStateNormal];
        [downloadConfirmButton setBackgroundImage:[[UIImage imageNamed:@"iphone_delete_button.png"] stretchableImageWithLeftCapWidth:8.0f topCapHeight:0.0f]
                                         forState:UIControlStateNormal];
        [downloadConfirmButton addTarget:self action:@selector(downloadDetail:) forControlEvents:UIControlEventTouchUpInside];
        [contentViewController.view addSubview:downloadConfirmButton];
        
        UIPopoverController *popController = [[UIPopoverController alloc] initWithContentViewController:contentViewController];
        popController.popoverContentSize = CGSizeMake(270.0f, 170.0f);
        _popController = popController;
        [_popController presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        NSString *msg = message;
        
#if USE_SYSTEM_IOS7_IMPLEMENTATION
        _actionsSheet = [[UIActionSheet alloc] initWithTitle:msg
                                                    delegate:self
                                           cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                      destructiveButtonTitle:confrimButtonTitle
                                           otherButtonTitles:nil, nil];
        _actionsSheet.tag = ACTION_SHEET_DOWNLOAD_ACTIONS;
        //[self.sheet showInView:self.view];
        //[self.sheet showInView:[UIApplication sharedApplication].keyWindow];
        [_actionsSheet showFromBarButtonItem:_actionButton animated:YES];
#else
        _actionsSheet = [UIAlertController alertControllerWithTitle:msg message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        [_actionsSheet addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:nil]];
        if( ! cannotDownload ){
            [_actionsSheet addAction:[UIAlertAction actionWithTitle:confrimButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                [self downloadDetail:self];
            }]];
        }
        [self presentViewController:_actionsSheet animated:YES completion:nil];
#endif
        
    }
}

- (IBAction)downloadDetail:(id)sender
{
    dispatch_queue_t downloadQueue = dispatch_queue_create("WifiCam.GCD.Queue.Playback.Donwload", 0);
    
    if ([sender isKindOfClass:[UIButton self]]) {
        [_popController dismissPopoverAnimated:YES];
    }
    
    [self addObserver:self
           forKeyPath:@"downloadedPercent"
              options:NSKeyValueObservingOptionNew
              context:nil];
    [self showProgressHUDWithMessage:NSLocalizedString(@"DownloadingTitle", @"")
                      detailsMessage:nil
                                mode:MBProgressHUDModeAnnularDeterminate];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [_ctrl.fileCtrl resetBusyToggle:YES];
        
        UIApplication  *app = [UIApplication sharedApplication];
        UIBackgroundTaskIdentifier downloadTask = [app beginBackgroundTaskWithExpirationHandler:^{
            AppLog(@"-->Expirationed.");
            NSArray *oldNotifications = [app scheduledLocalNotifications];
            // Clear out the old notification before scheduling a new one
            if ([oldNotifications count] > 5) {
                [app cancelAllLocalNotifications];
            }
            
            UILocalNotification *alarm = [[UILocalNotification alloc] init];
            if (alarm) {
                alarm.fireDate = [NSDate date];
                alarm.timeZone = [NSTimeZone defaultTimeZone];
                alarm.repeatInterval = 0;
                NSString *str = [[NSString alloc] initWithFormat:@"App is about to exit .Please bring it to foreground to continue dowloading."];
                alarm.alertBody = str;
                alarm.soundName = UILocalNotificationDefaultSoundName;
                
                [app scheduleLocalNotification:alarm];
            }
        }];
        
        BOOL downloadResult = YES;
        // Download percent!
        ICatchFile file = _gallery.videoTable.fileList.at(index);
        ICatchFile *pFile = &file;
        dispatch_async(downloadQueue, ^{
            while (_downloadedPercent < 100) {
                @autoreleasepool {
                    self.downloadedPercent = [_ctrl.fileCtrl requestDownloadedPercent:pFile];
                }
            }
        });
        // Downloading...
        downloadResult = [_ctrl.fileCtrl downloadFile:pFile];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeObserver:self forKeyPath:@"downloadedPercent"];
            NSString *message = nil;
            if (downloadResult) {
                message = NSLocalizedString(@"Download complete", nil);
            } else {
                //SaveError
                message = NSLocalizedString(@"SaveError", nil);
            }
            [self showProgressHUDCompleteMessage:message];
        });
        
        [_ctrl.fileCtrl resetBusyToggle:NO];
        [[UIApplication sharedApplication] endBackgroundTask:downloadTask];
        //downloadTask = UIBackgroundTaskInvalid;
    });
}

#pragma mark - GCDiscreetNotificationView
-(GCDiscreetNotificationView *)notificationView {
    if (!_notificationView) {
        _notificationView = [[GCDiscreetNotificationView alloc] initWithText:nil
                                                                showActivity:NO
                                                          inPresentationMode:GCDiscreetNotificationViewPresentationModeTop
                                                                      inView:self.view];
    }
    return _notificationView;
}

- (void)showGCDNoteWithMessage:(NSString *)message
                  withAnimated:(BOOL)animated
                    withAcvity:(BOOL)activity{
    
    [self.notificationView setTextLabel:message];
    [self.notificationView setShowActivity:activity];
    [self.notificationView show:animated];
    
}

- (void)showGCDNoteWithMessage:(NSString *)message
                       andTime:(NSTimeInterval) timeInterval
                    withAcvity:(BOOL)activity{
    [self.notificationView setTextLabel:message];
    [self.notificationView setShowActivity:activity];
    [self.notificationView showAndDismissAfter:timeInterval];
    
}

- (void)hideGCDiscreetNoteView:(BOOL)animated {
    [self.notificationView hide:animated];
}

#pragma mark - Gesture
- (IBAction)tapToHideControl:(UITapGestureRecognizer *)sender {
    TRACE();
//    if (UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation)) {
    if (self.view.frame.size.width < self.view.frame.size.height) {
        return;
    }
    if (_controlHidden) {
        [self.navigationController setNavigationBarHidden:NO];
//        [[UIApplication sharedApplication] setStatusBarHidden:NO];
        _pbCtrlPanel.hidden = NO;
        _bufferingBgView.hidden = NO;
        _bufferingView.hidden = NO;
        _slideController.hidden = NO;
        [self landscapeControlPanel];
    } else {
        [self.navigationController setNavigationBarHidden:YES];
//        [[UIApplication sharedApplication] setStatusBarHidden:YES];
        _pbCtrlPanel.hidden = YES;
        _bufferingBgView.hidden = YES;
        _bufferingView.hidden = YES;
        _slideController.hidden = YES;
    }
    self.controlHidden = !_controlHidden;
}

- (IBAction)panToFastMove:(UIPanGestureRecognizer *)sender {
    AppLog(@"%s", __func__);
    
}

//-(BOOL)prefersStatusBarHidden {
//    if (_controlHidden) {
//        return NO;
//    } else {
//        return YES;
//    }
//}

#if USE_SYSTEM_IOS7_IMPLEMENTATION

#pragma mark - UIActionSheetDelegate
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    _actionsSheet = nil;
    
    switch (actionSheet.tag) {
        case ACTION_SHEET_DOWNLOAD_ACTIONS:
            if (buttonIndex == actionSheet.destructiveButtonIndex) {
                [self downloadDetail:self];
            }
            break;
            
        case ACTION_SHEET_DELETE_ACTIONS:
            if (buttonIndex == actionSheet.destructiveButtonIndex) {
                [self deleteDetail:self];
            }
            break;
            
        default:
            break;
    }
    
}
#else
#endif

#pragma mark - UIPopoverControllerDelegate
-(void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    _popController = nil;
}

-(void)applicationDidEnterBackground:(UIApplication *)application {
    if (_played) {
        self.PlaybackRun = NO;
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        dispatch_async(dispatch_get_main_queue(), ^{
            if ((dispatch_semaphore_wait(_semaphore, time) != 0)) {
                AppLog(@"Timeout!");
            } else {
                dispatch_semaphore_signal(self.semaphore);
                
                self.played = ![_ctrl.pbCtrl stop];
                [self removePlaybackObserver];
                [_pbTimer invalidate];
                [[SDK instance] destroySDK];
            }
        });
    }
}


#pragma mark -
/*-(void)streamCloseCallback {
    self.PlaybackRun = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDNotice:@"Streaming is stopped unexpected." showTime:2.0];
    });
}*/
@end
