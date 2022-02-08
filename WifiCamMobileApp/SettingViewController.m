//
//  SettingViewController.m
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 13-12-11.
//  Copyright (c) 2013年 iCatchTech. All rights reserved.
//

#import "SettingViewController.h"
#import "SettingDetailViewController.h"
#import "WifiCamAlertTable.h"
#import "MBProgressHUD.h"
#include "UtilsMacro.h"
#import "ViewController.h"
#include "SettingViewSDKEventListener.h"

typedef NS_OPTIONS(NSUInteger, SettingSectionType) {
//    SettingSectionTypeAudiotoggle = 0,
//    SettingSectionTypeAutoDownload = 0,
    SettingSectionTypeBasic = 0,
    SettingSectionTypeTimelapse = 1,
    SettingSectionTypeAlertAction = 2,
    SettingSectionTypeChangeSSID = 3,
    SettingSectionTypeAutoDownload = 4,
    SettingSectionTypeNewFeature = 5,
    SettingSectionTypeAbout = 6,
};

@interface SettingViewController () {
    UpdateFWCompleteListener *udpateFWCompleteListener;
    UpdateFWCompletePowerOffListener *updateFWPowerOffListener;
}

@property(nonatomic) UIAlertView *formatAlertView;
@property(nonatomic) UIAlertView *updateFWAlertView;
@property(nonatomic) UIAlertView *cleanSpaceAlertView;
@property(nonatomic) WifiCam *wifiCam;
@property(nonatomic) WifiCamCamera *camera;
@property(nonatomic) WifiCamControlCenter *ctrl;
@property(nonatomic) NSMutableArray  *mainMenuTable;
@property(nonatomic) NSMutableArray  *mainMenuShowTable;
@property(nonatomic) NSMutableArray  *mainMenuBasicSlideTable;
@property(nonatomic) NSMutableArray  *mainMenuChangeSSIDSlideTable;
@property(nonatomic) NSMutableArray  *mainMenuTimelapseSlideTable;
@property(nonatomic) NSMutableArray  *mainMenuAutoDownloadTable;
@property(nonatomic) NSMutableArray  *mainMenuAboutTable;
@property(nonatomic) NSMutableArray  *subMenuTable;
@property(nonatomic) NSInteger curSettingDetailType;
@property(nonatomic) NSInteger curSettingDetailItem;

@property(nonatomic) NSMutableArray  *mainMenuNewFeatureTable;

@property(nonatomic) UITextField *rtmpUrlFiled;

@property(nonatomic) MBProgressHUD *progressHUD;
@end

@implementation SettingViewController

#pragma mark - Lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    WifiCamManager *app = [WifiCamManager instance];
    self.wifiCam = [app.wifiCams objectAtIndex:0];
    self.camera = _wifiCam.camera;
    self.ctrl = _wifiCam.controler;
    
    [_ctrl.propCtrl updateAllProperty:_camera];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    self.title = NSLocalizedString(@"SETTING", @"");
    
    // The whole
    self.mainMenuTable = [[NSMutableArray alloc] init];
    self.mainMenuShowTable = [[NSMutableArray alloc] init];
    self.mainMenuBasicSlideTable = [[NSMutableArray alloc] init];
    self.mainMenuChangeSSIDSlideTable = [[NSMutableArray alloc] init];
    self.mainMenuTimelapseSlideTable = [[NSMutableArray alloc] init];
    self.mainMenuAutoDownloadTable = [[NSMutableArray alloc] init];
    self.mainMenuAboutTable = [[NSMutableArray alloc] init];
    self.subMenuTable = [[NSMutableArray alloc] init];
    self.mainMenuNewFeatureTable = [[NSMutableArray alloc] initWithCapacity:4];
    
    
    NSDictionary *formatSDTable = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_FORMAT", @"")};
//    NSDictionary *udpateFWTable = @{@(SettingTableTextLabel): NSLocalizedString(@"UpdateFW", @"")};
    NSDictionary *clearAppTempDirectoryTable = @{@(SettingTableTextLabel): NSLocalizedString(@"ClearAppTemp", @"")};
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *liveBroadcast = [defaults stringForKey:@"PreferenceSpecifier:LiveBroadcast"];
    AppLogDebug(AppLogTagAPP, @"LiveBroadcast: %@", liveBroadcast);
    
    BOOL isLive = [defaults boolForKey:@"PreferenceSpecifier:Live"];
    AppLogDebug(AppLogTagAPP, @"isLive: %d", isLive);
    
    if (isLive && [liveBroadcast isEqualToString:@"立即直播"]) {
        NSDictionary *rtmpUrlTable = @{@(SettingTableTextLabel):NSLocalizedString(@"LIVEURL", @"")};
        [_mainMenuShowTable addObjectsFromArray:@[clearAppTempDirectoryTable, formatSDTable, rtmpUrlTable]];
    } else {
        [_mainMenuShowTable addObjectsFromArray:@[clearAppTempDirectoryTable, formatSDTable, /*udpateFWTable, */]];
    }
