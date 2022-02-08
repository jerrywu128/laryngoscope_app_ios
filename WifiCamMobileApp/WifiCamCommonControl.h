//
//  WifiCamCommonControl.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-6-23.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MBProgressHUD.h"

@interface WifiCamCommonControl : NSObject


-(void)addObserver:(ICatchEventID)eventTypeId
          listener:(ICatchWificamListener *)listener
       isCustomize:(BOOL)isCustomize;
-(void)removeObserver:(ICatchEventID)eventTypeId
             listener:(ICatchWificamListener *)listener
          isCustomize:(BOOL)isCustomize;
-(void)scheduleLocalNotice:(NSString *)message;
-(double)freeDiskSpaceInKBytes;
-(NSString *)translateSize:(unsigned long long)sizeInKB;

//-
-(void)updateFW:(string)fwPath;
@end
