//
//  MpbTableViewController.m
//  WifiCamMobileApp
//
//  Created by ZJ on 2017/3/24.
//  Copyright © 2017年 iCatchTech. All rights reserved.
//

#import "MpbTableViewController.h"
#import "MpbTableViewCell.h"
#import "WifiCamControl.h"
#import "SDK.h"
#import "WifiCamTableViewSelectedCellTable.h"
#import "MpbPopoverViewController.h"
#import "DiskSpaceTool.h"

@interface MpbTableViewController () {
    int observerNo;
}

@property(weak, nonatomic) UIBarButtonItem *actionButton;

@property(nonatomic, strong) WifiCam *wifiCam;
@property(nonatomic, strong) WifiCamPhotoGallery *gallery;
@property(nonatomic, strong) WifiCamControlCenter *ctrl;
@property(nonatomic, strong) WifiCamFileTable *fileTable;
@property (nonatomic, strong) NSCache *mpbCache;
@property(nonatomic) BOOL downloadFileProcessing;
@property(nonatomic) dispatch_queue_t thumbnailQueue;
@property(nonatomic) dispatch_queue_t downloadQueue;
@property(nonatomic) dispatch_queue_t downloadPercentQueue;
@property(nonatomic) MpbState curMpbState;
@property(nonatomic) WifiCamTableViewSelectedCellTable *selItemsTable;
@property(nonatomic) BOOL cancelDownload;
@property(nonatomic) UIPopoverController *popController;
@property(nonatomic) unsigned long long totalDownloadSize;
@property(nonatomic) BOOL isSend;
@property(nonatomic) MBProgressHUD *progressHUD;
@property(nonatomic, getter = isFirstTimeLoaded) BOOL loaded;
@property(nonatomic) NSUInteger totalDownloadFileNumber;
@property(nonatomic) NSUInteger downloadedFileNumber;
@property(nonatomic) NSUInteger downloadedPercent;
@property(nonatomic) NSUInteger downloadedTotalPercent;
@property(nonatomic, getter = isRun) BOOL run;
@property(nonatomic) dispatch_semaphore_t mpbSemaphore;
@property(nonatomic) UIImage *videoPlaybackThumb;
@property(nonatomic) NSUInteger videoPlaybackIndex;
@property(nonatomic, strong) MWPhotoBrowser* browser;
@property(nonatomic) UIAlertController *actionSheet;
@property(nonatomic) NSUInteger totalCount;
@property(nonatomic) NSInteger downloadFailedCount;
@property(nonatomic) NSMutableArray *shareFiles;
@property(nonatomic) NSMutableArray *shareFileType;

@end

@implementation MpbTableViewController

#pragma mark - Initialization
+ (instancetype)tableViewControllerWithIdentifier:(NSString *)identifier {
    UIStoryboard *mainStoryboard;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
    } else {
        mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPad" bundle:nil];
    }
    return [mainStoryboard instantiateViewControllerWithIdentifier:identifier];
}

// 懒加载
- (NSCache *)mpbCache {
    if (_mpbCache == nil) {
        _mpbCache = [[NSCache alloc] init];
        _mpbCache.countLimit = 100;
        _mpbCache.totalCostLimit = 4096;
    }
    
    return _mpbCache;
}

- (dispatch_queue_t)thumbnailQueue {
    if (_thumbnailQueue == nil) {
        _thumbnailQueue = dispatch_queue_create("WifiCam.GCD.Queue.Playback.Thumbnail", 0);
    }
    
    return _thumbnailQueue;
}

- (dispatch_queue_t)downloadQueue {
    if (_downloadQueue == nil) {
        _downloadQueue = dispatch_queue_create("WifiCam.GCD.Queue.Playback.Download", 0);
    }
    
    return _downloadQueue;
}

- (dispatch_queue_t)downloadPercentQueue {
    if (_downloadPercentQueue == nil) {
        _downloadPercentQueue = dispatch_queue_create("WifiCam.GCD.Queue.Playback.DownloadPercent", 0);
    }
    
    return _downloadPercentQueue;
}

- (WifiCamTableViewSelectedCellTable *)selItemsTable {
    if (_selItemsTable == nil) {
        NSMutableArray *array = [[NSMutableArray alloc] init];
        _selItemsTable = [[WifiCamTableViewSelectedCellTable alloc] initWithParameters:array
                                                                    andCount:0];
    }

    return _selItemsTable;
}

- (dispatch_semaphore_t)mpbSemaphore {
    if (_mpbSemaphore == nil) {
        _mpbSemaphore = dispatch_semaphore_create(1);
    }
    
    return _mpbSemaphore;
}

- (void)resetCollectionViewData {
    AppLog(@"%s listFiles start ...",__func__);
    _wifiCam.gallery = [WifiCamControl createOnePhotoGallery];
    self.gallery = _wifiCam.gallery;
    
    NSUInteger photoListSize = _gallery.imageTable.fileList.size();
    NSUInteger videoListSize = _gallery.videoTable.fileList.size();
    unsigned long long totalPhotoKBytes = _gallery.imageTable.fileStorage;
    unsigned long long totalVideoKBytes = _gallery.videoTable.fileStorage;
    unsigned long long totalAllKBytes = totalPhotoKBytes + totalVideoKBytes;
    
    AppLog(@"photoListSize: %lu", (unsigned long)photoListSize);
    AppLog(@"videoListSize: %lu", (unsigned long)videoListSize);
    AppLog(@"totalPhotoKBytes : %llu", totalPhotoKBytes);
    AppLog(@"totalVideoKBytes : %llu", totalVideoKBytes);
    AppLog(@"totalAllKBytes : %llu", totalAllKBytes);
    AppLog(@"listFiles end ...");
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kCameraAssetsListSizeNotification"
                                                        object:@[@(photoListSize), @(videoListSize)]];
    
    if (_curMpbMediaType == MpbMediaTypePhoto) {
        if (_gallery.imageTable) {
            _fileTable = _gallery.imageTable;
            _totalCount = _gallery.imageTable.fileList.size();
        }
    } else {
        if (_gallery.videoTable) {
            _fileTable = _gallery.videoTable;
            _totalCount = _gallery.videoTable.fileList.size();
        }
    }
}

#pragma mark - lifecycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    WifiCamManager *app = [WifiCamManager instance];
    self.wifiCam = [app.wifiCams objectAtIndex:0];
    self.ctrl = _wifiCam.controler;
    
    AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    delegate.delegate = self;
}

- (void)viewWillAppear:(BOOL)animated
{
    AppLog(@"%s", __func__);
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(recoverFromDisconnection)
                                             name    :@"kCameraNetworkConnectedNotification"
                                             object  :nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(destroySDKNotification)
                                             name    :@"kCameraDestroySDKNotification"
                                             object  :nil];
    self.run = YES;
    
    if (_curMpbState == MpbStateNor) {
        [self.selItemsTable.selectedCells removeAllObjects];
        [self postButtonStateChangeNotification:NO];
    }
}

- (void)recoverFromDisconnection {
    AppLog(@"%s", __func__);
    WifiCamManager *app = [WifiCamManager instance];
    self.wifiCam = [app.wifiCams objectAtIndex:0];
    self.ctrl = _wifiCam.controler;
    
    [self.tableView reloadData];
}

- (void)destroySDKNotification
{
    AppLog(@"receive destroySDKNotification.");
    self.run = NO;
}