//    NSDictionary *audioToggleTable = @{@(SettingTableTextLabel):NSLocalizedString(@"AUDIO", @"")};
//    [_mainMenuAudiotoggleTable addObjectsFromArray:@[audioToggleTable]];
//    
//    [_mainMenuTable insertObject:_mainMenuAudiotoggleTable
//                         atIndex:SettingSectionTypeAudiotoggle];
    [_mainMenuTable insertObject:_mainMenuBasicSlideTable
                         atIndex:SettingSectionTypeBasic];
    [_mainMenuTable insertObject:_mainMenuTimelapseSlideTable
                         atIndex:SettingSectionTypeTimelapse];
    [_mainMenuTable insertObject:_mainMenuShowTable
                         atIndex:SettingSectionTypeAlertAction];
    [_mainMenuTable insertObject:_mainMenuChangeSSIDSlideTable
                         atIndex:SettingSectionTypeChangeSSID];
    [_mainMenuTable insertObject:_mainMenuAutoDownloadTable
                         atIndex:SettingSectionTypeAutoDownload];
    [_mainMenuTable insertObject:_mainMenuNewFeatureTable atIndex:SettingSectionTypeNewFeature];
    [_mainMenuTable insertObject:_mainMenuAboutTable
                         atIndex:SettingSectionTypeAbout];
    self.formatAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"SETTING_FORMAT_CONFIRM", @"")
                                                      message:NSLocalizedString(@"SETTING_FORMAT_DESC", @"")
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                            otherButtonTitles:NSLocalizedString(@"Sure", @""), nil];
    self.updateFWAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Update Firmware", @"")
                                                        message:NSLocalizedString(@"ConfirmFormatSD?", @"")
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                              otherButtonTitles:NSLocalizedString(@"Sure", @""), nil];
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    delegate.delegate = self;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recoverFromDisconnection)
                                             name    :@"kCameraNetworkConnectedNotification"
                                             object  :nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self showProgressHUDWithMessage:NSLocalizedString(@"LOAD_SETTING_DATA", nil)];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self fillMainMenuBasicSlideTable];
        [self fillMainMenuChangeSSIDSlideTable];
        [self fillMainMenuAutoDownloadTable];
        [self fillMainMenuTimelapseSlideTable];
        [self fillMainMenuAboutTable];
        [self fillMainMenuNewFeatureTable];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            [self hideProgressHUD:YES];
        });
    });
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if (!_formatAlertView.hidden) {
        [_formatAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    if (!_updateFWAlertView.hidden) {
        [_updateFWAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
}

-(void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"kCameraNetworkConnectedNotification" object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)recoverFromDisconnection
{
    WifiCamManager *app = [WifiCamManager instance];
    self.wifiCam = [app.wifiCams objectAtIndex:0];
    self.camera = _wifiCam.camera;
    self.ctrl = _wifiCam.controler;
    
    [self.tableView reloadData];
}

#pragma mark - MBProgressHUD
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

#pragma mark - Fill menu

- (BOOL)capableOf:(WifiCamAbility)ability
{
    return (_camera.ability & ability) == ability ? YES : NO;
}

- (void)fillMainMenuBasicSlideTable
{
    NSDictionary *table = nil;
    [_mainMenuBasicSlideTable removeAllObjects];

    if ([self capableOf:WifiCamAbilityWhiteBalance]) {
        table = [self fillWhiteBalanceTable];
        if (table) {
            [_mainMenuBasicSlideTable addObject:table];
        }
    }

    if ((_camera.previewMode == WifiCamPreviewModeCameraOff
         || _camera.previewMode == WifiCamPreviewModeVideoOff)
        && [self capableOf:WifiCamAbilityDateStamp]) {
        table = [self fillDateStampTable];
        if (table) {
            [_mainMenuBasicSlideTable addObject:table];
        }
    }
    
    if ([self capableOf:WifiCamAbilityUpsideDown]) {
        table = [self fillUpsideDownTable];
        if (table) {
            [_mainMenuBasicSlideTable addObject:table];
        }
    }
    
//    if ([self capableOf:WifiCamAbilitySlowMotion]
//        && _camera.previewMode == WifiCamPreviewModeVideoOff) {
//        table = [self fillSlowMotionTable];
//        [_mainMenuBasicSlideTable addObject:table];
//    }
    if ([self capableOf:WifiCamAbilityLightFrequency]) {
        table = [self fillLightFrequencyTable];
        if (table) {
            [_mainMenuBasicSlideTable addObject:table];
        }
    }
    
//    table = [self fillAboutTable];
//    [_mainMenuBasicSlideTable addObject:table];
}

- (void)fillMainMenuAboutTable
{
    [_mainMenuAboutTable removeAllObjects];
    [_mainMenuAboutTable addObject:[self fillAboutTable]];
}

- (void)fillMainMenuAutoDownloadTable {
    NSDictionary *table = nil;
    [_mainMenuAutoDownloadTable removeAllObjects];
//    
//    NSDictionary *audioToggleTable = @{@(SettingTableTextLabel):NSLocalizedString(@"AUDIO", @"")};
//    [_mainMenuAutoDownloadTable addObjectsFromArray:@[audioToggleTable]];
    
    if ([[SDK instance] isSupportAutoDownload]) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"AutoDownload", @"")};
        if (table) {
            [_mainMenuAutoDownloadTable addObject:table];
        }
    }
    
    if ([self capableOf:WifiCamAbilityGetPowerOnAutoRecord] && _camera.previewMode == WifiCamPreviewModeVideoOff) {
        table = @{@(SettingTableTextLabel):NSLocalizedString(@"SetPowerOnAutoRecord", @""),
                  @(SettingTableDetailType):@(SettingDetailTypePowerOnAutoRecord)};
        
        if (table) {
            [_mainMenuAutoDownloadTable addObject:table];
        }
    }
    
    if ([self capableOf:WifiCamAbilityGetImageStabilization] && _camera.previewMode == WifiCamPreviewModeVideoOff) {
        table = @{@(SettingTableTextLabel):NSLocalizedString(@"SetImageStabilization", @""),
                  @(SettingTableDetailType):@(SettingDetailTypeImageStabilization)};
        
        if (table) {
            [_mainMenuAutoDownloadTable addObject:table];
        }
    }
    
    if ([self capableOf:WifiCamAbilityGetWindNoiseReduction] && _camera.previewMode == WifiCamPreviewModeVideoOff) {
        table = @{@(SettingTableTextLabel):NSLocalizedString(@"SetWindNoiseReduction", @""),
                  @(SettingTableDetailType):@(SettingDetailTypeWindNoiseReduction)};
        
        if (table) {
            [_mainMenuAutoDownloadTable addObject:table];
        }
    }
}

- (void)fillMainMenuChangeSSIDSlideTable
{
    if ([self capableOf:WifiCamAbilityChangeSSID]
        || [self capableOf:WifiCamAbilityChangePwd]) {
        NSDictionary *table = @{@(SettingTableTextLabel): NSLocalizedString(@"ChangeSSID", @"")};
        [_mainMenuChangeSSIDSlideTable removeAllObjects];
        if (table) {
            [_mainMenuChangeSSIDSlideTable addObject:table];
        }
    }
}

