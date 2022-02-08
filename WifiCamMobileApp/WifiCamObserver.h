//
//  WifiCamObserver.h
//  WifiCamMobileApp
//
//  Created by Guo on 6/26/15.
//  Copyright (c) 2015 iCatchTech. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ICatchWificam.h"

@interface WifiCamObserver : NSObject
@property(nonatomic) ICatchEventID eventType;
@property(nonatomic) ICatchWificamListener *listener;
@property(nonatomic) BOOL isCustomized;
@property(nonatomic) BOOL isGlobal;
-(id)initWithListener:(ICatchWificamListener *)listener1
            eventType:(ICatchEventID)eventType1
         isCustomized:(BOOL)isCustomized1
             isGlobal:(BOOL)isGlobal1;
@end
