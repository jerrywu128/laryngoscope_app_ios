//
//  MpbSegmentViewController.m
//  WifiCamMobileApp
//
//  Created by ZJ on 2016/11/18.
//  Copyright © 2016年 iCatchTech. All rights reserved.
//

#import "MpbSegmentViewController.h"
#import "MpbViewController.h"
#import "MpbTableViewController.h"

#define BACKGROUNDCOLOR [UIColor colorWithRed:230 / 255.0 green:230 / 255.0 blue:230 / 255.0 alpha:1.0]
#define PAGES 2

@interface MpbSegmentViewController ()
@property (weak, nonatomic) IBOutlet UIScrollView *pageView;

@property (weak, nonatomic) IBOutlet UIButton *photosBtn;
@property (weak, nonatomic) IBOutlet UIButton *videosBtn;

@property(weak, nonatomic) IBOutlet UIBarButtonItem *deleteButton;
@property(strong, nonatomic) IBOutlet UIBarButtonItem *doneButton;
@property(weak, nonatomic) IBOutlet UIBarButtonItem *editButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *infoButton;

- (IBAction)photosBtnClink:(id)sender;
- (IBAction)videosBtnClink:(id)sender;

- (IBAction)goHome:(id)sender;
- (IBAction)edit:(id)sender;
- (IBAction)delete:(id)sender;
- (IBAction)action:(id)sender;
- (IBAction)info:(id)sender;

@property (nonatomic) NSArray *valueArr;

@property (nonatomic) MpbViewController *curVc;
@property (nonatomic) MpbTableViewController *curTableVc;
@property (nonatomic, assign) MpbShowState curShowState;
@property (nonatomic, assign) MpbMediaType curMediaType;

@end

@implementation MpbSegmentViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self createPagrVC];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateBtnText:)
                                             name    :@"kCameraAssetsListSizeNotification"
                                             object  :nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateButtonEnableState:)
                                             name    :@"kCameraButtonsCurStateNotification"
                                             object  :nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updatePhotoGalleryEditState:)
                                             name    :@"kCameraUpdatePhotoGalleryEditStateNotification"
                                             object  :nil];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    [self updatePageViewFrame];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadAssets];
    [self initPhotoGallery];
    [self test];
}

//创建pagecontrol
-(void)createPagrVC
{
    self.pageView.delegate = self;
    self.pageView.contentSize = CGSizeMake(CGRectGetWidth(self.pageView.frame) * PAGES, CGRectGetHeight(self.pageView.frame));
    //AppLog(@"----------> contentSize: %@", NSStringFromCGSize(self.pageView.contentSize));
    
    [self setCurViewController:MpbMediaTypePhoto];
    
    
}

- (void)test
{
    NSMutableArray *photos = [[NSMutableArray alloc] init];
    NSMutableArray *thumbs = [[NSMutableArray alloc] init];
    MWPhoto *photo, *thumb;
    BOOL displayActionButton = YES;
    BOOL displaySelectionButtons = NO;
    BOOL displayNavArrows = NO;
    BOOL enableGrid = YES;
    BOOL startOnGrid = YES;
    BOOL autoPlayOnAppear = NO;
    @synchronized(_assets) {
        NSMutableArray *copy = [_assets copy];
        if (NSClassFromString(@"PHAsset")) {
            // Photos library
            UIScreen *screen = [UIScreen mainScreen];
            CGFloat scale = screen.scale;
            // Sizing is very rough... more thought required in a real implementation
            CGFloat imageSize = MAX(screen.bounds.size.width, screen.bounds.size.height) * 1.5;
            CGSize imageTargetSize = CGSizeMake(imageSize * scale, imageSize * scale);
            CGSize thumbTargetSize = CGSizeMake(imageSize / 3.0 * scale, imageSize / 3.0 * scale);
            for (PHAsset *asset in copy) {
                
                    [photos addObject:[MWPhoto photoWithAsset:asset targetSize:imageTargetSize]];
                    [thumbs addObject:[MWPhoto photoWithAsset:asset targetSize:thumbTargetSize]];
               
            }
        } else {
            // Assets library
            for (ALAsset *asset in copy) {
               
                    photo = [MWPhoto photoWithURL:asset.defaultRepresentation.url];
                    [photos addObject:photo];
                    thumb = [MWPhoto photoWithImage:[UIImage imageWithCGImage:asset.thumbnail]];
                    [thumbs addObject:thumb];
                

            }
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
    
    [self presentViewController:nc animated:YES completion:nil];

    
    // Test reloading of data after delay
    double delayInSeconds = 3;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    });
    
}