- (void)fillMainMenuTimelapseSlideTable
{
    NSDictionary *table = nil;
    [_mainMenuTimelapseSlideTable removeAllObjects];
    
    if (_camera.previewMode == WifiCamPreviewModeCameraOff || (_camera.previewMode == WifiCamPreviewModeTimelapseOff &&_camera.timelapseType == WifiCamTimelapseTypeStill)) {
        if ([self capableOf:WifiCamAbilityImageSize]) {
            table = [self fillImageSizeTable];
            if (table) {
                [_mainMenuTimelapseSlideTable addObject:table];
            }
        }
    }
    
    if (_camera.previewMode == WifiCamPreviewModeCameraOff) {
        if ([self capableOf:WifiCamAbilityDelayCapture]) {
            table = [self fillDelayCaptureTimeTable];
            if (table) {
                [_mainMenuTimelapseSlideTable addObject:table];
            }
        }
        
        if ([self capableOf:WifiCamAbilityBurstNumber]) {
            table = [self fillBurstNumberTable];
            if (table) {
                [_mainMenuTimelapseSlideTable addObject:table];
            }
        }
    }
    
    if (_camera.previewMode == WifiCamPreviewModeVideoOff || (_camera.previewMode == WifiCamPreviewModeTimelapseOff && _camera.timelapseType == WifiCamTimelapseTypeVideo)) {
        if ([self capableOf:WifiCamAbilityVideoSize]) {
            table = [self fillVideoSizeTable];
            if (table) {
                [_mainMenuTimelapseSlideTable addObject:table];
            }
        }
    }
    
    if ([self capableOf:WifiCamAbilitySlowMotion]
        && _camera.previewMode == WifiCamPreviewModeVideoOff) {
        table = [self fillSlowMotionTable];
        if (table) {
            [_mainMenuTimelapseSlideTable addObject:table];
        }
    }
    
    if (_camera.previewMode == WifiCamPreviewModeTimelapseOff
        && [self capableOf:WifiCamAbilityTimeLapse]) {

        table = [self fillTimeLapseTypeTable];
        if (table) {
            [_mainMenuTimelapseSlideTable addObject:table];
        }
        table = [self fillTimeLapseIntervalTable];
        if (table) {
            [_mainMenuTimelapseSlideTable addObject:table];
        }
        table = [self fillTimeLapseDurationTable];
        if (table) {
            [_mainMenuTimelapseSlideTable addObject:table];
        }
    }
    
#if 0
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PreferenceSpecifier:Live"] && _camera.previewMode == WifiCamPreviewModeVideoOff) {
        table = [self fillLiveSizeTable];
        if (table) {
            [_mainMenuTimelapseSlideTable addObject:table];
        }
    }
#endif
}

// add - 2017.3.17
- (void)fillMainMenuNewFeatureTable
{
    NSDictionary *table = nil;
    [_mainMenuNewFeatureTable removeAllObjects];
    
    if ([self capableOf:WifiCamAbilityGetScreenSaverTime]) {
        table = [self fillScreenSaverTable];
        if (table) {
            [_mainMenuNewFeatureTable addObject:table];
        }
    }
    
    if ([self capableOf:WifiCamAbilityGetAutoPowerOffTime]) {
        table = [self fillAutoPowerOffTable];
        if (table) {
            [_mainMenuNewFeatureTable addObject:table];
        }
    }
    
    if ([self capableOf:WifiCamAbilityGetExposureCompensation]) {
        table = [self fillExposureCompensationTable];
        if (table) {
            [_mainMenuNewFeatureTable addObject:table];
        }
    }
    
    if ([self capableOf:WifiCamAbilityGetVideoFileLength] && _camera.previewMode == WifiCamPreviewModeVideoOff) {
        table = [self fillVideoFileLengthTable];
        if (table) {
            [_mainMenuNewFeatureTable addObject:table];
        }
    }
    
    if ([self capableOf:WifiCamAbilityGetFastMotionMovie] && _camera.previewMode == WifiCamPreviewModeVideoOff) {
        table = [self fillFastMotionMovieTable];
        if (table) {
            [_mainMenuNewFeatureTable addObject:table];
        }
    }
}

