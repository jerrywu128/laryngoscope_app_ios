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
    
    [self initPhotoGallery];
}

//创建pagecontrol
-(void)createPagrVC
{
    self.pageView.delegate = self;
    self.pageView.contentSize = CGSizeMake(CGRectGetWidth(self.pageView.frame) * PAGES, CGRectGetHeight(self.pageView.frame));
    //AppLog(@"----------> contentSize: %@", NSStringFromCGSize(self.pageView.contentSize));
    
    [self setCurViewController:MpbMediaTypePhoto];
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
        
        if (_curShowState) {
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
}

- (IBAction)videosBtnClink:(id)sender {
    [self setCurViewController:MpbMediaTypeVideo];
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
        if (!_curShowState) {
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

@end
