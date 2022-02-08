//
//  SDKPrivate.h
//  WifiCamMobileApp
//
//  Created by ZJ on 2017/3/16.
//  Copyright © 2017年 iCatchTech. All rights reserved.
//

#ifndef SDKPrivate_h
#define SDKPrivate_h

typedef NS_ENUM(NSInteger, PTPDpcBurstNumber) {
    PTPDpcBurstNumber_HS = 0x0000,
    PTPDpcBurstNumber_OFF,
    PTPDpcBurstNumber_3,
    PTPDpcBurstNumber_5,
    PTPDpcBurstNumber_10,
    PTPDpcBurstNumber_7,
    PTPDpcBurstNumber_15,
    PTPDpcBurstNumber_30,
};

typedef NS_ENUM(NSInteger, PTPDpcWhiteBalance) {
    PTPDpcWhiteBalance_AUTO = 0x0001,
    PTPDpcWhiteBalance_DAYLIGHT,
    PTPDpcWhiteBalance_CLOUDY,
    PTPDpcWhiteBalance_FLUORESCENT,
    PTPDpcWhiteBalance_TUNGSTEN,
    PTPDpcWhiteBalance_UNDERWATER,
};

typedef NS_ENUM(NSInteger, CustomizePropertyID) {
    CustomizePropertyID_ScreenSaver = 0xd720,
    CustomizePropertyID_AutoPowerOff,
    CustomizePropertyID_PowerOnAutoRecord,
    CustomizePropertyID_EXposureCompensation,
    CustomizePropertyID_ImageStabilization,
    CustomizePropertyID_VideoFileLength,
    CustomizePropertyID_FastMotionMovie,
    CustomizePropertyID_WindNoiseReduction,
};

#endif /* SDKPrivate_h */