- (NSDictionary *)fillScreenSaverTable
{
    NSDictionary *table = nil;
    uint curScreenSaver = [[SDK instance] retrieveCurrentScreenSaver];
    WifiCamAlertTable *ssArray = [_ctrl.propCtrl prepareDataForScreenSaver:curScreenSaver];
    
    if (ssArray.array) {
       table = @{@(SettingTableTextLabel):NSLocalizedString(@"SetScreenSaver", @""),
               @(SettingTableDetailTextLabel):[_ctrl.propCtrl calcScreenSaverTime:curScreenSaver],
               @(SettingTableDetailType):@(SettingDetailTypeScreenSaver),
               @(SettingTableDetailData):ssArray.array,
               @(SettingTableDetailLastItem):@(ssArray.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillAutoPowerOffTable
{
    NSDictionary *table = nil;
    uint curAutoPowerOff = [[SDK instance] retrieveCurrentAutoPowerOff];
    WifiCamAlertTable *apo = [_ctrl.propCtrl prepareDataForAutoPowerOff:curAutoPowerOff];
    
    if (apo.array) {
        table = @{@(SettingTableTextLabel):NSLocalizedString(@"SetAutoPowerOff", @""),
                  @(SettingTableDetailTextLabel):[_ctrl.propCtrl calcAutoPowerOffTime:curAutoPowerOff],
                  @(SettingTableDetailType):@(SettingDetailTypeAutoPowerOff),
                  @(SettingTableDetailData):apo.array,
                  @(SettingTableDetailLastItem):@(apo.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillExposureCompensationTable
{
    NSDictionary *table = nil;
    uint curExposureCompensation = [[SDK instance] retrieveCurrentExposureCompensation];
    WifiCamAlertTable *ec = [_ctrl.propCtrl prepareDataForExposureCompensation:curExposureCompensation];
    
    if (ec.array) {
        table = @{@(SettingTableTextLabel):NSLocalizedString(@"SetExposureCompensation", @""),
                  @(SettingTableDetailTextLabel):[_ctrl.propCtrl calcExposureCompensationValue:curExposureCompensation],
                  @(SettingTableDetailType):@(SettingDetailTypeExposureCompensation),
                  @(SettingTableDetailData):ec.array,
                  @(SettingTableDetailLastItem):@(ec.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillVideoFileLengthTable
{
    NSDictionary *table = nil;
    uint curVideoFileLength = [[SDK instance] retrieveCurrentVideoFileLength];
    WifiCamAlertTable *vfl = [_ctrl.propCtrl prepareDataForVideoFileLength:curVideoFileLength];
    
    if (vfl.array) {
        table = @{@(SettingTableTextLabel):NSLocalizedString(@"SetVideoFileLength", @""),
                  @(SettingTableDetailTextLabel):[_ctrl.propCtrl calcVideoFileLength:curVideoFileLength],
                  @(SettingTableDetailType):@(SettingDetailTypeVideoFileLength),
                  @(SettingTableDetailData):vfl.array,
                  @(SettingTableDetailLastItem):@(vfl.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillFastMotionMovieTable
{
    NSDictionary *table = nil;
    uint curFastMotionMovie = [[SDK instance] retrieveCurrentFastMotionMovie];
    WifiCamAlertTable *fmm = [_ctrl.propCtrl prepareDataForFastMotionMovie:curFastMotionMovie];
    
    if (fmm.array) {
        table = @{@(SettingTableTextLabel):NSLocalizedString(@"SetFastMotionMovie", @""),
                  @(SettingTableDetailTextLabel):[_ctrl.propCtrl calcFastMotionMovieRate:curFastMotionMovie],
                  @(SettingTableDetailType):@(SettingDetailTypeFastMotionMovie),
                  @(SettingTableDetailData):fmm.array,
                  @(SettingTableDetailLastItem):@(fmm.lastIndex)};
    }
    
    return table;
}

- (WifiCamAlertTable *)prepareDataForLiveSize:(NSString *)curLiveSize
{
    WifiCamAlertTable *TAA = [[WifiCamAlertTable alloc] init];
    dispatch_sync([[SDK instance] sdkQueue], ^{
        __block int i = 0;
        
        NSDictionary *liveSizeDict = [[WifiCamStaticData instance] liveSizeDict];
        TAA.array = [[NSMutableArray alloc] initWithCapacity:liveSizeDict.count];
        
        [liveSizeDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            NSString *first = obj[0];
            NSString *second = obj[1];
            
            if (first && second) {
                NSString *s = [first stringByAppendingFormat:@" %@", second];
                AppLogDebug(AppLogTagAPP, @"%@", s);
                if (s) {
                    [TAA.array addObject:s];
                }
                
                if ([key isEqualToString:curLiveSize]) {
                    TAA.lastIndex = i;
                }
            }
            
            i++;
        }];
    });
    return TAA;
}

- (NSDictionary *)fillLiveSizeTable
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *curLiveSize = [defaults stringForKey:@"LiveSize"];
    if (!curLiveSize) {
        curLiveSize = @"854x480";
        [defaults setValue:curLiveSize forKey:@"LiveSize"];
    }
    
    NSDictionary *table = nil;
    WifiCamAlertTable *lsArray = [self prepareDataForLiveSize:curLiveSize];
    NSDictionary *liveSizeTable = [[WifiCamStaticData instance] liveSizeDict];
    NSArray *a = [liveSizeTable objectForKey:curLiveSize];
    
    if (lsArray.array && a) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"LIVE_RESOLUTION", @""),
                  @(SettingTableDetailTextLabel): [a firstObject],
                  @(SettingTableDetailType): @(SettingDetailTypeLiveSize),
                  @(SettingTableDetailData): lsArray.array,
                  @(SettingTableDetailLastItem): @(lsArray.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillImageSizeTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *isArray = [_ctrl.propCtrl prepareDataForImageSize:_camera.curImageSize];
//    NSDictionary *imageSizeTable = [[WifiCamStaticData instance] imageSizeDict];
    
    if (isArray.array) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"SetPhotoResolution", @""),
                  @(SettingTableDetailTextLabel): [_ctrl.propCtrl calcImageSizeToNum:[NSString stringWithFormat:@"%s", _camera.curImageSize.c_str()]],
                  @(SettingTableDetailType): @(SettingDetailTypeImageSize),
                  @(SettingTableDetailData): isArray.array,
                  @(SettingTableDetailLastItem): @(isArray.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillVideoSizeTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *vsArray = [_ctrl.propCtrl prepareDataForVideoSize:_camera.curVideoSize];
    NSDictionary *videoSizeTable = [[WifiCamStaticData instance] videoSizeDict];
    NSArray *a = [videoSizeTable objectForKey:@(_camera.curVideoSize.c_str())];
    
    if (a && vsArray.array) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"ALERT_TITLE_SET_VIDEO_RESOLUTION", @""),
                  @(SettingTableDetailTextLabel): [a firstObject],
                  @(SettingTableDetailType): @(SettingDetailTypeVideoSize),
                  @(SettingTableDetailData): vsArray.array,
                  @(SettingTableDetailLastItem): @(vsArray.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillDelayCaptureTimeTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *dctArray = [_ctrl.propCtrl prepareDataForDelayCapture:_camera.curCaptureDelay];
    NSDictionary *captureDelayTable = [[WifiCamStaticData instance] captureDelayDict];
    
    if (dctArray.array && captureDelayTable) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"ALERT_TITLE_SET_SELF_TIMER", @""),
                  @(SettingTableDetailTextLabel): [captureDelayTable objectForKey:@(_camera.curCaptureDelay)],
                  @(SettingTableDetailType): @(SettingDetailTypeCaptureDelay),
                  @(SettingTableDetailData): dctArray.array,
                  @(SettingTableDetailLastItem): @(dctArray.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillLightFrequencyTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *pfArray = [_ctrl.propCtrl prepareDataForLightFrequency:_camera.curLightFrequency];
    NSDictionary *powerFrequencyTable = [[WifiCamStaticData instance] powerFrequencyDict];
    
    if (powerFrequencyTable && pfArray.array) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_POWER_SUPPLY", @""),
                  @(SettingTableDetailTextLabel): [powerFrequencyTable objectForKey:@(_camera.curLightFrequency)],
                  @(SettingTableDetailType): @(SettingDetailTypePowerFrequency),
                  @(SettingTableDetailData): pfArray.array,
                  @(SettingTableDetailLastItem): @(pfArray.lastIndex)};
    }

    return table;
}

- (NSDictionary *)fillWhiteBalanceTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *awbArray = [_ctrl.propCtrl prepareDataForWhiteBalance:_camera.curWhiteBalance];
    NSDictionary *whiteBalanceTable = [[WifiCamStaticData instance] whiteBalanceDict];
    
    if (whiteBalanceTable && awbArray.array) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_AWB", @""),
                  @(SettingTableDetailTextLabel): [whiteBalanceTable objectForKey:@(_camera.curWhiteBalance)],
                  @(SettingTableDetailType): @(SettingDetailTypeWhiteBalance),
                  @(SettingTableDetailData): awbArray.array,
                  @(SettingTableDetailLastItem): @(awbArray.lastIndex)};
    }

    return table;
}

- (NSDictionary *)fillBurstNumberTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *bnArray = [_ctrl.propCtrl prepareDataForBurstNumber:_camera.curBurstNumber];
    NSDictionary *burstNumberStringTable = [[WifiCamStaticData instance] burstNumberStringDict];
    
    if (burstNumberStringTable && bnArray.array) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_BURST", @""),
                  @(SettingTableDetailTextLabel): [[burstNumberStringTable objectForKey:@(_camera.curBurstNumber)] firstObject],
                  @(SettingTableDetailType): @(SettingDetailTypeBurstNumber),
                  @(SettingTableDetailData): bnArray.array,
                  @(SettingTableDetailLastItem): @(bnArray.lastIndex)};
    }

    return table;
}

- (NSDictionary *)fillDateStampTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *dsArray = [_ctrl.propCtrl prepareDataForDateStamp:_camera.curDateStamp];
    NSDictionary *dateStampTable = [[WifiCamStaticData instance] dateStampDict];
    
    if (dateStampTable && dsArray.array) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_DATESTAMP", @""),
                  @(SettingTableDetailTextLabel): [dateStampTable objectForKey:@(_camera.curDateStamp)],
                  @(SettingTableDetailType): @(SettingDetailTypeDateStamp),
                  @(SettingTableDetailData): dsArray.array,
                  @(SettingTableDetailLastItem): @(dsArray.lastIndex)};
    }

    return table;
}

- (NSDictionary *)fillSSIDPwdTable
{
    
    return nil;
}

- (NSDictionary *)fillTimeLapseTypeTable
{
    NSDictionary *table = nil;
    NSString *curTimelapseTypeStr = nil;
    WifiCamAlertTable *t = [[WifiCamAlertTable alloc] init];
    t.array = [NSMutableArray arrayWithObjects:NSLocalizedString(@"SETTING_TIMELAPSE_TYPE_STILL", nil),
               NSLocalizedString(@"SETTING_TIMELAPSE_TYPE_VIDEO", nil), nil];
    if (_camera.timelapseType == WifiCamTimelapseTypeVideo) {
        t.lastIndex = 1;
    } else {
        t.lastIndex = 0;
    }
    
    if (t.array) {
        curTimelapseTypeStr = [t.array objectAtIndex:t.lastIndex];
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_TIMELAPSE_TYPE", @""),
                @(SettingTableDetailTextLabel): curTimelapseTypeStr,
                @(SettingTableDetailType): @(SettingDetailTypeTimelapseType),
                @(SettingTableDetailData): t.array,
                @(SettingTableDetailLastItem): @(t.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillTimeLapseIntervalTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *vtiArray = [_ctrl.propCtrl prepareDataForTimelapseInterval:_camera.curTimelapseInterval];
    //  NSDictionary *timeLapseTable = [[WifiCamStaticData instance] timelapseIntervalDict];
    NSString *tableCellDetailText = @"";
    if (vtiArray.lastIndex != UNDEFINED_NUM) {
        //    tableCellDetailText = [timeLapseTable objectForKey:@(_camera.curTimelapseInterval)];
        if (0 == _camera.curTimelapseInterval) {
            tableCellDetailText = NSLocalizedString(@"SETTING_CAP_TL_INTERVAL_OFF", nil);
        } else {
            //      tableCellDetailText = [NSString stringWithFormat:@"%ds", _camera.curTimelapseInterval];
            tableCellDetailText = [vtiArray.array objectAtIndex:vtiArray.lastIndex];
        }
    }
    
    if (tableCellDetailText && vtiArray.array) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_CAP_TIMESCAPE_INTERVAL", @""),
                  @(SettingTableDetailTextLabel): tableCellDetailText,
                  @(SettingTableDetailType): @(SettingDetailTypeTimelapseInterval),
                  @(SettingTableDetailData): vtiArray.array,
                  @(SettingTableDetailLastItem): @(vtiArray.lastIndex)};
    }
    
    return table;
}

- (NSDictionary *)fillTimeLapseDurationTable
{
    NSDictionary *table = nil;
    WifiCamAlertTable *vtdArray = [_ctrl.propCtrl prepareDataForTimelapseDuration:_camera.curTimelapseDuration];
    //  NSDictionary *timeLapseTable = [[WifiCamStaticData instance] timelapseDurationDict];
    NSString *tableCellDetailText = @"";
    if (vtdArray.lastIndex != UNDEFINED_NUM) {
        //    tableCellDetailText = [timeLapseTable objectForKey:@(_camera.curTimelapseDuration)];
        if (0xFFFF == _camera.curTimelapseDuration) {
            tableCellDetailText = NSLocalizedString(@"SETTING_CAP_TL_DURATION_Unlimited", nil);
        } else {
            //      tableCellDetailText = [NSString stringWithFormat:@"%dm", _camera.curTimelapseDuration];
            tableCellDetailText = [vtdArray.array objectAtIndex:vtdArray.lastIndex];
        }
    }
    
    if (tableCellDetailText && vtdArray.array) {
        table = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_CAP_TIMESCAPE_LIMIT", @""),
                  @(SettingTableDetailTextLabel): tableCellDetailText,
                  @(SettingTableDetailType): @(SetttngDetailTypeTimelapseDuration),
                  @(SettingTableDetailData): vtdArray.array,
                  @(SettingTableDetailLastItem): @(vtdArray.lastIndex)};
    }
    
    return table;
}


- (NSDictionary *)fillUpsideDownTable
{
    NSDictionary *upsideDownDict = nil;
    WifiCamAlertTable *upsideDownTable = [[WifiCamAlertTable alloc] init];
    upsideDownTable.array = [[NSMutableArray alloc] initWithObjects:NSLocalizedString(@"SETTING_OFF", nil), NSLocalizedString(@"SETTING_ON", nil), nil];
    
    uint curUpsideDown = _camera.curInvertMode;//[_ctrl.propCtrl retrieveCurrentUpsideDown];
    if (0 == curUpsideDown) {
        upsideDownTable.lastIndex = 0;
    } else {
        upsideDownTable.lastIndex = 1;
    }
    
    if (upsideDownTable.array) {
        upsideDownDict = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_UPSIDE_DOWN", @""),
                           @(SettingTableDetailTextLabel): [upsideDownTable.array objectAtIndex:upsideDownTable.lastIndex],
                           @(SettingTableDetailType): @(SettingDetailTypeUpsideDown),
                           @(SettingTableDetailData): upsideDownTable.array,
                           @(SettingTableDetailLastItem): @(upsideDownTable.lastIndex)};
    }
    
    return upsideDownDict;
}

- (NSDictionary *)fillSlowMotionTable
{
    NSDictionary *upsideDownDict = nil;
    WifiCamAlertTable *slowMotionTable = [[WifiCamAlertTable alloc] init];
    slowMotionTable.array = [[NSMutableArray alloc] initWithObjects:NSLocalizedString(@"SETTING_OFF", nil), NSLocalizedString(@"SETTING_ON", nil), nil];
    
    uint curSlowMotion = _camera.curSlowMotion;//[_ctrl.propCtrl retrieveCurrentSlowMotion];
    if (0 == curSlowMotion) {
        slowMotionTable.lastIndex = 0;
    } else {
        slowMotionTable.lastIndex = 1;
    }
   
    if (slowMotionTable.array) {
        upsideDownDict = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_SLOW_MOTION", @""),
                           @(SettingTableDetailTextLabel): [slowMotionTable.array objectAtIndex:slowMotionTable.lastIndex],
                           @(SettingTableDetailType): @(SettingDetailTypeSlowMotion),
                           @(SettingTableDetailData): slowMotionTable.array,
                           @(SettingTableDetailLastItem): @(slowMotionTable.lastIndex)};
    }
    
    return upsideDownDict;
}

