//
//  MpbSegmentViewController.h
//  WifiCamMobileApp
//
//  Created by ZJ on 2016/11/18.
//  Copyright © 2016年 iCatchTech. All rights reserved.
//

#import <UIKit/UIKit.h>

enum MpbState{
    MpbStateNor = 0,
    MpbStateEdit,
};

enum MpbMediaType{
    MpbMediaTypePhoto = 0,
    MpbMediaTypeVideo,
};

enum MpbShowState {
    MpbShowStateNor = 0,
    MpbShowStateInfo,
};

@class MpbSegmentViewController;

@protocol MpbSegmentViewControllerDelegate <NSObject>

- (void)mpbSegmentViewController:(MpbSegmentViewController *)mpbSegmentViewController goHome:(id)sender;
- (MpbState)mpbSegmentViewController:(MpbSegmentViewController *)mpbSegmentViewController edit:(id)sender;
- (void)mpbSegmentViewController:(MpbSegmentViewController *)mpbSegmentViewController delete:(id)sender;
- (void)mpbSegmentViewController:(MpbSegmentViewController *)mpbSegmentViewController action:(id)sender;

@end

@interface MpbSegmentViewController : UIViewController <UIScrollViewDelegate>
{
    int pageIndex;
    NSMutableArray *viewControllers;
}

@property(weak, nonatomic) IBOutlet UIBarButtonItem *actionButton;

@property (nonatomic, weak) IBOutlet id<MpbSegmentViewControllerDelegate> delegate;

@end
