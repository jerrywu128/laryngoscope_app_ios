//
//  AppMacro.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-2-27.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#ifndef WifiCamMobileApp_AppMacro_h
#define WifiCamMobileApp_AppMacro_h


// SDK debug toggle
#define SDK_DEBUG 1
#define APP_DEBUG 1
#define RUN_DEBUG 0
#define LIVE_DEBUG 0
#define kV50_Test 0

#import "AppLog.h"

// Debug Logging
#if (APP_DEBUG == 1) // Build Setting --> PreProcessor Macro
#define AppLog(fmt, ...) do { \
NSString *file = [[NSString alloc] initWithFormat:@"%s", __FILE__]; \
NSLog((@"%@(%d) " fmt), [file lastPathComponent], __LINE__, ##__VA_ARGS__); \
} while(0)
#define TRACE() AppLog(@"[%s][%d]", __func__, __LINE__)
#else
#define AppLog(x, ...) AppLogInfo(AppLogTagAPP, x, ##__VA_ARGS__)
#define TRACE() AppLogTRACE()
#endif

#if (RUN_DEBUG == 1)
#define RunLog(x, ...) AppLog(x)
#else
#define RunLog(x, ...)
#endif

// Check App version
#define APP_VERSION [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]

// Check iOS version
#define SYSTEM_VERSION_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v) \
([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)

#define ACTION_SHEET_DOWNLOAD_ACTIONS 2014
#define ACTION_SHEET_DELETE_ACTIONS   (ACTION_SHEET_DOWNLOAD_ACTIONS + 1)

#define APP_CONNECT_ERROR_TAG 1024
#define APP_RECONNECT_ALERT_TAG (APP_CONNECT_ERROR_TAG + 1)
#define APP_CUSTOMER_ALERT_TAG  (APP_CONNECT_ERROR_TAG + 2)
#define APP_TIMEOUT_ALERT_TAG  (APP_CONNECT_ERROR_TAG + 3)
#define APP_INPUTIPADDR_ALERT_TAG  (APP_CONNECT_ERROR_TAG + 4)
#define APP_INPUTPVURL_ALERT_TAG  (APP_CONNECT_ERROR_TAG + 5)

const int UNDEFINED_NUM = 0xffff;

#define HW_DECODE_H264
#define USE_SYSTEM_IOS7_IMPLEMENTATION 0
#define USE_SDK_EVENT_DISCONNECTED 0

#endif