- (NSDictionary *)fillAboutTable
{
    NSMutableArray  *aboutArray = [[NSMutableArray alloc] init];
    NSString *appVersion = NSLocalizedString(@"SETTING_APP_VERSION", nil);
    appVersion = [appVersion stringByReplacingOccurrencesOfString:@"%@"
                                                       withString:APP_VERSION];
    [aboutArray addObject:appVersion];
    if ([self capableOf:WifiCamAbilityFWVersion]) {
        NSString *fwVersion = NSLocalizedString(@"SETTING_FIRMWARE_VERSION", nil);
        fwVersion = [fwVersion stringByReplacingOccurrencesOfString:@"%@" withString:_camera.cameraFWVersion];
        [aboutArray addObject:fwVersion];
    }
    if ([self capableOf:WifiCamAbilityProductName]) {
        NSString *productName = NSLocalizedString(@"SETTING_PRODUCT_NAME", nil);
        productName = [productName stringByReplacingOccurrencesOfString:@"%@" withString:_camera.cameraProductName];
        [aboutArray addObject:productName];
    }
    
    NSDictionary *table = @{@(SettingTableTextLabel): NSLocalizedString(@"SETTING_ABOUT", @""),
                            @(SettingTableDetailType): @(SettingDetailTypeAbout),
                            @(SettingTableDetailData): aboutArray};
    
    
    return table;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_mainMenuTable count];
}

