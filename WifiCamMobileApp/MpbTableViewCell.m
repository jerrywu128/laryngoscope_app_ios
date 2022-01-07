//
//  MpbTableViewCell.m
//  WifiCamMobileApp
//
//  Created by ZJ on 2017/3/24.
//  Copyright © 2017年 iCatchTech. All rights reserved.
//

#import "MpbTableViewCell.h"

@interface MpbTableViewCell()

@property (weak, nonatomic) IBOutlet UILabel *fileNameLab;
@property (weak, nonatomic) IBOutlet UILabel *fileSizeLab;
@property (weak, nonatomic) IBOutlet UILabel *fileDateLab;

@property(weak, nonatomic) IBOutlet UIImageView *selectedComfirmIcon;
@property(weak, nonatomic) IBOutlet UIImageView *videoStaticIcon;

@end

@implementation MpbTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void)setFile:(ICatchFile *)file {
    _file = file;
    
    self.fileNameLab.text = [NSString stringWithFormat:@"%s", file->getFileName().c_str()];
    self.fileSizeLab.text = [self translateSize:file->getFileSize()>>10];
    self.fileDateLab.text = [self translateDate:file->getFileDate()];//[NSString stringWithFormat:@"%s", file->getFileDate().c_str()];
    self.videoStaticIcon.hidden = file->getFileType() == TYPE_IMAGE ? YES : NO;
}

- (NSString *)translateSize:(unsigned long long)sizeInKB
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

- (NSString *)translateDate:(string)date {
    NSMutableString *dateStr = [NSMutableString string];
    
    NSString *dateString = [NSString stringWithFormat:@"%s", date.c_str()];
    //AppLogDebug(AppLogTagAPP, @"dateString: %@", dateString);
    
    if (dateString.length == 15) {
        [dateStr appendString:[dateString substringWithRange:NSMakeRange(0, 4)]];
        [dateStr appendString:@"-"];
        [dateStr appendString:[dateString substringWithRange:NSMakeRange(4, 2)]];
        [dateStr appendString:@"-"];
        [dateStr appendString:[dateString substringWithRange:NSMakeRange(6, 2)]];
        [dateStr appendString:@" "];
        [dateStr appendString:[dateString substringWithRange:NSMakeRange(9, 2)]];
        [dateStr appendString:@":"];
        [dateStr appendString:[dateString substringWithRange:NSMakeRange(11, 2)]];
        [dateStr appendString:@":"];
        [dateStr appendString:[dateString substringWithRange:NSMakeRange(13, 2)]];
        
        return dateStr.copy;
    } else {
        return dateString;
    }
}

- (void)setSelectedConfirmIconHidden:(BOOL)value
{
    [self.selectedComfirmIcon setHidden:value];
}

@end
