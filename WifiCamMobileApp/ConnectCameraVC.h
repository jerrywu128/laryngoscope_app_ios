//
//  ConnectCameraVC.h
//  laryngoscope_app_ios
//
//  Created by 吳旻洋 on 2021/12/22.
//  Copyright © 2021 HonestMedical. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <NetworkExtension/NetworkExtension.h>
#import <SystemConfiguration/CaptiveNetwork.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConnectCameraVC : UIViewController
@property(nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property(nonatomic) NSUInteger idx;
@property(nonatomic) NSString *cameraSSID;
@property(nonatomic) NSString *qrWifiInfo;
@property(nonatomic) NSString *wifi_SSID;
@property(nonatomic) NSString *wifi_PASSWORD;
@end

NS_ASSUME_NONNULL_END