- (void)setCurViewController:(MpbMediaType)type
{
    if (!_curVc) {
        if (_curTableVc && type == _curTableVc.curMpbMediaType) {
            return;
        }
        [self createPageViewController:type];
    } else {
        if (type == _curVc.curMpbMediaType) {
            return;
        } else {
            [UIView animateWithDuration:0.2 animations:^{
                [_curVc.view removeFromSuperview];
                [_curVc removeFromParentViewController];
                _curVc = nil;
                
                [self createPageViewController:type];
            }];
        }
    }
    self.pageView.contentOffset = CGPointMake(type * CGRectGetWidth(self.pageView.frame), 0);
    
    [self setButtonBackgroundColor:type];
}

- (void)createPageViewController:(MpbMediaType)type
{
    @autoreleasepool {
        
        [_curTableVc.view removeFromSuperview];
        [_curTableVc removeFromParentViewController];
        _curTableVc = nil;
        
        NSString *pageId = [NSString stringWithFormat:@"page%i", type];
        MpbViewController *pvController = [MpbViewController  mpbViewControllerWithIdentifier:pageId];
        pvController.curMpbMediaType = type;
        pvController.view.frame = CGRectMake(CGRectGetWidth(self.pageView.frame) * type, 0, CGRectGetWidth(self.pageView.frame), CGRectGetHeight(self.pageView.frame));
        
        /*
        [_curVc.view removeFromSuperview];
        [_curVc removeFromParentViewController];
        _curVc = nil;
        
        MpbTableViewController *pvController = [MpbTableViewController  tableViewControllerWithIdentifier:@"TableViewID"];
        pvController.curMpbMediaType = _curMediaType;
        pvController.view.frame = CGRectMake(CGRectGetWidth(self.pageView.frame) * _curMediaType, 0, CGRectGetWidth(self.pageView.frame), CGRectGetHeight(self.pageView.frame));
        */
        self.delegate = pvController;
        _curVc = pvController;
        
        _curMediaType = type;
        _curShowState = MpbShowStateNor;
        
        [self addChildViewController:pvController];
        [self.pageView addSubview:pvController.view];
        
        //[self.pageView scrollRectToVisible:pvController.view.frame animated:YES];
        
        [self initPhotoGallery];
    }
}

- (void)initPhotoGallery
{
    AppLog(@"%s", __func__);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.navigationItem.leftBarButtonItem = self.doneButton;
        self.title = NSLocalizedString(@"Albums", @"");
        self.editButton.title = NSLocalizedString(@"Edit", @"");
        self.doneButton.title = NSLocalizedString(@"Done", @"");
        self.deleteButton.enabled = NO;
        self.actionButton.enabled = YES;
        
        if (!_curShowState) {
            self.infoButton.image = [UIImage imageNamed:@"UIBarButtonItemGrid"];
        } else {
            self.infoButton.image = [UIImage imageNamed:@"info"];
        }
    });
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset
{
    CGFloat targetX = (targetContentOffset->x + CGRectGetWidth(self.pageView.frame) * 0.5);
    pageIndex = targetX / CGRectGetWidth(self.pageView.frame);
    
    [self setCurViewController:(MpbMediaType)pageIndex];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)photosBtnClink:(id)sender {
    [self setCurViewController:MpbMediaTypePhoto];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self ShowAlert:@"ph."];
    });
}

