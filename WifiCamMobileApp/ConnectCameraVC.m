//
//  ConnectCameraVC.m
//  laryngoscope_app_ios
//
//  Created by 吳旻洋 on 2021/12/22.
//  Copyright © 2021 HonestMedical. All rights reserved.
//

#import "ConnectCameraVC.h"
#import "WifiCamControl.h"
#import "Reachability+Ext.h"
#import "ViewController.h"
#import "GCDiscreetNotificationView.h"
#import "Camera.h"
#import "WiFiAPSetupVC.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <NetworkExtension/NetworkExtension.h>


@interface ConnectCameraVC ()
<
NSFetchedResultsControllerDelegate
>
@property(nonatomic) NSInteger AppError;
@property(nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property(weak, nonatomic) IBOutlet UILabel *ConnectLabel;
@property(weak, nonatomic) IBOutlet UIActivityIndicatorView *ActivityIndicator;
@property(strong, nonatomic) UIAlertView *connErrAlert;
@property(strong, nonatomic) UIAlertView *reconnAlert;
@property(strong, nonatomic) UIAlertView *customerIDAlert;
@property(nonatomic) WifiCam *wifiCam;
@property(nonatomic) WifiCamCamera *camera;
@property(nonatomic) WifiCamControlCenter *ctrl;
@end

@implementation ConnectCameraVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _ConnectLabel.text = NSLocalizedString(@"Video Connecting Please wait", nil);
    _ActivityIndicator.transform = CGAffineTransformMakeScale(2.0, 2.0);
    _ActivityIndicator.color = [UIColor blackColor];
    
    self.connErrAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ConnectError", nil)
                                                   message:NSLocalizedString(@"NoWifiConnection", nil)
                                                  delegate:self
                                         cancelButtonTitle:NSLocalizedString(@"Sure", nil)
                                         otherButtonTitles:nil, nil];
    _connErrAlert.tag = APP_CONNECT_ERROR_TAG;
    
    self.reconnAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ConnectError", nil)
                                                  message:NSLocalizedString(@"TimeoutError", nil)
                                                 delegate:self
                                        cancelButtonTitle:NSLocalizedString(@"STREAM_RECONNECT", nil)
                                        otherButtonTitles:nil, nil];
    _reconnAlert.tag = APP_RECONNECT_ALERT_TAG;
    
    self.customerIDAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ConnectError",nil)
                                                      message:NSLocalizedString(@"ALERT_DOWNLOAD_CORRECT_APP", nil)
                                                     delegate:self
                                            cancelButtonTitle:NSLocalizedString(@"Exit", nil)
                                            otherButtonTitles:nil, nil];
    _customerIDAlert.tag = APP_CUSTOMER_ALERT_TAG;
   
    [self splitQRInfo:_qrWifiInfo];
    [self wifiConnect];
    
 
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (void)splitQRInfo:(NSString *)Info
{
    NSArray *arrayOfComponents = [Info componentsSeparatedByString:@";"];
    _wifi_SSID = [arrayOfComponents[0] componentsSeparatedByString:@":"][2];
    _wifi_PASSWORD =[arrayOfComponents[2] componentsSeparatedByString:@":"][1];
  
}
- (NSString *)getCurrentWifi
{
    NSString *ssid = nil;
    NSArray *ifs = (__bridge id)CNCopySupportedInterfaces();
    for (NSString *ifname in ifs) {
        NSDictionary *info = (__bridge id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifname);
        if (info[@"SSID"])
        {
            ssid = info[@"SSID"];
        }
    }
    return ssid;
}

- (void)wifiConnect{
    
    NEHotspotConfiguration * hotspotConfig = [[NEHotspotConfiguration alloc] initWithSSID:_wifi_SSID passphrase:_wifi_PASSWORD isWEP:NO];
    
    [[NEHotspotConfigurationManager sharedManager] applyConfiguration:hotspotConfig completionHandler:^(NSError * _Nullable error) {
                NSLog(@"%@", error);
                if (!error) {
                    //根據名稱判斷是否鏈接成功
                   
                    if ([[self getCurrentWifi] isEqualToString:self->_wifi_SSID]) {
                        NSLog(@"鏈接成功");
                        [self _connect:@[@(self->_idx), self->_wifi_SSID]];
                        
                    }
                    if(error==nil){
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(6.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [self.view.window.rootViewController dismissViewControllerAnimated:YES completion: ^{
                                [[SDK instance] destroySDK];
                            }];
                        });
                        
                    }
                }else{
                   
                    
                    NSLog(@"%@", error.localizedDescription);
                    if ([[self getCurrentWifi] isEqualToString:self->_wifi_SSID]) {
                        NSLog(@"鏈接成功");
                        [self _connect:@[@(self->_idx), self->_wifi_SSID]];
                    }else{
                        
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self.view.window.rootViewController dismissViewControllerAnimated:YES completion: ^{
                                [[SDK instance] destroySDK];
                            }];
          
                        });
                        
                    }
                   
                }
                    
            }];
}