-(void)viewDidAppear:(BOOL)animated
{
    AppLog(@"%s", __func__);
    [super viewDidAppear:animated];
    if (!_loaded) {
        [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)
                          detailsMessage:nil
                                    mode:MBProgressHUDModeIndeterminate];
        
        // Get list and udpate collection-view
        dispatch_async(self.thumbnailQueue, ^{
            [self resetCollectionViewData];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                self.loaded = YES;
                
                [self.tableView reloadData];
            });
        });
    } else {
        [self.tableView reloadData];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    AppLog(@"%s", __func__);
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    self.run = NO;
    
    if (_popController.popoverVisible) {
        [_popController dismissPopoverAnimated:YES];
    }
#if USE_SYSTEM_IOS7_IMPLEMENTATION
    if (_actionSheet.visible) {
        [_actionSheet dismissWithClickedButtonIndex:0 animated:NO];
    }
#else
    [_actionSheet dismissViewControllerAnimated:NO completion:nil];
#endif
    
    if (self.selItemsTable.count > 0 || observerNo > 0 ) {
        [self.selItemsTable removeObserver:self forKeyPath:@"count"];
        --observerNo;
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    AppLog(@"%s", __func__);
    [super viewDidDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
    AppLog(@"%s", __func__);
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    [self.mpbCache removeAllObjects];
}

- (void)dealloc
{
    AppLog(@"%s", __func__);
    [self.mpbCache removeAllObjects];
    self.browser = nil;
}

#pragma mark - Action Progress
- (MBProgressHUD *)progressHUD {
    if (!_progressHUD) {
        _progressHUD = [[MBProgressHUD alloc] initWithView:self.view];
        _progressHUD.minSize = CGSizeMake(120, 120);
        _progressHUD.minShowTime = 1;
        // The sample image is based on the
        // work by: http://www.pixelpressicons.com
        // licence: http://creativecommons.org/licenses/by/2.5/ca/
        self.progressHUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MWPhotoBrowser.bundle/images/Checkmark.png"]];
        [self.view addSubview:_progressHUD];
    }
    return _progressHUD;
}

- (void)showProgressHUDWithMessage:(NSString *)message {
    self.progressHUD.labelText = message;
    self.progressHUD.mode = MBProgressHUDModeIndeterminate;
    [self.progressHUD show:YES];
}

- (void)showProgressHUDNotice:(NSString *)message
                     showTime:(NSTimeInterval)time{
    AppLog(@"%s", __func__);
    self.navigationController.toolbar.userInteractionEnabled = NO;
    if (message) {
        [self.view bringSubviewToFront:self.progressHUD];
        [self.progressHUD show:YES];
        self.progressHUD.labelText = message;
        self.progressHUD.mode = MBProgressHUDModeText;
        self.progressHUD.dimBackground = YES;
        [self.progressHUD hide:YES afterDelay:time];
    } else {
        [self.progressHUD hide:YES];
    }
    //self.navigationController.navigationBar.userInteractionEnabled = NO;
    self.navigationController.toolbar.userInteractionEnabled = YES;
}

- (void)showProgressHUDCompleteMessage:(NSString *)message {
    AppLog(@"%s", __func__);
    if (message) {
        if (self.progressHUD.isHidden) [self.progressHUD show:YES];
        self.progressHUD.labelText = message;
        self.progressHUD.detailsLabelText = nil;
        self.progressHUD.mode = MBProgressHUDModeCustomView;
        [self.progressHUD hide:YES afterDelay:1.0];
    } else {
        [self.progressHUD hide:YES];
    }
    //self.navigationController.navigationBar.userInteractionEnabled = YES;
    self.navigationController.toolbar.userInteractionEnabled = YES;
}

- (void)showProgressHUDWithMessage:(NSString *)message
                    detailsMessage:(NSString *)dMessage
                              mode:(MBProgressHUDMode)mode {
    AppLog(@"%s", __func__);
    self.progressHUD.labelText = message;
    self.progressHUD.detailsLabelText = dMessage;
    self.progressHUD.mode = mode;
    self.progressHUD.dimBackground = YES;
    [self.view bringSubviewToFront:self.progressHUD];
    [self.progressHUD show:YES];
    //self.navigationController.navigationBar.userInteractionEnabled = NO;
    self.navigationController.toolbar.userInteractionEnabled = NO;
    
}

- (void)updateProgressHUDWithMessage:(NSString *)message
                      detailsMessage:(NSString *)dMessage {
    AppLog(@"%s", __func__);
    if (message) {
        self.progressHUD.labelText = message;
    }
    if (dMessage) {
        self.progressHUD.progress = _downloadedPercent / 100.0;
        self.progressHUD.detailsLabelText = dMessage;
    }
}

- (void)hideProgressHUD:(BOOL)animated {
    AppLog(@"%s", __func__);
    [self.progressHUD hide:animated];
    //self.navigationController.navigationBar.userInteractionEnabled = YES;
    self.navigationController.toolbar.userInteractionEnabled = YES;
    
}

#pragma mark - MPB
- (void)goHome:(id)sender
{
    AppLog(@"%s", __func__);
    self.run = NO;
    [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)
                      detailsMessage:nil
                                mode:MBProgressHUDModeIndeterminate];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        if (dispatch_semaphore_wait(self.mpbSemaphore, time) != 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showProgressHUDCompleteMessage:NSLocalizedString(@"STREAM_WAIT_FOR_VIDEO", nil)];
            });
        } else {
            dispatch_semaphore_signal(self.mpbSemaphore);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                [self dismissViewControllerAnimated:YES completion:^{
                    AppLog(@"MPB QUIT ...");
                }];
            });
        }
    });
}

- (void)edit:(id)sender
{
    AppLog(@"%s", __func__);
    if (_curMpbState == MpbStateNor) {
        self.navigationItem.leftBarButtonItem = nil;
        self.title = NSLocalizedString(@"SelectItem", nil);
        self.curMpbState = MpbStateEdit;
        
        [self.selItemsTable addObserver:self forKeyPath:@"count" options:0x0 context:nil];
        observerNo++;
        
    } else {
        if ([_ctrl.fileCtrl isBusy]) {
            // Cancel download
            self.cancelDownload = YES;
            [_ctrl.fileCtrl cancelDownload];
        }
        
        self.curMpbState = MpbStateNor;
        
        if ([_popController isPopoverVisible]) {
            [_popController dismissPopoverAnimated:YES];
        }
        
        // Clear
        for (NSIndexPath *ip in self.selItemsTable.selectedCells) {
            //      ICatchFile *file = (ICatchFile *)[[a lastObject] pointerValue];
            MpbTableViewCell *cell = (MpbTableViewCell *)[self.tableView cellForRowAtIndexPath:ip];
            [cell setSelectedConfirmIconHidden:YES];
            cell.tag = 0;
        }
        if (!_cancelDownload) {
            [self.selItemsTable.selectedCells removeAllObjects];
        }
        
        self.selItemsTable.count = 0;
        if( observerNo>0){
            [self.selItemsTable removeObserver:self forKeyPath:@"count"];
            --observerNo;
            self.totalDownloadSize = 0;
        }
        _isSend = NO;
    }
    
    AppLog(@"%s, curMpbState: %d", __func__, _curMpbState);;
}

-(void)showPopoverFromBarButtonItem:(UIBarButtonItem *)item
                            message:(NSString *)message
                    fireButtonTitle:(NSString *)fireButtonTitle
                           callback:(SEL)fireAction
{
    AppLog(@"%s", __func__);
    MpbPopoverViewController *contentViewController = [[MpbPopoverViewController alloc] initWithNibName:@"MpbPopover" bundle:nil];
    contentViewController.msg = message;
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        contentViewController.msgColor = [UIColor blackColor];
    } else {
        contentViewController.msgColor = [UIColor whiteColor];
    }
    
    UIPopoverController *popController = [[UIPopoverController alloc] initWithContentViewController:contentViewController];
    if (fireButtonTitle) {
        UIButton *fireButton = [[UIButton alloc] initWithFrame:CGRectMake(5.0f, 110.0f, 260.0f, 47.0f)];
        popController.popoverContentSize = CGSizeMake(270.0f, 170.0f);
        fireButton.enabled = YES;
        
        [fireButton setTitle:fireButtonTitle
                    forState:UIControlStateNormal];
        [fireButton setBackgroundImage:[[UIImage imageNamed:@"iphone_delete_button.png"] stretchableImageWithLeftCapWidth:8.0f topCapHeight:0.0f]
                              forState:UIControlStateNormal];
        [fireButton addTarget:self action:fireAction forControlEvents:UIControlEventTouchUpInside];
        [contentViewController.view addSubview:fireButton];
    } else {
        popController.popoverContentSize = CGSizeMake(270.0f, 160.0f);
    }
    
    self.popController = popController;
    [_popController presentPopoverFromBarButtonItem:item permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}