- (IBAction)videosBtnClink:(id)sender {
    [self setCurViewController:MpbMediaTypeVideo];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self ShowAlert:@"vd."];
    });
}

- (IBAction)goHome:(id)sender {
    if ([self.delegate respondsToSelector:@selector(mpbSegmentViewController:goHome:)]) {
        [self.delegate mpbSegmentViewController:self goHome:sender];
    }
}

- (IBAction)edit:(id)sender {
    if ([self.delegate respondsToSelector:@selector(mpbSegmentViewController:edit:)]) {
        [self updatePhotoGallery:[self.delegate mpbSegmentViewController:self edit:sender]];
    }
}

- (IBAction)delete:(id)sender {
    if ([self.delegate respondsToSelector:@selector(mpbSegmentViewController:delete:)]) {
        [self.delegate mpbSegmentViewController:self delete:sender];
    }
}

- (IBAction)action:(id)sender {
    if ([self.delegate respondsToSelector:@selector(mpbSegmentViewController:action:)]) {
        [self.delegate mpbSegmentViewController:self action:sender];
    }
}

- (IBAction)info:(id)sender {
    AppLogInfo(AppLogTagAPP, "===========");

    @autoreleasepool {
        if (!_curShowState) {//!ini
            [_curVc.view removeFromSuperview];
            [_curVc removeFromParentViewController];
            _curVc = nil;
            
            MpbTableViewController *pvController = [MpbTableViewController  tableViewControllerWithIdentifier:@"TableViewID"];
            pvController.curMpbMediaType = _curMediaType;
            pvController.view.frame = CGRectMake(CGRectGetWidth(self.pageView.frame) * _curMediaType, 0, CGRectGetWidth(self.pageView.frame), CGRectGetHeight(self.pageView.frame));
            
            self.delegate = pvController;
            _curTableVc = pvController;
            
            [self addChildViewController:pvController];
            [self.pageView addSubview:pvController.view];
            
            //[self.pageView scrollRectToVisible:pvController.view.frame animated:YES];
            
            [self initPhotoGallery];
            self.pageView.contentOffset = CGPointMake(_curMediaType * CGRectGetWidth(self.pageView.frame), 0);
           
            _curShowState = MpbShowStateInfo;
        } else {
            [_curTableVc.view removeFromSuperview];
            [_curTableVc removeFromParentViewController];
            _curTableVc = nil;
            
            [self setCurViewController:_curMediaType];
            
            _curShowState = MpbShowStateNor;
            self.pageView.contentOffset = CGPointMake(_curMediaType * CGRectGetWidth(self.pageView.frame), 0);
        }
    }
}

- (void)updatePhotoGallery:(BOOL)value
{
    AppLogTRACE();
//    self.deleteButton.enabled = value;
    dispatch_async(dispatch_get_main_queue(), ^{
        self.deleteButton.enabled = NO;
        
        if (value == MpbStateEdit) {
            self.navigationItem.leftBarButtonItem = nil;
            self.title = NSLocalizedString(@"SelectItem", nil);
            self.editButton.title = NSLocalizedString(@"Cancel", @"");
            self.editButton.style = UIBarButtonItemStyleDone;
            self.actionButton.enabled = NO;
        } else {
            self.navigationItem.leftBarButtonItem = self.doneButton;
            self.title = NSLocalizedString(@"Albums", nil);
            self.editButton.title = NSLocalizedString(@"Edit", @"");
            
            if (_curVc.curMpbMediaType == MpbMediaTypePhoto && [_valueArr[0] unsignedIntegerValue]) {
                self.actionButton.enabled = YES;
            }else if (_curVc.curMpbMediaType == MpbMediaTypeVideo && [_valueArr[1] unsignedIntegerValue]) {
                self.actionButton.enabled = YES;
            } else self.actionButton.enabled = NO;
        }
    });
}

