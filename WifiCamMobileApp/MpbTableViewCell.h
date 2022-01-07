//
//  MpbTableViewCell.h
//  WifiCamMobileApp
//
//  Created by ZJ on 2017/3/24.
//  Copyright © 2017年 iCatchTech. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MpbTableViewCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *fileThumbs;

@property (nonatomic) ICatchFile *file;

- (void)setSelectedConfirmIconHidden:(BOOL)value;

@end