-(void)showActionSheetFromBarButtonItem:(UIBarButtonItem *)item
                                message:(NSString *)message
                      cancelButtonTitle:(NSString *)cancelButtonTitle
                 destructiveButtonTitle:(NSString *)destructiveButtonTitle
                                    tag:(NSInteger)tag
{
    AppLog(@"%s", __func__);
#if USE_SYSTEM_IOS7_IMPLEMENTATION
    self.actionSheet = [[UIActionSheet alloc] initWithTitle:message
                                                   delegate:self
                                          cancelButtonTitle:cancelButtonTitle
                                     destructiveButtonTitle:destructiveButtonTitle
                                          otherButtonTitles:nil, nil];
    _actionSheet.tag = tag;
    [_actionSheet showFromBarButtonItem:item animated:YES];
#else
    self.actionSheet = [UIAlertController alertControllerWithTitle:message message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [_actionSheet addAction:[UIAlertAction actionWithTitle:cancelButtonTitle style:UIAlertActionStyleCancel handler:nil]];
    if (destructiveButtonTitle != nil) {
        [_actionSheet addAction:[UIAlertAction actionWithTitle:destructiveButtonTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
            switch (tag) {
                case ACTION_SHEET_DOWNLOAD_ACTIONS:
                    [self downloadDetail:item];
                    break;
                    
                case ACTION_SHEET_DELETE_ACTIONS:
                    [self deleteDetail:item];
                    break;
                    
                default:
                    break;
            }
        }]];
    }
    
    [self presentViewController:_actionSheet animated:YES completion:nil];
#endif
}

- (void)requestDownloadPercent:(ICatchFile *)file
{
    AppLog(@"%s", __func__);
    if (!file) {
        AppLog(@"file is null");
        return;
    }
    
    ICatchFile *f = file;
    NSString *locatePath = nil;
    NSString *fileName = [NSString stringWithUTF8String:f->getFileName().c_str()];
    unsigned long long fileSize = f->getFileSize();
    locatePath = [NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), fileName];
    AppLog(@"locatePath: %@, %llu", locatePath, fileSize);
    
    dispatch_async(self.downloadPercentQueue, ^{
        do {
            @autoreleasepool {
                if (_cancelDownload) break;
                //self.downloadedPercent = [_ctrl.fileCtrl requestDownloadedPercent:f];
                self.downloadedPercent = [_ctrl.fileCtrl requestDownloadedPercent2:locatePath
                                                                          fileSize:fileSize];
                AppLog(@"percent: %lu", (unsigned long)self.downloadedPercent);
                
                [NSThread sleepForTimeInterval:0.2];
            }
        } while (_downloadFileProcessing);
        
    });
}

- (NSArray *)downloadAllOfType:(WCFileType)type
{
    AppLog(@"%s", __func__);
    ICatchFile *file = NULL;
    vector<ICatchFile> fileList;
    NSInteger downloadedNum = 0;
    NSInteger downloadFailedCount = 0;
    
    switch (type) {
        case WCFileTypeImage:
            fileList = _gallery.imageTable.fileList;
            break;
            
        case WCFileTypeVideo:
            fileList = _gallery.videoTable.fileList;
            break;
            
        default:
            break;
    }
    
    if (![[SDK instance] openFileTransChannel]) {
        return nil;
    }
    
    for(vector<ICatchFile>::iterator it = fileList.begin();
        it != fileList.end();
        ++it) {
        if (_cancelDownload) {
            break;
        }
        
        file = &(*it);
        
        self.downloadFileProcessing = YES;
        self.downloadedPercent = 0; //Before the download clear downloadedPercent and increase downloadedFileNumber.
        self.downloadedFileNumber ++;
        [self requestDownloadPercent:file];
        //        if (![_ctrl.fileCtrl downloadFile:file]) {
        //            ++downloadFailedCount;
        //            self.downloadFileProcessing = NO;
        //            continue;
        //        }
        if (![[SDK instance] p_downloadFile2:file]) {
            ++downloadFailedCount;
            self.downloadFileProcessing = NO;
            continue;
        }
        self.downloadFileProcessing = NO;
        [NSThread sleepForTimeInterval:0.5];
        
        ++downloadedNum;
        [self.shareFiles addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), [NSString stringWithUTF8String:file->getFileName().c_str()]]]];
        [self.shareFileType addObject:[NSNumber numberWithInt:type]];
    }
    
    if (![[SDK instance] closeFileTransChannel]) {
        return nil;
    }
    
    return [NSArray arrayWithObjects:@(downloadedNum), @(downloadFailedCount), nil];
}

- (NSArray *)downloadAll
{
    AppLog(@"%s", __func__);
    NSInteger downloadedPhotoNum = 0, downloadedVideoNum = 0;
    NSInteger downloadFailedCount = 0;
    NSArray *resultArray = nil;
    
    if (_curMpbMediaType == MpbMediaTypePhoto) {
        resultArray = [self downloadAllOfType:WCFileTypeImage];
        downloadedPhotoNum = [resultArray[0] integerValue];
        downloadFailedCount += [resultArray[1] integerValue];
    } else {
        resultArray = [self downloadAllOfType:WCFileTypeVideo];
        downloadedVideoNum = [resultArray[0] integerValue];
        downloadFailedCount += [resultArray[1] integerValue];
    }
    
    [_ctrl.fileCtrl resetDownoladedTotalNumber];
    return [NSArray arrayWithObjects:@(downloadedPhotoNum), @(downloadedVideoNum), @(downloadFailedCount), nil];
}

- (void)downloadSelectedFile:(ICatchFile)f andFailedCount:(NSInteger *)downloadFailedCount andPhotoCount:(NSInteger *)downloadedPhotoNum andVideoCount:(NSInteger *)downloadedVideoNum
{
    do {
        self.downloadedFileNumber ++;
        [self requestDownloadPercent:&f];
        //        if (![_ctrl.fileCtrl downloadFile2:&f]) {
        //            ++(*downloadFailedCount);
        //            self.downloadFileProcessing = NO;
        //            continue;
        //        }
        if (![[SDK instance] p_downloadFile2:&f]) {
            ++downloadFailedCount;
            self.downloadFileProcessing = NO;
            continue;
        }
        
        self.downloadFileProcessing = NO;
        [NSThread sleepForTimeInterval:0.5];
        
        switch (f.getFileType()) {
            case TYPE_IMAGE:
                ++(*downloadedPhotoNum);
                [self.shareFiles addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), [NSString stringWithUTF8String:f.getFileName().c_str()]]]];
                [self.shareFileType addObject:[NSNumber numberWithInt:TYPE_IMAGE]];
                break;
                
            case TYPE_VIDEO:
                ++(*downloadedVideoNum);
                [self.shareFiles addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), [NSString stringWithUTF8String:f.getFileName().c_str()]]]];
                [self.shareFileType addObject:[NSNumber numberWithInt:TYPE_VIDEO]];
                break;
                
            case TYPE_TEXT:
            case TYPE_AUDIO:
            case TYPE_ALL:
            case TYPE_UNKNOWN:
            default:
                break;
        }
    } while (0);
}