- (NSInteger) tableView             :(UITableView *)tableView
              numberOfRowsInSection :(NSInteger)section
{
    return [[_mainMenuTable objectAtIndex:section] count];
}

- (UITableViewCell *) tableView             :(UITableView *)tableView
                      cellForRowAtIndexPath :(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"settingCell";
    static NSString *CellIdentifier2 = @"settingCell2";
    static NSString *CellIdentifier3 = @"settingCell3";
    static NSString *CellIdentifier4 = @"settingCell4";
    UITableViewCell *cell = nil;
    
    if (indexPath.section == SettingSectionTypeAlertAction) {
        // Format
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier2 forIndexPath:indexPath];
        [cell.textLabel setTextColor:[UIColor blueColor]];
        
        if (!indexPath.row) {
            UILabel *lab = [[UILabel alloc] initWithFrame:CGRectMake(CGRectGetWidth(cell.frame) - 100, 0, 100, CGRectGetHeight(cell.frame))];
            lab.text = [self cleanSpace];
            lab.textColor = [UIColor lightGrayColor];
            lab.textAlignment = NSTextAlignmentRight;
            cell.accessoryView = lab;
        }
    } else if (indexPath.section == SettingSectionTypeBasic
               /*|| indexPath.section == SettingSectionTypeTimelapse*/) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    } else if (indexPath.section == SettingSectionTypeChangeSSID) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier3 forIndexPath:indexPath];
    } else if (indexPath.section == SettingSectionTypeAutoDownload) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier4 forIndexPath:indexPath];
        UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
//        if (indexPath.row == 0) {
//            [switchView addTarget:self action:@selector(updateAudioSwitch:) forControlEvents:UIControlEventValueChanged];
//            switchView.on = _camera.enableAudio;
//        } else if (indexPath.row == 1) {
//            [switchView addTarget:self action:@selector(updateSwitchAtIndexPath:) forControlEvents:UIControlEventValueChanged];
//            switchView.on = _camera.enableAutoDownload;
//        }
        
        // modify - 2017.3.17
//        [switchView addTarget:self action:@selector(updateSwitchAtIndexPath:) forControlEvents:UIControlEventValueChanged];
//        switchView.on = _camera.enableAutoDownload;
//        cell.accessoryView = switchView;
//        //cell.backgroundColor = [UIColor redColor];
        switch ([(_mainMenuAutoDownloadTable[indexPath.row])[@(SettingTableDetailType)] intValue]) {
            case SettingDetailTypePowerOnAutoRecord:
                [switchView addTarget:self action:@selector(updatePowerOnAutoRecondSwitch:) forControlEvents:UIControlEventValueChanged];
                switchView.on = [[SDK instance] retrieveCurrentPowerOnAutoRecord];
                break;
                
            case SettingDetailTypeImageStabilization:
                [switchView addTarget:self action:@selector(updateImageStabilizationSwitch:) forControlEvents:UIControlEventValueChanged];
                switchView.on = [[SDK instance] retrieveCurrentImageStabilization];
                break;
                
            case SettingDetailTypeWindNoiseReduction:
                [switchView addTarget:self action:@selector(updateWindNoiseReductionSwitch:) forControlEvents:UIControlEventValueChanged];
                switchView.on = [[SDK instance] retrieveCurrentWindNoiseReduction];
                break;
                
            default:
                [switchView addTarget:self action:@selector(updateSwitchAtIndexPath:) forControlEvents:UIControlEventValueChanged];
                    switchView.on = _camera.enableAutoDownload;
                break;
        }
        
        cell.accessoryView = switchView;
    }