- (void)_connect:(id)sender
{
    self.AppError = 0;
    if (!_connErrAlert.hidden) {
        AppLog(@"dismiss connErrAlert");
        [_connErrAlert dismissWithClickedButtonIndex:0 animated:NO];
    }
    if (!_reconnAlert.hidden) {
        AppLog(@"dismiss reconnAlert");
        [_reconnAlert dismissWithClickedButtonIndex:0 animated:NO];
    }
    
 
    dispatch_async([[SDK instance] sdkQueue], ^{
        
        int totalCheckCount = 4;
        while (totalCheckCount-- > 0) {
            @autoreleasepool {
                if ([Reachability didConnectedToCameraHotspot]) {
                    if ([[SDK instance] initializeSDK]) {
                        
                        // modify by allen.chuang - 20140703
                        /*
                         if( [[SDK instance] isValidCustomerID:0x0100] == false){
                         dispatch_async(dispatch_get_main_queue(), ^{
                         AppLog(@"CustomerID mismatch");
                         [_customerIDAlert show];
                         self.AppError=1;
                         });
                         break;
                         }
                         */
                        
                        [WifiCamControl scan];
                        
                        WifiCamManager *app = [WifiCamManager instance];
                        self.wifiCam = [app.wifiCams objectAtIndex:0];
                        _wifiCam.camera = [WifiCamControl createOneCamera];
                        self.camera = _wifiCam.camera;
                        self.ctrl = _wifiCam.controler;
                        
                        if ([[SDK instance] isSDKInitialized]) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                              
                                AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
                                appDelegate.isReconnecting = NO;
                                [self performSegueWithIdentifier:@"ConnectPreviewSegue" sender:sender];
                            });
                        } else {
                            totalCheckCount = 4;
                            continue;
                        }
                        
                        return;
                    }
                }
                
                AppLog(@"[%d]NotReachable -- Sleep 500ms", totalCheckCount);
                [NSThread sleepForTimeInterval:0.5];
            }
        }
        
        if (totalCheckCount <= 0 && _AppError == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
               
                [_connErrAlert show];
            });
        }
    });
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"ConnectPreviewSegue"]) {
        NSArray *data = (NSArray *)sender;
        UINavigationController *navController = [segue destinationViewController];
        ViewController *vc = (ViewController *)navController.topViewController;
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Camera" inManagedObjectContext:self.managedObjectContext];
        [fetchRequest setEntity:entity];
        
        NSPredicate *predicate = [NSPredicate
                                  predicateWithFormat:@"id = %@",[data firstObject]];
        [fetchRequest setPredicate:predicate];
        
        NSError *error = nil;
        NSArray *fetchedObjects = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (!error && fetchedObjects && fetchedObjects.count>0) {
            
            vc.savedCamera = (Camera *)fetchedObjects[0];
            AppLog(@"Already have one camera: %d", [[data firstObject] intValue]);
        } else {
            vc.savedCamera = (Camera *)[NSEntityDescription insertNewObjectForEntityForName:@"Camera"
                                                                     inManagedObjectContext:self.managedObjectContext];
            AppLog(@"Create a camera");
        }
        vc.savedCamera.id = [data firstObject];
        vc.savedCamera.wifi_ssid = [data lastObject];
    }
}
- (void) ShowAlert:(NSString *)Message {
    UIAlertController * alert=[UIAlertController alertControllerWithTitle:nil
                                                                  message:@""
                                                           preferredStyle:UIAlertControllerStyleAlert];
    UIView *firstSubview = alert.view.subviews.firstObject;
    UIView *alertContentView = firstSubview.subviews.firstObject;
    for (UIView *subSubView in alertContentView.subviews) {
        subSubView.backgroundColor = [UIColor colorWithRed:0/255.0f green:0/255.0f blue:0/255.0f alpha:1.0f];
    }
    [alertContentView addConstraint:([NSLayoutConstraint constraintWithItem: alertContentView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem: nil attribute:NSLayoutAttributeNotAnAttribute multiplier: 1 constant: 230])];
    
    NSMutableAttributedString *AS = [[NSMutableAttributedString alloc] initWithString:Message];
    [AS addAttribute: NSFontAttributeName value: [UIFont systemFontOfSize:15]  range: NSMakeRange(0,AS.length)];
    [alert setValue:AS forKey:@"attributedTitle"];
    
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:^{
        }];
    });
}



@end