- (NSArray *)shareSelectedFiles
{
    AppLog(@"%s", __func__);
    NSInteger downloadedPhotoNum = 0, downloadedVideoNum = 0;
    NSInteger downloadFailedCount = 0;
    
    ICatchFile f = NULL;
    NSString *fileName = nil;
    NSArray *tmpDirectoryContents = nil;
    
    if (![[SDK instance] openFileTransChannel]) {
        return nil;
    }
    
    for (NSIndexPath *ip in self.selItemsTable.selectedCells) {
        if (_cancelDownload) break;
        
        f = _fileTable.fileList.at(ip.item);
        
        fileName = [NSString stringWithUTF8String:f.getFileName().c_str()];
        tmpDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:nil];
        
        self.downloadFileProcessing = YES;
        self.downloadedPercent = 0;//Before the download clear downloadedPercent and increase downloadedFileNumber.
        
        if (tmpDirectoryContents.count) {
            for (NSString *name in tmpDirectoryContents) {
                if ([name isEqualToString:fileName]) {
                    NSString *filePath = [NSTemporaryDirectory() stringByAppendingPathComponent:fileName];
                    long long tempSize = [DiskSpaceTool fileSizeAtPath:filePath];
                    long long fileSize = f.getFileSize();
                    
                    if (tempSize == fileSize) {
                        [self.shareFiles addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), [NSString stringWithUTF8String:f.getFileName().c_str()]]]];
                        [self.shareFileType addObject:[NSNumber numberWithInt:f.getFileType()]];
                    } else {
                        [self downloadSelectedFile:f andFailedCount:(&downloadFailedCount) andPhotoCount:(&downloadedPhotoNum) andVideoCount:(&downloadedVideoNum)];
                    }
                    break;
                } else if ([name isEqualToString:[tmpDirectoryContents lastObject]]) {
                    [self downloadSelectedFile:f andFailedCount:(&downloadFailedCount) andPhotoCount:(&downloadedPhotoNum) andVideoCount:(&downloadedVideoNum)];
                }
            }
        } else {
            [self downloadSelectedFile:f andFailedCount:(&downloadFailedCount) andPhotoCount:(&downloadedPhotoNum) andVideoCount:(&downloadedVideoNum)];
        }
    }
    
    if (![[SDK instance] closeFileTransChannel]) {
        return nil;
    }
    
    [_ctrl.fileCtrl resetDownoladedTotalNumber];
    return [NSArray arrayWithObjects:@(downloadedPhotoNum), @(downloadedVideoNum), @(downloadFailedCount), nil];
}

- (int)videoAtPathIsCompatibleWithSavedPhotosAlbum:(int)saveNum {
    if (self.shareFileType != nil && self.shareFileType.count > 0) {
        ICatchFileType fileType = (ICatchFileType)[self.shareFileType.firstObject intValue];
        if (fileType != TYPE_VIDEO) {
            return 0;
        }
    } else {
        return 0;
    }
    
    int inCompatible = 0;
    int inCompatibleExceed = 0;
    NSString *path = nil;
    
    if (saveNum == self.shareFiles.count) {
        for (NSURL *temp in self.shareFiles) {
            path = temp.path;
            if (path != nil && !UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
                inCompatible ++;
            }
        }
    } else {
        NSURL *fileURL = nil;
        for (int i = 0; i < saveNum; i++) {
            fileURL = self.shareFiles[i];
            path = fileURL.path;
            if (path != nil && !UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
                inCompatible ++;
            }
        }
        
        for (int i = saveNum; i < self.shareFiles.count; i++) {
            fileURL = self.shareFiles[i];
            path = fileURL.path;
            if (path != nil && !UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
                inCompatibleExceed ++;
            }
        }
    }
    
    if (inCompatible || inCompatibleExceed) {
        NSString *msg = [NSString stringWithFormat:@"There is %d specified video can not be saved to user’s Camera Roll album", inCompatible + inCompatibleExceed];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:msg delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [alert show];
        });
    }
    
    return (saveNum - inCompatible);
}

- (void)showUIActivityViewController:(id)sender
{
    AppLog(@"%s", __func__);
    if (_popController.popoverVisible) {
        [_popController dismissPopoverAnimated:YES];
    }
    
    uint shareNum = (uint)[self.shareFiles count];
    uint assetNum = (uint)[[SDK instance] retrieveCameraRollAssetsResult].count;
    
    if (shareNum) {
        UIActivityViewController *activityVc = [[UIActivityViewController alloc]initWithActivityItems:self.shareFiles applicationActivities:nil];
        
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            [self presentViewController:activityVc animated:YES completion:nil];
        } else {
            // Create pop up
            UIPopoverController *activityPopoverController = [[UIPopoverController alloc] initWithContentViewController:activityVc];
            // Show UIActivityViewController in popup
            [activityPopoverController presentPopoverFromBarButtonItem:(UIBarButtonItem *)sender permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        }
        
        activityVc.completionWithItemsHandler = ^(NSString *activityType,
                                                  BOOL completed,
                                                  NSArray *returnedItems,
                                                  NSError *error) {
            if (completed) {
                AppLog(@"We used activity type: %@", activityType);
                
                if ([activityType isEqualToString:@"com.apple.UIKit.activity.SaveToCameraRoll"]) {
                    dispatch_async(dispatch_queue_create("WifiCam.GCD.Queue.Share", DISPATCH_QUEUE_SERIAL), ^{
                        [self showProgressHUDWithMessage:NSLocalizedString(@"PhotoSavingWait", nil)];
                        
                        BOOL ret;
                        AppLog(@"shareNum: %d", shareNum);
                        if (shareNum <= 5) {
                            ret = [[SDK instance] savetoAlbum:@"SBCapp" andAlbumAssetNum:assetNum andShareNum:[self videoAtPathIsCompatibleWithSavedPhotosAlbum:shareNum]];
                        } else {
                            ret = [[SDK instance] savetoAlbum:@"SBCapp" andAlbumAssetNum:assetNum andShareNum:[self videoAtPathIsCompatibleWithSavedPhotosAlbum:5]];
                            
                            for (int i = 5; i < shareNum; i++) {
                                NSURL *fileURL = self.shareFiles[i];
                                if (fileURL == nil) {
                                    continue;
                                }
                                
                                ICatchFileType fileType = (ICatchFileType)[self.shareFileType[i] intValue];
                                if (fileType == TYPE_VIDEO) {
                                    NSString *path = fileURL.path;
                                    if (path && UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path)) {
                                        [[SDK instance] addNewAssetWithURL:fileURL toAlbum:@"SBCapp" andFileType:fileType];
                                    } else {
                                        AppLog(@"The specified video can not be saved to user’s Camera Roll album");
                                    }
                                } else {
                                    [[SDK instance] addNewAssetWithURL:fileURL toAlbum:@"SBCapp" andFileType:fileType];
                                }
                            }
                        }
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:@"kCameraDownloadCompleteNotification"
                                                                                object:[NSNumber numberWithInt:ret]];
                            
                            if (ret) {
                                [self showProgressHUDCompleteMessage:NSLocalizedString(@"SavePhotoToAlbum", nil)];
                            } else {
                                [self showProgressHUDCompleteMessage:NSLocalizedString(@"SaveError", nil)];
                            }
                            
                            [self.shareFiles removeAllObjects];
                            [self.shareFileType removeAllObjects];
                        });
                    });
                }
            } else {
                AppLog(@"We didn't want to share anything after all.");
            }
            
            if (error) {
                AppLog(@"An Error occured: %@, %@", error.localizedDescription, error.localizedFailureReason);
            }
        };
    } else {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"没有选择要分享的图片或视频 !"
                                                            message:nil
                                                           delegate:nil
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                                                  otherButtonTitles:nil];
        [alertView show];
        [self.shareFiles removeAllObjects];
        [self.shareFileType removeAllObjects];
    }
}

