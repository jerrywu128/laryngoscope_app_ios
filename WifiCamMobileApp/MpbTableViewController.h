//
//  MpbTableViewController.h
//  WifiCamMobileApp
//
//  Created by ZJ on 2017/3/24.
//  Copyright © 2017年 iCatchTech. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MpbSegmentViewController.h"
#import "VideoPlaybackViewController.h"

@interface MpbTableViewController : UITableViewController <MpbSegmentViewControllerDelegate, MWPhotoBrowserDelegate, AppDelegateProtocol, VideoPlaybackControllerDelegate>

@property(nonatomic) MpbMediaType curMpbMediaType;
@property(nonatomic, strong) NSMutableArray *assets;
@property(nonatomic, strong) ALAssetsLibrary *ALAssetsLibrary;

+ (instancetype)tableViewControllerWithIdentifier:(NSString *)identifier;

@end
