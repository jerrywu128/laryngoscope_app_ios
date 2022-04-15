//
//  ViewController_ViewControllerPrivate.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-2-28.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "HYOpenALHelper.h"
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>
#import "AppDelegate.h"
#import "SettingViewController.h"
#import "MBProgressHUD.h"
#import "CustomIOS7AlertView.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>
#import <ImageIO/ImageIO.h>
#import "WifiCamManager.h"
#import "WifiCamControl.h"
#include "UtilsMacro.h"
#include "PreviewSDKEventListener.h"
#import "Camera.h"
#include "WifiCamSDKEventListener.h"
#import "GCDiscreetNotificationView.h"
#import <VideoToolbox/VideoToolbox.h>
#import <malloc/malloc.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

enum SettingState{
  SETTING_DELAY_CAPTURE = 0,
  SETTING_STILL_CAPTURE,
  SETTING_VIDEO_CAPTURE
};

typedef NS_ENUM(NSUInteger,IQMode){
  NONE = 0,
  BRIGHTNESS,
  SATURATION,
  HUE,
  WHTIE_BALANCE,
  BLC
};

//test

//end

@interface ViewController ()
<
UIAlertViewDelegate,
UITableViewDelegate,
UITableViewDataSource,
AppDelegateProtocol,
MWPhotoBrowserDelegate,
SettingDelegate
>

@property(weak, nonatomic) IBOutlet UIImageView *preview;
@property(nonatomic) IBOutlet UIView *h264View;
@property(weak, nonatomic) IBOutlet UIButton *deviceInfoButton;
@property(weak, nonatomic) IBOutlet UIButton    *cameraToggle;
@property(weak, nonatomic) IBOutlet UIButton    *videoToggle;
@property(weak, nonatomic) IBOutlet UIButton    *timelapseToggle;
@property(weak, nonatomic) IBOutlet UIButton *zoomOutButton;
@property(weak, nonatomic) IBOutlet UIButton *zoomInButton;
@property(weak, nonatomic) IBOutlet UILabel *zoomValueLabel;
@property(weak, nonatomic) IBOutlet UISlider *zoomSlider;
@property(weak, nonatomic) IBOutlet UIButton    *mpbToggle;
@property(weak, nonatomic) IBOutlet UIImageView *batteryState;
@property(weak, nonatomic) IBOutlet UIImageView *awbLabel;
@property(weak, nonatomic) IBOutlet UIImageView *timelapseStateImageView;
@property(weak, nonatomic) IBOutlet UIImageView *slowMotionStateImageView;
@property(weak, nonatomic) IBOutlet UIImageView *invertModeStateImageView;
@property(weak, nonatomic) IBOutlet UIImageView *burstCaptureStateImageView;
@property(weak, nonatomic) IBOutlet UIButton    *selftimerButton;
@property(weak, nonatomic) IBOutlet UILabel     *selftimerLabel;
@property(weak, nonatomic) IBOutlet UIButton    *sizeButton;
@property(weak, nonatomic) IBOutlet UILabel     *sizeLabel;
@property(weak, nonatomic) IBOutlet UIBarButtonItem    *settingButton;
@property(weak, nonatomic) IBOutlet UIButton    *snapButton;
@property(weak, nonatomic) IBOutlet UILabel *movieRecordTimerLabel;
@property(weak, nonatomic) IBOutlet UILabel *noPreviewLabel;
@property(weak, nonatomic) IBOutlet UIImageView *autoDownloadThumbImage;
@property(weak, nonatomic) IBOutlet UIButton *enableAudioButton;
@property(weak, nonatomic) IBOutlet UIButton *ImageQualityButton;
@property(weak, nonatomic) IBOutlet UIView *ImageQualityView;
@property(weak, nonatomic) IBOutlet UIView *IQSettingView;
@property(weak, nonatomic) IBOutlet UIView *appBootView;
@property(weak, nonatomic) IBOutlet UIButton *CloseIQViewButton;
@property(weak, nonatomic) IBOutlet UIButton *CloseIQSettingViewButton;
@property(weak, nonatomic) IBOutlet UIButton *IQbrightnessButton;
@property(weak, nonatomic) IBOutlet UIButton *IQhueButton;
@property(weak, nonatomic) IBOutlet UIButton *IQsaturationButton;
@property(weak, nonatomic) IBOutlet UIButton *IQWhiteBalanceButton;
@property(weak, nonatomic) IBOutlet UISlider *IQValueSlider;
@property(weak, nonatomic) IBOutlet UILabel  *IQCurValueLabel;
@property(weak, nonatomic) IBOutlet UILabel  *IQsilderLabel;
@property(weak, nonatomic) IBOutlet UIButton *IQrevertToDefaultButton;
@property(weak, nonatomic) IBOutlet UIButton *WB_AUTO;
@property(weak, nonatomic) IBOutlet UIButton *WB_DAYLIGHT;
@property(weak, nonatomic) IBOutlet UIButton *WB_CLOUDY;
@property(weak, nonatomic) IBOutlet UIButton *WB_INCADESCENT;
@property(weak, nonatomic) IBOutlet UIButton *WB_FLOURESCENT_H;
@property(weak, nonatomic) IBOutlet UIButton *changeIqPwdButton;
@property(weak, nonatomic) IBOutlet UILabel  *recordingLabel;
@property(weak, nonatomic) IBOutlet UIButton *bootPageButton;