- (void)downloadDetail:(id)sender
{
    AppLog(@"%s", __func__);
    if ([sender isKindOfClass:[UIButton self]]) {
        [_popController dismissPopoverAnimated:YES];
    }
    
    self.cancelDownload = NO;
    
    // Prepare
    if (_curMpbState == MpbStateNor) {
        [self.selItemsTable addObserver:self forKeyPath:@"count" options:0x0 context:nil];
        observerNo++;
        self.totalDownloadFileNumber = _totalCount;
    } else {
        self.totalDownloadFileNumber = self.selItemsTable.selectedCells.count;
    }

    self.downloadedFileNumber = 0;
    self.downloadedPercent = 0;
    [self addObserver:self forKeyPath:@"downloadedFileNumber" options:0x0 context:nil];
    [self addObserver:self forKeyPath:@"downloadedPercent" options:NSKeyValueObservingOptionNew context:nil];
    NSUInteger handledNum = MIN(_downloadedFileNumber, _totalDownloadFileNumber);
    NSString *msg = [NSString stringWithFormat:@"%lu / %lu", (unsigned long)handledNum, (unsigned long)_totalDownloadFileNumber];
    
    // Show processing notice
    if (!handledNum) {
        [self showProgressHUDWithMessage:@"请稍候 ..."
                          detailsMessage:nil
                                    mode:MBProgressHUDModeDeterminate];
    } else {
        [self showProgressHUDWithMessage:msg
                          detailsMessage:nil
                                    mode:MBProgressHUDModeDeterminate];
    }
    // Just in case, _selItemsTable.selectedCellsn wouldn't be destoried after app enter background
    [_ctrl.fileCtrl tempStoreDataForBackgroundDownload:self.selItemsTable.selectedCells];
    
    dispatch_async(self.downloadQueue, ^{
        NSInteger downloadedPhotoNum = 0, downloadedVideoNum = 0;
        NSInteger downloadFailedCount = 0;
        UIBackgroundTaskIdentifier downloadTask;
        NSArray *resultArray = nil;
        
        [_ctrl.fileCtrl resetBusyToggle:YES];
        // -- Request more time to excute task within background
        UIApplication  *app = [UIApplication sharedApplication];
        downloadTask = [app beginBackgroundTaskWithExpirationHandler: ^{
            
            AppLog(@"-->Expiration");
            NSArray *oldNotifications = [app scheduledLocalNotifications];
            // Clear out the old notification before scheduling a new one
            if ([oldNotifications count] > 5) {
                [app cancelAllLocalNotifications];
            }
            
            NSString *noticeMessage = [NSString stringWithFormat:@"[Progress: %lu/%lu] - App is about to exit. Please bring it to foreground to continue dowloading.", (unsigned long)handledNum, (unsigned long)_totalDownloadFileNumber];
            [_ctrl.comCtrl scheduleLocalNotice:noticeMessage];
        }];
        
        
        // ---------- Downloading
        if (_curMpbState == MpbStateNor) {
            self.curMpbState = MpbStateEdit;
            [[NSNotificationCenter defaultCenter] postNotificationName:@"kCameraUpdatePhotoGalleryEditStateNotification" object:@(self.curMpbState)];
            resultArray = [self downloadAll];
        } else {
            //            resultArray = [self downloadSelectedFiles];
            resultArray = [self shareSelectedFiles];
        }
        downloadedPhotoNum = [resultArray[0] integerValue];
        downloadedVideoNum = [resultArray[1] integerValue];
        downloadFailedCount = [resultArray[2] integerValue];
        self.downloadFailedCount = downloadFailedCount;
        // -----------
        
        
        // Download is completed, notice & update GUI
        self.totalDownloadSize = 0;
        // Post local notification
        if (app.applicationState == UIApplicationStateBackground) {
            NSString *noticeMessage = NSLocalizedString(@"SavePhotoToAlbum", @"Download complete.");
            [_ctrl.comCtrl scheduleLocalNotice:noticeMessage];
        }
        // HUD notification
        dispatch_async(dispatch_get_main_queue(), ^{
            [self removeObserver:self forKeyPath:@"downloadedFileNumber"];
            [self removeObserver:self forKeyPath:@"downloadedPercent"];
            
            [self showUIActivityViewController:self.actionButton];
            // Clear
            for (NSIndexPath *ip in self.selItemsTable.selectedCells) {
                MpbTableViewCell *cell = (MpbTableViewCell *)[self.tableView cellForRowAtIndexPath:ip];
                [cell setSelectedConfirmIconHidden:YES];
                cell.tag = 0;
            }
            [self.selItemsTable.selectedCells removeAllObjects];
            self.selItemsTable.count = 0;
            [self postButtonStateChangeNotification:NO];
            
            if (!_cancelDownload) {
                NSString *message = nil;
                if (downloadFailedCount > 0) {
                    NSString *message = NSLocalizedString(@"DownloadSelectedError", nil);
                    message = [message stringByReplacingOccurrencesOfString:@"%d" withString:[NSString stringWithFormat:@"%ld", (long)downloadFailedCount]];
                    [self showProgressHUDNotice:message showTime:0.5];
                    
                } else {
                    if (self.downloadedFileNumber) {
                        message = NSLocalizedString(@"DownloadDoneMessage", nil);
                        NSString *photoNum = [NSString stringWithFormat:@"%ld", (long)downloadedPhotoNum];
                        NSString *videoNum = [NSString stringWithFormat:@"%ld", (long)downloadedVideoNum];
                        message = [message stringByReplacingOccurrencesOfString:@"%1"
                                                                     withString:photoNum];
                        message = [message stringByReplacingOccurrencesOfString:@"%2"
                                                                     withString:videoNum];
                    }
                    [self showProgressHUDCompleteMessage:message];
                }
                
            } else {
                [self hideProgressHUD:YES];
            }
        });
        
        [_ctrl.fileCtrl resetBusyToggle:NO];
        [[UIApplication sharedApplication] endBackgroundTask:downloadTask];
    });
}

-(NSString *)translateSize:(unsigned long long)sizeInKB
{
    NSString *humanDownloadFileSize = nil;
    double temp = (double)sizeInKB/1024; // MB
    if (temp > 1024) {
        temp /= 1024;
        humanDownloadFileSize = [NSString stringWithFormat:@"%.2fGB", temp];
    } else {
        humanDownloadFileSize = [NSString stringWithFormat:@"%.2fMB", temp];
    }
    return humanDownloadFileSize;
}

-(NSString *)makeupDownloadMessageWithSize:(unsigned long long)sizeInKB
                                 andNumber:(NSInteger)num
{
    AppLog(@"%s", __func__);
    
    NSString *message = nil;
    NSString *humanDownloadFileSize = [self translateSize:sizeInKB];
    unsigned long long downloadTimeInHours = (sizeInKB/1024)/3600;
    unsigned long long downloadTimeInMinutes = (sizeInKB/1024)/60 - downloadTimeInHours*60;
    unsigned long long downloadTimeInSeconds = sizeInKB/1024 - downloadTimeInHours*3600 - downloadTimeInMinutes*60;
    AppLog(@"downloadTimeInHours: %llu, downloadTimeInMinutes: %llu, downloadTimeInSeconds: %llu",
           downloadTimeInHours, downloadTimeInMinutes, downloadTimeInSeconds);
    
    if (downloadTimeInHours > 0) {
        message = NSLocalizedString(@"DownloadConfirmMessage3", nil);
        message = [message stringByReplacingOccurrencesOfString:@"%1"
                                                     withString:[NSString stringWithFormat:@"%ld", (long)num]];
        message = [message stringByReplacingOccurrencesOfString:@"%2"
                                                     withString:[NSString stringWithFormat:@"%llu", downloadTimeInHours]];
        message = [message stringByReplacingOccurrencesOfString:@"%3"
                                                     withString:[NSString stringWithFormat:@"%llu", downloadTimeInMinutes]];
        message = [message stringByReplacingOccurrencesOfString:@"%4"
                                                     withString:[NSString stringWithFormat:@"%llu", downloadTimeInSeconds]];
    } else if (downloadTimeInMinutes > 0) {
        message = NSLocalizedString(@"DownloadConfirmMessage2", nil);
        message = [message stringByReplacingOccurrencesOfString:@"%1"
                                                     withString:[NSString stringWithFormat:@"%ld", (long)num]];
        message = [message stringByReplacingOccurrencesOfString:@"%2"
                                                     withString:[NSString stringWithFormat:@"%llu", downloadTimeInMinutes]];
        message = [message stringByReplacingOccurrencesOfString:@"%3"
                                                     withString:[NSString stringWithFormat:@"%llu", downloadTimeInSeconds]];
    } else {
        message = NSLocalizedString(@"DownloadConfirmMessage1", nil);
        message = [message stringByReplacingOccurrencesOfString:@"%1"
                                                     withString:[NSString stringWithFormat:@"%ld", (long)num]];
        message = [message stringByReplacingOccurrencesOfString:@"%2"
                                                     withString:[NSString stringWithFormat:@"%llu", downloadTimeInSeconds]];
    }
    message = [message stringByAppendingString:[NSString stringWithFormat:@"\n%@", humanDownloadFileSize]];
    return message;
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

-(void)_showDownloadConfirm:(NSString *)message
                      title:(NSString *)confrimButtonTitle
                     dBytes:(unsigned long long)downloadSizeInKBytes
                     fSpace:(double)freeDiscSpace {
    AppLog(@"%s", __func__);
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        if (downloadSizeInKBytes < freeDiscSpace) {
            [self showPopoverFromBarButtonItem:self.actionButton
                                       message:message
                               fireButtonTitle:confrimButtonTitle
                                      callback:@selector(downloadDetail:)];
        } else {
            [self showPopoverFromBarButtonItem:self.actionButton
                                       message:message
                               fireButtonTitle:nil
                                      callback:nil];
        }
        
    } else {
        [self showActionSheetFromBarButtonItem:self.actionButton
                                       message:message
                             cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                        destructiveButtonTitle:confrimButtonTitle
                                           tag:ACTION_SHEET_DOWNLOAD_ACTIONS];
    }
}