//    else if (indexPath.section == SettingSectionTypeAudiotoggle) {
//        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier4 forIndexPath:indexPath];
//        UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
//        [switchView addTarget:self action:@selector(updateAudioSwitch:) forControlEvents:UIControlEventValueChanged];
//        switchView.on = _camera.enableAudio;
//        cell.accessoryView = switchView;
//    }
    else if (indexPath.section == SettingSectionTypeTimelapse) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    } else if (indexPath.section == SettingSectionTypeAbout) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    } else if (indexPath.section == SettingSectionTypeNewFeature) {
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    }
    
    if (cell) {
        //  AppLog(@"section:%d, row:%d", indexPath.section, indexPath.row);
        NSDictionary *dict = [[_mainMenuTable objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        NSAssert1([dict isKindOfClass:[NSDictionary class]], @"Object dict isn't an NSDictionary", nil);
        cell.textLabel.text = [dict objectForKey:@(SettingTableTextLabel)];
        cell.detailTextLabel.text = [dict objectForKey:@(SettingTableDetailTextLabel)];
        
        return cell;
    } else {
        AppLog(@"Some exception message for unexpected tableView");
        abort();
    }
}

- (IBAction)updatePowerOnAutoRecondSwitch:(id)sender {
    UISwitch *switchView = (UISwitch *)sender;
    
    if ([switchView isOn])
        AppLog(@"PowerOnAutoRecord On");
    else
        AppLog(@"PowerOnAutoRecord Off");
    
    [[SDK instance] setCustomizeIntProperty:CustomizePropertyID_PowerOnAutoRecord value:switchView.isOn];
}

- (IBAction)updateImageStabilizationSwitch:(id)sender {
    UISwitch *switchView = (UISwitch *)sender;
    
    if ([switchView isOn])
        AppLog(@"ImageStabilization On");
    else
        AppLog(@"ImageStabilization Off");
    
    [[SDK instance] setCustomizeIntProperty:CustomizePropertyID_ImageStabilization value:switchView.isOn];
}

- (IBAction)updateWindNoiseReductionSwitch:(id)sender {
    UISwitch *switchView = (UISwitch *)sender;
    
    if ([switchView isOn])
        AppLog(@"WindNoiseReduction On");
    else
        AppLog(@"WindNoiseReduction Off");
    
    [[SDK instance] setCustomizeIntProperty:CustomizePropertyID_WindNoiseReduction value:switchView.isOn];
}

- (IBAction)updateAudioSwitch:(id)sender {
    UISwitch *switchView = (UISwitch *)sender;
    
    if ([switchView isOn])
        AppLog(@"Audio On");
    else
        AppLog(@"Audio Off");

    _camera.enableAudio = switchView.isOn;
}

- (IBAction)updateSwitchAtIndexPath:(id)sender {
    UISwitch *switchView = (UISwitch *)sender;
    
    if ([switchView isOn])
    {
        AppLog(@"AutoDownload On");
    }
    else
    {
        AppLog(@"AutoDownload Off");
    }
    
    _camera.enableAutoDownload = switchView.isOn;
    
}

- (NSString *)tableView               :(UITableView *)tableView
              titleForHeaderInSection :(NSInteger)section
{
    NSString *retVal = nil;
    
    switch (section) {
        case SettingSectionTypeBasic:
            retVal = NSLocalizedString(@"SETTING", nil);
            break;
            
        case SettingSectionTypeTimelapse:
            if (_camera.previewMode == WifiCamPreviewModeTimelapseOff
                && [self capableOf:WifiCamAbilityTimeLapse]) {
                retVal = NSLocalizedString(@"SETTING_TIMELAPSE", nil);
            }
            break;
            
        default:
            break;
    }
    
    return retVal;
}

- (NSString *)cleanSpace
{
    long long numberOfBytes = 0;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSArray *documentsDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    NSString *logFilePath = nil;
    for (NSString *fileName in  documentsDirectoryContents) {
        if (![fileName isEqualToString:@"Camera.sqlite"] && ![fileName isEqualToString:@"Camera.sqlite-shm"] && ![fileName isEqualToString:@"Camera.sqlite-wal"]) {
            
            logFilePath = [documentsDirectory stringByAppendingPathComponent:fileName];
            numberOfBytes += [DiskSpaceTool num_folderSizeAtPath:logFilePath];
            NSLog(@"=======> %@", [DiskSpaceTool humanReadableStringFromBytes:numberOfBytes]);
        }
    }
    
    numberOfBytes += [DiskSpaceTool num_folderSizeAtPath:NSTemporaryDirectory()];
    
    return [DiskSpaceTool humanReadableStringFromBytes:numberOfBytes];
}

#pragma mark - Table view delegate

- (void)tableView               :(UITableView *)tableView
        didSelectRowAtIndexPath :(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == SettingSectionTypeAlertAction) {
        // Format
        if (indexPath.row == 0) {
            //[self cleanSpace];
            self.cleanSpaceAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ClearAppTemp", @"")
                                                                  message:[self cleanSpace]
                                                                 delegate:self
                                                        cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                        otherButtonTitles:NSLocalizedString(@"Sure", @""), nil];
            [self.cleanSpaceAlertView setTag:10];
            [self.cleanSpaceAlertView show];
        } /*else if (indexPath.row == 1) {
            [_updateFWAlertView setTag:1];
            [_updateFWAlertView show];
        } */else if (indexPath.row == 1/*2*/) {
//            [_ctrl.actCtrl cleanUpDownloadDirectory];
            [_formatAlertView setTag:0];
            [_formatAlertView show];
        } else {
            UIAlertView *inputUrlAlert = [[UIAlertView alloc] initWithTitle:@"Server URL"
                                            message           :@"please enter server URL:"
                                            delegate          :self
                                            cancelButtonTitle :@"Cancel"
                                            otherButtonTitles :@"Ok", nil];
            [inputUrlAlert setAlertViewStyle:UIAlertViewStylePlainTextInput];
            UITextField *text = [inputUrlAlert textFieldAtIndex:0];
            text.clearButtonMode = UITextFieldViewModeWhileEditing;
            
            NSString *ipAddr = [[NSUserDefaults standardUserDefaults] objectForKey:@"RTMPURL"];
            if (!ipAddr) {
                text.placeholder = @"please enter server URL";
            } else {
                text.text = ipAddr;
            }
            
            [inputUrlAlert show];
            inputUrlAlert.tag = 11;
        }
    } else if (indexPath.section == SettingSectionTypeChangeSSID) {
        
        //[self performSegueWithIdentifier:@"changeSSID" sender:self];
    }
}

