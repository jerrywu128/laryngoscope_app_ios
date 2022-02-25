//
//  CollectionViewController.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 13-12-5.
//  Copyright (c) 2013年 iCatchTech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MWPhotoBrowser.h"
#import "MWPhotoBrowserPrivate.h"
#import "VideoPlaybackViewController.h"
#import "ActivityWrapper.h"
#import "MpbSegmentViewController.h"

@interface MpbViewController : UICollectionViewController <UIAlertViewDelegate,
  UIPopoverControllerDelegate, MWPhotoBrowserDelegate, UIActionSheetDelegate,
  UICollectionViewDelegateFlowLayout, VideoPlaybackControllerDelegate, ActivityWrapperDelegate, MpbSegmentViewControllerDelegate>

@property(nonatomic, getter = isEnableHeader) BOOL enableHeader;
@property(nonatomic, getter = isEnableHeader) BOOL enableFooter;
@property int observerNo;
@property(nonatomic) BOOL isSend;
@property(nonatomic, strong) NSMutableArray *photos;
@property(nonatomic, strong) NSMutableArray *thumbs;
@property(nonatomic) NSMutableArray *selections;
@property(nonatomic, strong) NSMutableArray *assets;
@property(nonatomic, strong) ALAssetsLibrary *ALAssetsLibrary;

@property(nonatomic) MpbMediaType curMpbMediaType;
+ (instancetype)mpbViewControllerWithIdentifier:(NSString *)identifier;

@end