-(void)showShareConfirm
{
    AppLog(@"%s", __func__);
    if (_popController.popoverVisible) {
        [_popController dismissPopoverAnimated:YES];
    }
    
    if (!self.shareFiles) {
        self.shareFiles = [NSMutableArray array];
    } else {
        [self.shareFiles removeAllObjects];
    }
    
    if (!self.shareFileType) {
        self.shareFileType = [NSMutableArray array];
    } else {
        [self.shareFileType removeAllObjects];
    }
    
    NSInteger fileNum = 0;
    unsigned long long downloadSizeInKBytes = 0;
    NSString *confrimButtonTitle = nil;
    NSString *message = nil;
    double freeDiscSpace = [_ctrl.comCtrl freeDiskSpaceInKBytes];
    
    if (_curMpbState == MpbStateEdit) {
        
        if (_totalDownloadSize < freeDiscSpace/2.0) {
            message = [self makeupDownloadMessageWithSize:_totalDownloadSize
                                                andNumber:self.selItemsTable.count];
            confrimButtonTitle = NSLocalizedString(@"SureDownload", @"");
        } else {
            message = [self makeupNoDownloadMessageWithSize:_totalDownloadSize];
        }
        
    } else {
        fileNum += _fileTable.fileList.size();
        downloadSizeInKBytes += _fileTable.fileStorage;
        
        if (downloadSizeInKBytes < freeDiscSpace) {
            message = [self makeupDownloadMessageWithSize:downloadSizeInKBytes
                                                andNumber:fileNum];
            confrimButtonTitle = NSLocalizedString(@"AllDownload", @"");
        } else {
            message = [self makeupNoDownloadMessageWithSize:downloadSizeInKBytes];
        }
    }
    
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0")) {
        [self _showDownloadConfirm:message title:confrimButtonTitle dBytes:downloadSizeInKBytes fSpace:freeDiscSpace];
    } else {
        [self _showDownloadConfirm:message title:confrimButtonTitle dBytes:downloadSizeInKBytes fSpace:freeDiscSpace];
    }
}

- (void)deleteDetail:(id)sender
{
    AppLog(@"%s", __func__);
    __block int failedCount = 0;
    
    if ([sender isKindOfClass:[UIButton self]]) {
        [_popController dismissPopoverAnimated:YES];
    }
    
    self.run = NO;
    [self showProgressHUDWithMessage:NSLocalizedString(@"Deleting", nil)
                      detailsMessage:nil
                                mode:MBProgressHUDModeIndeterminate];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *cachedKey = nil;
        
        dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 10ull * NSEC_PER_SEC);
        dispatch_semaphore_wait(self.mpbSemaphore, time);
        
        // Real delete icatch file & remove NSCache item
        
        for (NSIndexPath *ip in self.selItemsTable.selectedCells) {
            ICatchFile f = _fileTable.fileList.at(ip.item);

            if ([_ctrl.fileCtrl deleteFile:&f] == NO) {
                ++failedCount;
            }
            cachedKey = [NSString stringWithFormat:@"ID%d", f.getFileHandle()];
            
            [self.mpbCache removeObjectForKey:cachedKey];
        }
        
        // Update the UICollectionView's data source
        [self resetCollectionViewData];
        dispatch_semaphore_signal(self.mpbSemaphore);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (failedCount != self.selItemsTable.selectedCells.count) {
                [self.selItemsTable.selectedCells removeAllObjects];
                [self postButtonStateChangeNotification:NO];
                self.run = YES;
                [self.tableView reloadData];
            }
            
            NSString *noticeMessage = nil;
            
            if (failedCount > 0) {
                noticeMessage = NSLocalizedString(@"DeleteMultiError", nil);
                NSString *failedCountString = [NSString stringWithFormat:@"%d", failedCount];
                noticeMessage = [noticeMessage stringByReplacingOccurrencesOfString:@"%d" withString:failedCountString];
            } else {
                noticeMessage = NSLocalizedString(@"DeleteDoneMessage", nil);
            }
            [self showProgressHUDCompleteMessage:noticeMessage];
//            self.selItemsTable.count = 0;
        });
        
    });
}

- (void)delete:(id)sender
{
    AppLog(@"%s", __func__);
    if (_popController.popoverVisible) {
        [_popController dismissPopoverAnimated:YES];
    }
    
    NSString *message = NSLocalizedString(@"DeleteMultiAsk", nil);
    NSString *replaceString = [NSString stringWithFormat:@"%ld", (long)self.selItemsTable.count];
    message = [message stringByReplacingOccurrencesOfString:@"%d"
                                                 withString:replaceString];
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [self showPopoverFromBarButtonItem:sender
                                   message:message
                           fireButtonTitle:NSLocalizedString(@"SureDelete", @"")
                                  callback:@selector(deleteDetail:)];
    } else {
        [self showActionSheetFromBarButtonItem:sender
                                       message:message
                             cancelButtonTitle:NSLocalizedString(@"Cancel", @"")
                        destructiveButtonTitle:NSLocalizedString(@"SureDelete", @"")
                                           tag:ACTION_SHEET_DELETE_ACTIONS];
    }
}

-(void)prepareForAction
{
    AppLog(@"%s", __func__);
    NSInteger selectedPhotoNum = 0;
    NSInteger selectedVideoNum = 0;
    
    for (NSIndexPath *ip in self.selItemsTable.selectedCells) {
        ICatchFile f = _fileTable.fileList.at(ip.item);

        switch (f.getFileType()) {
            case TYPE_IMAGE:
                ++selectedPhotoNum;
                break;
                
            case TYPE_VIDEO:
                ++selectedVideoNum;
                break;
            default:
                break;
        }
    }
    AppLog(@"VIDEO: %ld, IMAGE: %ld", (long)selectedVideoNum, (long)selectedPhotoNum);
    
    if ((selectedPhotoNum > 0) && (selectedVideoNum > 0)) {
        NSString  *demoTitle = NSLocalizedString(@"SelectedItems", nil);
        NSString  *items = [NSString stringWithFormat:@"%ld", (long)(selectedPhotoNum + selectedVideoNum)];
        self.title = [demoTitle stringByReplacingOccurrencesOfString:@"%d" withString:items];
        
    } else if (selectedPhotoNum > 0) {
        if (selectedPhotoNum == 1) {
            self.title = NSLocalizedString(@"SelectedOnePhoto", nil);
        } else {
            NSString  *demoTitle = NSLocalizedString(@"SelectedPhotos", nil);
            NSString  *items = [NSString stringWithFormat:@"%ld", (long)selectedPhotoNum];
            self.title = [demoTitle stringByReplacingOccurrencesOfString:@"%d" withString:items];
        }
    } else if (selectedVideoNum > 0) {
        if (selectedVideoNum == 1) {
            self.title = NSLocalizedString(@"SelectedOneVideo", nil);
        } else {
            NSString  *demoTitle = NSLocalizedString(@"SelectedVideos", nil);
            NSString  *items = [NSString stringWithFormat:@"%ld", (long)selectedVideoNum];
            self.title = [demoTitle stringByReplacingOccurrencesOfString:@"%d" withString:items];
        }
    }
}