- (void)updatePhotoGalleryEditState:(NSNotification *)notification
{
    [self updatePhotoGallery:[notification.object boolValue]];
}

- (void)updateButtonEnableState:(NSNotification*)notification
{
    BOOL ret = [notification.object boolValue];
    
    self.actionButton.enabled = ret;
    self.deleteButton.enabled = ret;
}

- (void)setButtonBackgroundColor:(MpbMediaType)type
{
    [UIView animateWithDuration:2.0 animations:^{
        if (type == MpbMediaTypePhoto) {
            _photosBtn.backgroundColor = [UIColor whiteColor];
            _videosBtn.backgroundColor = BACKGROUNDCOLOR;
        } else {
            _photosBtn.backgroundColor = BACKGROUNDCOLOR;
            _videosBtn.backgroundColor = [UIColor whiteColor];
        }
    }];
}

- (void)updateBtnText:(NSNotification*)notification
{
    _valueArr = notification.object;
    //AppLog(@"===========> %@", valueArr);

    dispatch_async(dispatch_get_main_queue(), ^{
        if ((_curVc && _curVc.curMpbMediaType == MpbMediaTypePhoto) || (_curTableVc && _curTableVc.curMpbMediaType == MpbMediaTypePhoto)) {
            if ([_valueArr[0] unsignedIntegerValue]) {
                self.actionButton.enabled = YES;
                self.editButton.enabled = YES;
            } else {
                [self updatePhotoGallery:MpbStateNor];
                self.editButton.enabled = NO;
            }
        } else {
            if ([_valueArr[1] unsignedIntegerValue]) {
                self.actionButton.enabled = YES;
                self.editButton.enabled = YES;
            } else {
                [self updatePhotoGallery:MpbStateNor];
                self.editButton.enabled = NO;
            }
        }
        
        [self.photosBtn setTitle:[NSString stringWithFormat:@"Photos (%@)", _valueArr[0]] forState:UIControlStateNormal];
        [self.videosBtn setTitle:[NSString stringWithFormat:@"Videos (%@)", _valueArr[1]] forState:UIControlStateNormal];
    });
}

- (void)updatePageViewFrame {
    self.pageView.contentSize = CGSizeMake(CGRectGetWidth(self.pageView.frame) * PAGES, CGRectGetHeight(self.pageView.frame));
    
    if (!_curShowState) {
        _curVc.view.frame = CGRectMake(CGRectGetWidth(self.pageView.frame) * _curVc.curMpbMediaType, 0, CGRectGetWidth(self.pageView.frame), CGRectGetHeight(self.pageView.frame));
        self.pageView.contentOffset = CGPointMake(_curVc.curMpbMediaType * CGRectGetWidth(self.pageView.frame), 0);
    } else {
        _curTableVc.view.frame = CGRectMake(CGRectGetWidth(self.pageView.frame) * _curMediaType, 0, CGRectGetWidth(self.pageView.frame), CGRectGetHeight(self.pageView.frame));
        self.pageView.contentOffset = CGPointMake(_curMediaType * CGRectGetWidth(self.pageView.frame), 0);
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self updatePageViewFrame];
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

#pragma mark - Load Assets
- (void)loadAssets {
    // get current SSID

    
    if (NSClassFromString(@"PHAsset")) {
        // Check library permissions
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status == PHAuthorizationStatusNotDetermined) {
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    [self performLoadAssets];
                }
            }];
        } else if (status == PHAuthorizationStatusAuthorized) {
            [self performLoadAssets];
        }
    } else {
        // Assets library
        [self performLoadAssets];
    }
    
 
}

