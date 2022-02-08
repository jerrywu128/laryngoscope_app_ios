//
//  WifiCamCommonControl.m
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-6-23.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#import "WifiCamCommonControl.h"
// struct statfs
#include <sys/param.h>
#include <sys/mount.h>

@implementation WifiCamCommonControl


- (void)addObserver:(ICatchEventID)eventTypeId
           listener:(ICatchWificamListener *)listener
        isCustomize:(BOOL)isCustomize {
    AppLog(@"Add Observer: [id]0x%x, [listener]%p", eventTypeId, listener);
    [[SDK instance] addObserver:eventTypeId listener:listener isCustomize:isCustomize];
}

- (void)removeObserver:(ICatchEventID)eventTypeId
              listener:(ICatchWificamListener *)listener
           isCustomize:(BOOL)isCustomize {
    AppLog(@"Remove Observer: [id]0x%x, [listener]%p", eventTypeId, listener);
    [[SDK instance] removeObserver:eventTypeId listener:listener isCustomize:isCustomize];
}

- (void)scheduleLocalNotice:(NSString *)message
{
    UIApplication  *app = [UIApplication sharedApplication];
    UILocalNotification *alarm = [[UILocalNotification alloc] init];
    if (alarm) {
        alarm.fireDate = [NSDate date];
        alarm.timeZone = [NSTimeZone defaultTimeZone];
        alarm.repeatInterval = 0;
        alarm.alertBody = message;
        alarm.soundName = UILocalNotificationDefaultSoundName;
        
        [app scheduleLocalNotification:alarm];
    }
}

- (double)freeDiskSpaceInKBytes
{
//    struct statfs buf;
    long long freeSpace = -1;
    /*
    if (statfs("/var", &buf) >= 0) {
        freeSpace = buf.f_bsize * buf.f_bfree / 1024 - 204800; // Minus 200MB to adjust the real size
    }
    */
    freeSpace = [self getFreeDiskspace] / 1024 - 204800;
    
    return freeSpace;
}

- (uint64_t)getFreeDiskspace {
    uint64_t totalSpace = 0;
    uint64_t totalFreeSpace = 0;
    NSError *error = nil;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfFileSystemForPath:[paths lastObject] error:&error];
    
    if (dict) {
        NSNumber *fileSystemSizeInBytes = [dict objectForKey:NSFileSystemSize];
        NSNumber *freeFileSystemSizeInBytes = [dict objectForKey:NSFileSystemFreeSize];
        totalSpace = [fileSystemSizeInBytes unsignedLongLongValue];
        totalFreeSpace = [freeFileSystemSizeInBytes unsignedLongLongValue];
        NSLog(@"Memory Capacity of %llu MiB with %llu MiB Free memory available.", ((totalSpace/1024)/1024), ((totalFreeSpace/1024)/1024));
    } else {
        NSLog(@"Error Obtaining System Memory Info: Domain = %@, Code = %zd", [error domain], [error code]);
    }
    
    return totalFreeSpace;
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


-(void)updateFW:(string)fwPath {
    [[SDK instance] updateFW:fwPath];
}

@end