#pragma mark - Observer
- (void)observeValueForKeyPath:(NSString *)keyPath
        ofObject              :(id)object
        change                :(NSDictionary *)change
        context               :(void *)context
{
    AppLog(@"%s", __func__);
    if ([keyPath isEqualToString:@"count"]) {
        if (self.selItemsTable.count > 0) {
            [self prepareForAction];
        } else {
        }
    } else if ([keyPath isEqualToString:@"downloadedFileNumber"]) {
        NSUInteger handledNum = MIN(_downloadedFileNumber, _totalDownloadFileNumber);
        NSString *msg = [NSString stringWithFormat:@"%lu / %lu", (unsigned long)handledNum, (unsigned long)_totalDownloadFileNumber];
        [self updateProgressHUDWithMessage:msg detailsMessage:nil];
    } else if([keyPath isEqualToString:@"downloadedPercent"]) {
        NSString *msg = [NSString stringWithFormat:@"%lu%%", (unsigned long)_downloadedPercent];
        if (self.downloadedFileNumber) {
            [self updateProgressHUDWithMessage:nil detailsMessage:msg];
        }
    }
}

#pragma mark - UIPopoverControllerDelegate
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    _popController = nil;
}

#pragma mark - Table view data source
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _fileTable.fileList.size();
}

- (void)setCellTag:(MpbTableViewCell *)cell
         indexPath:(NSIndexPath *)indexPath {
    if ([self.selItemsTable.selectedCells containsObject:indexPath]) {
        [cell setSelectedConfirmIconHidden:NO];
        cell.tag = 1;
    } else {
        [cell setSelectedConfirmIconHidden:YES];
        cell.tag = 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MpbTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MyTableViewCellID" forIndexPath:indexPath];
    
    ICatchFile file = _fileTable.fileList.at(indexPath.row);
    cell.file = &file;
    if( file.getFileType() == TYPE_VIDEO){
        //NSLog(@"video duration is %u",file.getFileDuration());
    }
    [self setCellTag:cell indexPath:indexPath];

    NSString *cachedKey = [NSString stringWithFormat:@"ID%d", file.getFileHandle()];
    UIImage *image = [self.mpbCache objectForKey:cachedKey];
    
    if (image) {
        cell.fileThumbs.image = image;
    } else {
        cell.fileThumbs.image = [UIImage imageNamed:@"empty_photo"];
        
        double delayInSeconds = 0.05;
        dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(delayTime, self.thumbnailQueue, ^{
            if (!_run) {
                AppLog(@"bypass...");
                return;
            }
            
            dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 5ull * NSEC_PER_SEC);
            // Just in case, make sure the cell for this indexPath is still On-Screen.
            dispatch_semaphore_wait(self.mpbSemaphore, time);
            //if ([tableView cellForRowAtIndexPath:indexPath]) {
                UIImage *image = [[SDK instance] requestThumbnail:(ICatchFile *)&file];
                if (image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.mpbCache setObject:image forKey:cachedKey];
                        MpbTableViewCell *c = (MpbTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
                        if (c) {
                            c.fileThumbs.image = image;
                        } else {
                            // 解决thumbs显示错行
                            [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                        }
                    });
                } else {
                    AppLog(@"request thumbnail failed");
                }
            //}
            dispatch_semaphore_signal(self.mpbSemaphore);
        });
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    AppLog(@"%s, curMpbState: %d", __func__, _curMpbState);
    
    ICatchFile file = _fileTable.fileList.at(indexPath.row);

    if (_curMpbState == MpbStateNor) {
        SEL callback = nil;
        
        switch (file.getFileType()) {
            case TYPE_IMAGE:
                callback = @selector(photoSinglePlaybackCallback:);
                break;
               
            case TYPE_VIDEO:
                callback = @selector(videoSinglePlaybackCallback:);
                break;
                
            default:
                break;
        }
        
        if ([self respondsToSelector:callback]) {
            AppLog(@"callback-index: %ld", (long)indexPath.item);
            [self performSelector:callback withObject:indexPath afterDelay:0];
        } else {
            AppLog(@"It's not support to playback this file.");
        }
    } else {
        MpbTableViewCell *cell = (MpbTableViewCell *)[tableView cellForRowAtIndexPath:indexPath];
        if (cell.tag == 1) { // It's selected.
            cell.tag = 0;
            [cell setSelectedConfirmIconHidden:YES];
            [self.selItemsTable.selectedCells removeObject:indexPath];
            _totalDownloadSize -= file.getFileSize()>>10;
        } else {
            cell.tag = 1;
            [cell setSelectedConfirmIconHidden:NO];
            [self.selItemsTable.selectedCells addObject:indexPath];
            _totalDownloadSize += file.getFileSize()>>10;
        }
        
        self.selItemsTable.count = self.selItemsTable.selectedCells.count;
        
        if (self.selItemsTable.count) {
            if (!_isSend) {
                [self postButtonStateChangeNotification:YES];
            }
        } else {
            if (_isSend) {
                [self postButtonStateChangeNotification:NO];
            }
        }
    }
}

- (void)postButtonStateChangeNotification:(BOOL)state
{
    _isSend = state;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kCameraButtonsCurStateNotification"
                                                        object:@(state)];
}

#pragma mark - VideoPlaybackControllerDelegate
-(BOOL)videoPlaybackController:(VideoPlaybackViewController *)controller
            deleteVideoAtIndex:(NSUInteger)index
{
    AppLog(@"%s", __func__);
    NSUInteger i = 0;
    unsigned long listSize = 0;
    BOOL ret = NO;
    
    listSize = _gallery.videoTable.fileList.size();
    if (listSize>0) {
        i = MAX(0, MIN(index, listSize - 1));
        ICatchFile file = _gallery.videoTable.fileList.at(i);
        ret = [_ctrl.fileCtrl deleteFile:&file];
        if (ret) {
            NSString *cachedKey = [NSString stringWithFormat:@"ID%d", file.getFileHandle()];
            [self.mpbCache removeObjectForKey:cachedKey];
            [self resetCollectionViewData];
        }
    }
    
    return ret;
}

#pragma mark - UITableViewDelegate
- (void)photoSinglePlaybackCallback:(NSIndexPath *)indexPath {
    self.browser = [_ctrl.fileCtrl createOneMWPhotoBrowserWithDelegate:self];
    [_browser setCurrentPhotoIndex:indexPath.item];
    
    [self.navigationController pushViewController:self.browser animated:YES];
}