- (NSIndexPath *) tableView               :(UITableView *)tableView
                  willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section != SettingSectionTypeAlertAction) {
        NSDictionary *dict = [[_mainMenuTable objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
        [_subMenuTable setArray:[dict objectForKey:@(SettingTableDetailData)]];
        _curSettingDetailType = [[dict objectForKey:@(SettingTableDetailType)] integerValue];
        _curSettingDetailItem = [[dict objectForKey:@(SettingTableDetailLastItem)] integerValue];
    }
    
    return indexPath;
}

#pragma mark - UIAlertView delegate
- (void)alertView           :(UIAlertView *)alertView
        clickedButtonAtIndex:(NSInteger)buttonIndex
{
    __block BOOL formatOK = NO;
    if ((buttonIndex == 1) && (alertView.tag == 0)) {
        if (![_ctrl.propCtrl checkSDExist]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil
                                                 message           :NSLocalizedString(@"CARD_ERROR", nil)
                                                 delegate          :self
                                                 cancelButtonTitle :NSLocalizedString(@"Sure", nil)
                                                 otherButtonTitles :nil, nil];
            [alert show];
            return;
        }
        
//        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view.window animated:YES];
//        hud.labelText = NSLocalizedString(@"SETTING_FORMATTING", nil);
//        hud.minSize = CGSizeMake(120, 120);
//        hud.dimBackground = YES;
        [self showProgressHUDWithMessage:NSLocalizedString(@"SETTING_FORMATTING", nil)];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            formatOK = [_ctrl.actCtrl formatSD];
            
            dispatch_async(dispatch_get_main_queue(), ^{
//                hud.mode = MBProgressHUDModeText;
//                if (formatOK) {
//                    hud.labelText = NSLocalizedString(@"SETTING_FORMAT_FINISH", nil);
//                } else {
//                    hud.labelText = NSLocalizedString(@"SETTING_FORMAT_FAILED", nil);
//                }
//                
//                [MBProgressHUD hideHUDForView:self.view.window animated:YES];
                NSString *text = formatOK?NSLocalizedString(@"SETTING_FORMAT_FINISH", nil):NSLocalizedString(@"SETTING_FORMAT_FAILED", nil);
                [self showProgressHUDCompleteMessage:text];
            });
            
        });
        
    } else if ((buttonIndex == 1) && (alertView.tag == 1)) {
        udpateFWCompleteListener = new UpdateFWCompleteListener(self);
        [_ctrl.comCtrl addObserver:ICATCH_EVENT_FW_UPDATE_COMPLETED
                          listener:udpateFWCompleteListener
                       isCustomize:NO];
        updateFWPowerOffListener = new UpdateFWCompletePowerOffListener(self);
        [_ctrl.comCtrl addObserver:ICATCH_EVENT_FW_UPDATE_POWEROFF
                          listener:updateFWPowerOffListener
                       isCustomize:NO];
        
        [self showProgressHUDWithMessage:@"Updating..."];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            AppLog(@"Start Save FW to Document Directory");
            NSString* filePath = [[NSBundle mainBundle] pathForResource:@"sphost" ofType:@"wav"];
            
            FILE *fileHandle = fopen([filePath UTF8String],"rb");
            void *buf = malloc(10*1024*1024);
            if (buf != NULL)
            {
                size_t n = fread(buf, sizeof(char), 15*1024*1024, fileHandle);
                
                NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
                NSString *cacheDirectory = [paths objectAtIndex:0];
                NSString *toFilePath = [cacheDirectory stringByAppendingPathComponent:@"sphost.BRN"];
                AppLog(@"TO : %@", toFilePath);
                FILE *toFileHandle = fopen([toFilePath cStringUsingEncoding:NSASCIIStringEncoding], "w+");
                
                fwrite(buf, sizeof(char), n, toFileHandle);
                free(buf);
                fclose(fileHandle);
                fclose(toFileHandle);
                
                AppLog(@"FW : %@", toFilePath);
                std::string path = [toFilePath cStringUsingEncoding:[NSString defaultCStringEncoding]];
                [[SDK instance] openFileTransChannel];
                [_ctrl.comCtrl updateFW:path];
                [[SDK instance] closeFileTransChannel];
            } else {
                
            }
        });
    } else if ((buttonIndex == 1) && (alertView.tag == 10)){
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [_ctrl.actCtrl cleanUpDownloadDirectory];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDCompleteMessage:@"应用空间已清理完成 !"];
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:SettingSectionTypeAlertAction]] withRowAnimation:UITableViewRowAnimationFade];
            });
            
        });
    } else if ((buttonIndex == 1) && (alertView.tag == 11)) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *rtmpUrl = [alertView textFieldAtIndex:0].text;
        AppLogDebug(AppLogTagAPP, @"rtmpUrl: %@", rtmpUrl);

        [defaults setObject:rtmpUrl forKey:@"RTMPURL"];
        [self showProgressHUDCompleteMessage:@"URL设置成功!"];
    }
}

#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewControlleVidr].
    // Pass the selected object to the new view controller.
    
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        SettingDetailViewController *detail = [segue destinationViewController];
        
        detail.subMenuTable = _subMenuTable;
        detail.curSettingDetailType = _curSettingDetailType;
        detail.curSettingDetailItem = _curSettingDetailItem;
    }
}

- (IBAction)goHome:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(goHome)]) {
        [self.delegate goHome];
    }
    [self dismissViewControllerAnimated:YES completion:^{
        AppLog(@"Setting -- QUIT");
        
    }];
}

#pragma mark -

-(void)updateFWCompleted {
    TRACE();
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDNotice:@"Update Done" showTime:1.0];
        
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_FW_UPDATE_COMPLETED
                             listener:udpateFWCompleteListener
                          isCustomize:NO];
        if (udpateFWCompleteListener) {
            delete udpateFWCompleteListener;
            udpateFWCompleteListener = NULL;
        }
    });
    
}

-(void)updateFWPowerOff {
    TRACE();
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDNotice:@"PowerOff" showTime:1.5];
        
        [_ctrl.comCtrl removeObserver:ICATCH_EVENT_FW_UPDATE_POWEROFF
                             listener:updateFWPowerOffListener
                          isCustomize:NO];
        if (updateFWPowerOffListener) {
            delete updateFWPowerOffListener;
            updateFWPowerOffListener = NULL;
        }
    });
    
}

#pragma mark - AppDelegateProtocol
- (void)sdcardRemoveCallback
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDNotice:NSLocalizedString(@"CARD_REMOVED", nil) showTime:2.0];
    });
}

@end