@property(nonatomic) MPMoviePlayerController *h264player;
@property(nonatomic, getter = isPVRun) BOOL PVRun;
@property(nonatomic, getter = isAudioRun) BOOL AudioRun;
//@property(nonatomic, getter = isPVRunning) BOOL PVRunning;
@property(nonatomic, getter = isVideoCaptureStopOn) BOOL videoCaptureStopOn;
@property(nonatomic, getter = isBatteryLowAlertShowed) BOOL batteryLowAlertShowed;
@property(nonatomic) enum SettingState curSettingState;
@property(nonatomic) enum IQMode curIQMode;
@property(nonatomic) NSMutableArray *alertTableArray;
@property(nonatomic) WifiCamAlertTable* tbDelayCaptureTimeArray;
@property(nonatomic) WifiCamAlertTable* tbPhotoSizeArray;
@property(nonatomic) WifiCamAlertTable* tbVideoSizeArray;
@property(nonatomic) dispatch_semaphore_t previewSemaphore;
@property(strong, nonatomic) CustomIOS7AlertView* customIOS7AlertView;
@property(nonatomic) UIAlertView *normalAlert;
@property(nonatomic) NSTimer *videoCaptureTimer;
@property(nonatomic) int elapsedVideoRecordSecs;
@property(nonatomic) NSTimer *burstCaptureTimer;
@property(nonatomic) NSUInteger burstCaptureCount;
@property(nonatomic) NSTimer *hideZoomControllerTimer;
@property(nonatomic) UIImage *stopOn;
@property(nonatomic) UIImage *stopOff;
@property(nonatomic) uint movieRecordElapsedTimeInSeconds;
@property(nonatomic) SystemSoundID stillCaptureSound;
@property(nonatomic) SystemSoundID delayCaptureSound;
@property(nonatomic) SystemSoundID changeModeSound;
@property(nonatomic) SystemSoundID videoCaptureSound;
@property(nonatomic) SystemSoundID burstCaptureSound;
@property(nonatomic) MBProgressHUD *progressHUD;
@property(nonatomic) AVAudioPlayer *player;
@property(nonatomic) AudioFileStreamID outAudioFileStream;
@property(nonatomic) HYOpenALHelper *al;
@property(nonatomic) WifiCam *wifiCam;
@property(nonatomic) WifiCamCamera *camera;
@property(nonatomic) WifiCamControlCenter *ctrl;
@property(nonatomic) WifiCamStaticData *staticData;
@property(nonatomic) dispatch_group_t previewGroup;
@property(nonatomic) dispatch_queue_t audioQueue;
@property(nonatomic) dispatch_queue_t videoQueue;
@property(nonatomic) ICatchPreviewMode previewMode;
//@property(nonatomic) NSMutableArray* pvCache;
@property(nonatomic) WifiCamObserver *streamObserver;
@property(nonatomic) BOOL readyGoToSetting;
@property(nonatomic) AVSampleBufferDisplayLayer *avslayer;
@property(nonatomic) double curVideoPTS;
@property(nonatomic) BOOL videoPlayFlag;
@property(nonatomic, retain) GCDiscreetNotificationView *notificationView;

@property(nonatomic) dispatch_queue_t liveQueue;
@property (weak, nonatomic) IBOutlet UISwitch *liveSwitch;
@property (weak, nonatomic) IBOutlet UILabel *liveTitle;
@property (weak, nonatomic) IBOutlet UILabel *liveResolution;
@property (nonatomic) BOOL Living;
@property (nonatomic) BOOL Recording;

@property (nonatomic, strong) NSString *authorization;
@property (nonatomic, strong) NSString *liveBroadcastId;
@property (nonatomic, strong) NSString *liveStreamsId;
@property (nonatomic, strong) NSString *bindId;
@property (nonatomic, strong) NSString *streamStatus;
@property (nonatomic, strong) NSString *liveBroadcastStatus;
@property (nonatomic, strong) NSString *postUrl;
@property (nonatomic ,strong) NSString *shareUrl;

@property (nonatomic) NSMutableData *currentVideoData;
@property (nonatomic) BOOL isEnterBackground;
@property (nonatomic) BOOL isCheckIQPassword;
@property (nonatomic) NSUserDefaults *userDefaults;
@property(nonatomic, strong) NSMutableArray *assets;
@property(nonatomic, strong) NSMutableArray *photos;
@property(nonatomic, strong) NSMutableArray *thumbs;
@property(nonatomic) NSMutableArray *selections;
@property(nonatomic, strong) ALAssetsLibrary *ALAssetsLibrary;


- (IBAction)liveSwitchClink:(id)sender;
+ (NSString *)formatTypeToString:(ICatchPreviewMode)formatType;
+ (NSString *)formatTypeToString2:(WifiCamPreviewMode)formatType;
@end