- (void)videoSinglePlaybackCallback:(NSIndexPath *)indexPath
{
    AppLog(@"%s", __func__);
    if (![_ctrl.fileCtrl isVideoPlaybackEnabled]) {
        [self showProgressHUDNotice:NSLocalizedString(@"ShowNoViewVideoTip", nil) showTime:1.0];
        return;
    }
    
    ICatchFile file = _fileTable.fileList.at(indexPath.item);
    
    NSString *cachedKey = [NSString stringWithFormat:@"ID%d", file.getFileHandle()];
    _videoPlaybackIndex = indexPath.item;
    
    UIImage *image = [self.mpbCache objectForKey:cachedKey];
    if (!image) {
        dispatch_suspend(self.thumbnailQueue);
        
        [self showProgressHUDWithMessage:NSLocalizedString(@"STREAM_ERROR_CAPTURING_CAPTURE", nil)
                          detailsMessage:nil
                                    mode:MBProgressHUDModeIndeterminate];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (!_run) {
                return;
            }
            
            dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, 5ull * NSEC_PER_SEC);
            dispatch_semaphore_wait(self.mpbSemaphore, time);
            
            UIImage *image = [_ctrl.fileCtrl requestThumbnail:(ICatchFile *)&file];
            if (image != nil) {
                [self.mpbCache setObject:image forKey:cachedKey];
            }
            dispatch_semaphore_signal(self.mpbSemaphore);
            dispatch_resume(self.thumbnailQueue);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self hideProgressHUD:YES];
                _videoPlaybackThumb = image;
                //[self performSegueWithIdentifier:@"PlaybackVideoSegue" sender:nil];
                [self presentVideoPlaybackViewController];
            });
        });
    } else {
        _videoPlaybackThumb = image;
        //[self performSegueWithIdentifier:@"PlaybackVideoSegue" sender:nil];
        [self presentVideoPlaybackViewController];
    }
}

- (void)presentVideoPlaybackViewController {
    UIStoryboard  *mainStoryboard = nil;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
    } else {
        mainStoryboard = [UIStoryboard storyboardWithName:@"Main_iPad" bundle:nil];
    }
    
    UINavigationController *nc = [mainStoryboard instantiateViewControllerWithIdentifier:@"PlaybackVideoID"];;
    nc.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    
    VideoPlaybackViewController *vpvc = (VideoPlaybackViewController *)nc.topViewController;
    vpvc.delegate = self;
    vpvc.previewImage = _videoPlaybackThumb;
    vpvc.index = _videoPlaybackIndex;
    
    [self presentViewController:nc animated:YES completion:nil];
}

- (void)allPlaybackCallback:(NSIndexPath *)indexPath
{
    AppLog(@"%s", __func__);
    ICatchFile file = _fileTable.fileList.at(indexPath.item);
    
    switch (file.getFileType()) {
        case TYPE_IMAGE:
            [self photoSinglePlaybackCallback:indexPath];
            break;
            
        case TYPE_VIDEO:
            [self videoSinglePlaybackCallback:indexPath];
            break;
            
        default:
            [self nonePlaybackCallback:indexPath];
            break;
    }
}

- (void)nonePlaybackCallback:(NSIndexPath *)indexPath
{
    AppLog(@"%s", __func__);
    [self showProgressHUDCompleteMessage:NSLocalizedString(@"It's not supported yet.", nil)];
}

#pragma mark - MWPhotoBrowserDataSource
- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser
{
    AppLog(@"%s", __func__);
    return _gallery.imageTable.fileList.size();
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser
                photoAtIndex:(NSUInteger)index
{
    AppLog(@"%s(%lu)", __func__, (unsigned long)index);
    MWPhoto *photo = nil;
    unsigned long listSize = 0;

    listSize = _gallery.imageTable.fileList.size();
    ICatchFile file = _gallery.imageTable.fileList.at(index);
    
    if (index < listSize) {
        photo = [MWPhoto photoWithURL:[NSURL URLWithString:@"sdk://test"] funcBlock:^{
            return [_ctrl.fileCtrl requestImage:(ICatchFile *)&file];
        }];
    }
    
    return photo;
}

- (void)showShareConfirmForphotoBrowser
{
    NSIndexPath *ip = [self.selItemsTable.selectedCells firstObject];
    ICatchFile f = _fileTable.fileList.at(ip.item);
    
    NSString *fileName = [NSString stringWithUTF8String:f.getFileName().c_str()];
    NSArray *tmpDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:nil];
    
    self.downloadFileProcessing = YES;
    self.downloadedPercent = 0;
    if (tmpDirectoryContents.count) {
        for (NSString *name in tmpDirectoryContents) {
            if ([name isEqualToString:fileName]) {
                [self.shareFiles addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), [NSString stringWithUTF8String:f.getFileName().c_str()]]]];
                break;
            } else if ([name isEqualToString:[tmpDirectoryContents lastObject]]) {
                if ([[SDK instance] p_downloadFile:&f]) {
                    [self.shareFiles addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), [NSString stringWithUTF8String:f.getFileName().c_str()]]]];
                }
            }
        }
    } else {
        if ([[SDK instance] p_downloadFile:&f]) {
            [self.shareFiles addObject:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@%@", NSTemporaryDirectory(), [NSString stringWithUTF8String:f.getFileName().c_str()]]]];
        }
    }
}

#pragma mark - MWPhotoBrowserDelegate
-(void)photoBrowser:(MWPhotoBrowser *)photoBrowser actionButtonPressedForPhotoAtIndex:(NSUInteger)index {
    AppLog(@"%s", __func__);
    if (!self.shareFiles) {
        self.shareFiles = [NSMutableArray array];
    } else {
        [self.shareFiles removeAllObjects];
    }

    [self.selItemsTable.selectedCells removeAllObjects];
    [self.selItemsTable.selectedCells addObject:[NSIndexPath indexPathForItem:index inSection:0]];
}

- (BOOL)photoBrowser      :(MWPhotoBrowser *)photoBrowser
        deletePhotoAtIndex:(NSUInteger)index
{
    AppLog(@"%s", __func__);
    NSUInteger i = 0;
    unsigned long listSize = 0;
    BOOL ret = NO;

    listSize = _gallery.imageTable.fileList.size();
    if (listSize>0) {
        i = MAX(0, MIN(index, listSize - 1));
        ICatchFile file = _gallery.imageTable.fileList.at(i);
        ret = [_ctrl.fileCtrl deleteFile:&file];
        if (ret) {
            NSString *cachedKey = [NSString stringWithFormat:@"ID%d", file.getFileHandle()];
            [self.mpbCache removeObjectForKey:cachedKey];
            [self resetCollectionViewData];
        }
    }
    
    return ret;
}

-(BOOL)photoBrowser:(MWPhotoBrowser *)photoBrowser downloadPhotoAtIndex:(NSUInteger)index
{
    AppLog(@"%s", __func__);
    [self showShareConfirm];
    
    return _downloadFailedCount>0?NO:YES;
}

-(void)photoBrowser:(MWPhotoBrowser *)photoBrowser shareImageAtIndex:(NSUInteger)index {
    AppLog(@"%s", __func__);
    [self showUIActivityViewController:photoBrowser.actionButton];
}

-(void)shareImage:(MWPhotoBrowser *)photoBrowser {
    AppLog(@"%s", __func__);
    [self showShareConfirmForphotoBrowser];
}

#pragma mark - MpbSegmentViewController delegate
- (MpbState)mpbSegmentViewController:(MpbSegmentViewController *)mpbSegmentViewController edit:(id)sender
{
    [self edit:sender];
    AppLog(@"%s, curMpbState: %d", __func__, _curMpbState);
    
    return _curMpbState;
}

- (void)mpbSegmentViewController:(MpbSegmentViewController *)mpbSegmentViewController goHome:(id)sender
{
    [self goHome:sender];
}

- (void)mpbSegmentViewController:(MpbSegmentViewController *)mpbSegmentViewController delete:(id)sender
{
    [self delete:sender];
}

- (void)mpbSegmentViewController:(MpbSegmentViewController *)mpbSegmentViewController action:(id)sender
{
    self.actionButton = mpbSegmentViewController.actionButton;
    [self showShareConfirm];
}

#pragma mark AppDelegateProtocol
- (void)sdcardRemoveCallback {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showProgressHUDNotice:NSLocalizedString(@"CARD_REMOVED", nil) showTime:2.0];
    });
}

@end