- (void)performLoadAssets {
    
    // Initialise
    if (!_assets) {
        _assets = [NSMutableArray new];
    } else {
        [_assets removeAllObjects];
    }
    
  
    // Load
    if (NSClassFromString(@"PHAsset")) {
        
        // Photos library iOS >= 8
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            PHFetchResult *assetsFetchResult = nil;
            PHFetchResult *topLevelUserCollections = [PHCollectionList fetchTopLevelUserCollectionsWithOptions:nil];
            for (int i=0; i<topLevelUserCollections.count; ++i) {
                PHCollection *collection = [topLevelUserCollections objectAtIndex:i];
                if ([collection.localizedTitle isEqualToString:NSLocalizedString(@"appName",nil)]) {
                    if (![collection isKindOfClass:[PHAssetCollection class]]) {
                        continue;
                    }
                    // Configure the AAPLAssetGridViewController with the asset collection.
                    PHAssetCollection *assetCollection = (PHAssetCollection *)collection;
                    PHFetchOptions *options = [PHFetchOptions new];
                    options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
                    assetsFetchResult = [PHAsset fetchAssetsInAssetCollection:assetCollection options:options];
                    break;
                }
            }
            if (!assetsFetchResult) {
                AppLog(@"assetsFetchResult was nil.");
                return;
            }
            
            [assetsFetchResult enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                //Add
                [_assets addObject:obj];
            }];
        });
        
    } else {
        
        /*
         ALAssetsLibrary：代表整个PhotoLibrary，我们可以生成一个它的实例对象，这个实例对象就相当于是照片库的句柄。
         ALAssetsGroup：照片库的分组，我们可以通过ALAssetsLibrary的实例获取所有的分组的句柄。
         ALAsset：一个ALAsset的实例代表一个资产，也就是一个photo或者video，我们可以通过他的实例获取对应的缩略图或者原图等等。
         */
        
        // Assets Library iOS < 8
        _ALAssetsLibrary = [[ALAssetsLibrary alloc] init];
        // Run in the background as it takes a while to get all assets from the library
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            NSMutableArray *assetGroups = [[NSMutableArray alloc] init];
            NSMutableArray *assetURLDictionaries = [[NSMutableArray alloc] init];
            
            // Process assets
            void (^assetEnumerator)(ALAsset *, NSUInteger, BOOL *) = ^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if (result) {
                    NSString *assetType = [result valueForProperty:ALAssetPropertyType];
                    
                   
                    
                    if ([assetType isEqualToString:ALAssetTypePhoto] || [assetType isEqualToString:ALAssetTypeVideo]) {
                        [assetURLDictionaries addObject:[result valueForProperty:ALAssetPropertyURLs]];
                        NSURL *url = result.defaultRepresentation.url;
                        [_ALAssetsLibrary assetForURL:url
                                          resultBlock:^(ALAsset *asset) {
                                              if (asset) {
                                                  @synchronized(_assets) {
                                                      [_assets addObject:asset];
                                                  }
                                              }
                                          }
                                         failureBlock:^(NSError *error){
                                             NSLog(@"operation was not successfull!");
                                         }];
                    }
                }
            };
            
            // Process groups
            void (^ assetGroupEnumerator) (ALAssetsGroup *, BOOL *) = ^(ALAssetsGroup *group, BOOL *stop) {
                if (group) {
                    [group enumerateAssetsWithOptions:NSEnumerationReverse usingBlock:assetEnumerator];
                    [assetGroups addObject:group];
                }
            };
            
            // Process!
            [_ALAssetsLibrary enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                                            usingBlock:assetGroupEnumerator
                                          failureBlock:^(NSError *error) {
                                              NSLog(@"There is an error");
                                          }];
            
        });
        
    }
    
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

- (void)photoBrowserDidFinishModalPresentation:(MWPhotoBrowser *)photoBrowser {
    // If we subscribe to this method we must dismiss the view controller ourselves
    NSLog(@"Did finish modal presentation");
    [self dismissViewControllerAnimated:YES completion:nil];
}


@end
