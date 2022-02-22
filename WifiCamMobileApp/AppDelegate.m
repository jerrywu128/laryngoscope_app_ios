//
//  AppDelegate.m
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 13-12-5.
//  Copyright (c) 2013年 iCatchTech. All rights reserved.
//

#import "AppDelegate.h"
#import "ExceptionHandler.h"
#ifdef DEBUG
#include "ICatchWificamConfig.h"
#endif
#import "ViewController.h"
#import "HomeVC.h"
#include "WifiCamSDKEventListener.h"
#import "WifiCamControl.h"
#import "Reachability+Ext.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import "GCDiscreetNotificationView.h"

//#import <BuglyHotfix/Bugly.h>
#import <GoogleSignIn/GoogleSignIn.h>

@interface AppDelegate ()
@property(nonatomic) BOOL enableLog;
@property(nonatomic) FILE *appLogFile;
//@property (nonatomic) FILE *sdkLogFile;
@property(nonatomic) WifiCamObserver *globalObserver;
@property(strong, nonatomic) UIAlertView *reconnectionAlertView;
@property(strong, nonatomic) UIAlertView *connectionErrorAlertView;
@property(strong, nonatomic) UIAlertView *connectionErrorAlertView1;
@property(strong, nonatomic) UIAlertView *connectingAlertView;
@property(nonatomic) NSString *current_ssid;
@property(nonatomic, retain) GCDiscreetNotificationView *notificationView;
@property(nonatomic) NSTimer *timer;
@property(nonatomic) WifiCamObserver *sdcardRemoveObserver;
@property(nonatomic) BOOL isTimeout;
@property(nonatomic) NSTimer *timeOutTimer;
@end


#define UmengAppkey @"55765a2467e58ed0a60031d8"
static NSString * const kClientID = @"759186550079-prbjm58kcrideo6lh4uukdqqp2q9bc67.apps.googleusercontent.com";

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [[GIDSignIn sharedInstance] handleURL:url
                               sourceApplication:sourceApplication
                                      annotation:annotation];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSDate *date = [NSDate date];

    //[Bugly startWithAppId:nil]; //add bugly SDK 2016.12.28
    // Exception handler
    [self registerDefaultsFromSettingsBundle];

    // Set app's client ID for |GIDSignIn|.
    [GIDSignIn sharedInstance].clientID = kClientID;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults stringForKey:@"RTMPURL"]) {
        [defaults setObject:@"rtmp://a.rtmp.youtube.com/live2/7m5m-wuhz-ryaq-89ss" forKey:@"RTMPURL"];
    }
    
    // Enalbe log
    NSUserDefaults *defaultSettings = [NSUserDefaults standardUserDefaults];
    self.enableLog = [defaultSettings boolForKey:@"PreferenceSpecifier:Log"];
    
//    self.enableLog = YES; // Test on iOS9
    if (_enableLog) {
        [self startLogToFile];
    } else {
        [self cleanLogs];
    }
    
    AppLogInfo(AppLogTagAPP, @"=================== app run starting ====================");
    AppLogInfo(AppLogTagAPP, @"App Version: %@", [defaultSettings stringForKey:@"PreferenceSpecifiers:1"]);
    AppLogInfo(AppLogTagAPP, @"Build: %@", [defaultSettings stringForKey:@"PreferenceSpecifiers:2"]);
    
    NSDateFormatter *dateformatter = [[NSDateFormatter alloc] init];
    [dateformatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    AppLogInfo(AppLogTagAPP, @"Run Date: %@", [dateformatter stringFromDate:date]);
    AppLogInfo(AppLogTagAPP, @"=========================================================");
    
    //
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    
    //
    UINavigationController *rootNavController = (UINavigationController *)self.window.rootViewController;
    HomeVC *homeVC = (HomeVC *)rootNavController.topViewController;
    homeVC.managedObjectContext = self.managedObjectContext;
    
    self.connectionErrorAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ConnectError", nil)
          message                                         :NSLocalizedString(@"NoWifiConnection", nil)
          delegate                                        :self
          cancelButtonTitle                               :NSLocalizedString(@"Exit", nil)
          otherButtonTitles                               :nil, nil];
    _connectionErrorAlertView.tag = APP_CONNECT_ERROR_TAG;
    
    self.connectionErrorAlertView1 = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ConnectError", nil)
                                                    message:NSLocalizedString(@"Connected to other Wi-Fi", nil)
                                                   delegate:self
                                          cancelButtonTitle:NSLocalizedString(@"Exit", nil)
                                          otherButtonTitles:nil, nil];
    _connectionErrorAlertView1.tag = APP_CONNECT_ERROR_TAG;
    
    self.reconnectionAlertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ConnectError", nil)
                                       message           :NSLocalizedString(@"TimeoutError", nil)
                                       delegate          :self
                                       cancelButtonTitle :NSLocalizedString(@"STREAM_RECONNECT", nil)
                                       otherButtonTitles :NSLocalizedString(@"Exit", nil), nil];
    _reconnectionAlertView.tag = APP_RECONNECT_ALERT_TAG;
    
    [self addGlobalObserver];
    //[[Reachability reachabilityForLocalWiFi] startNotifier];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDisconnectionEvent) name:kReachabilityChangedNotification object:nil];
    self.isReconnecting = YES;
    if (![self.timer isValid]) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(checkCurrentNetworkStatus)
                                                    userInfo:nil repeats:YES];
    }

    return YES;
}

- (void)checkCurrentNetworkStatus
{
    if (![Reachability didConnectedToCameraHotspot]) {
        if (!_isReconnecting) {
            [self notifyDisconnectionEvent];
        }
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, doneand throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    
    TRACE();
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    TRACE();
    
    [self removeGlobalObserver];
    //[[Reachability reachabilityForLocalWiFi] stopNotifier];
    //[[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    [self.timer invalidate];
    _isReconnecting = NO;
    [self.timeOutTimer invalidate];
    _isTimeout = NO;
    
    if (![[SDK instance] isBusy]) {
        if ([self.delegate respondsToSelector:@selector(applicationDidEnterBackground:)]) {
            AppLog(@"Execute delegate method.");
            [self.delegate applicationDidEnterBackground:nil];
        } else {
            AppLog(@"Execute default method.");
            dispatch_sync([[SDK instance] sdkQueue], ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"kCameraDestroySDKNotification"
                                                                    object:nil];
                [[SDK instance] destroySDK];
            });
        }
        
        [self.window.rootViewController dismissViewControllerAnimated:YES completion: nil];
    } else {
        NSTimeInterval ti = 0;
        ti = [[UIApplication sharedApplication] backgroundTimeRemaining];
        NSLog(@"backgroundTimeRemaining: %f", ti);
    }
    
    if (!_connectingAlertView.hidden) {
        [_connectingAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    if (!_connectionErrorAlertView.hidden) {
        [_connectionErrorAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
    if (!_connectionErrorAlertView1.hidden) {
        [_connectionErrorAlertView1 dismissWithClickedButtonIndex:0 animated:NO];
    }
    if (!_reconnectionAlertView.hidden) {
        [_reconnectionAlertView dismissWithClickedButtonIndex:0 animated:NO];
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    TRACE();
    
    [self addGlobalObserver];
    //[[Reachability reachabilityForLocalWiFi] startNotifier];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyDisconnectionEvent) name:kReachabilityChangedNotification object:nil];
    if (![self.timer isValid]) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(checkCurrentNetworkStatus)
                                                    userInfo:nil repeats:YES];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    
    TRACE();
#ifdef DEBUG
    //  NSUserDefaults *defaultSettings = [NSUserDefaults standardUserDefaults];
    //  if (![defaultSettings integerForKey:@"PreviewCacheTime"]) {
    //    AppLog(@"loading default value...");
    //    [self performSelector:@selector(registerDefaultsFromSettingsBundle)];
    //  }
    
    /*
     NSInteger pct = [[NSUserDefaults standardUserDefaults] integerForKey:@"PreviewCacheTime"];
     AppLog(@"pct: %d", pct);
     ICatchWificamConfig *config = new ICatchWificamConfig();
     config->setPreviewCacheParam(pct);
     delete config; config = NULL;
     */
    
    /*
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
//    enableDumpMediaStream  parameter: videoStream --> true:video false:audio
    ICatchWificamConfig::getInstance()->enableDumpMediaStream(true, documentsDirectory.UTF8String);
    */
#endif
    /*
     if (![[SDK instance] isSDKInitialized]) {
     //
     UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"Disconnected from camera." delegate:self cancelButtonTitle:@"Back" otherButtonTitles:@"Reconnect", nil];
     alert.tag = 1000;
     [alert show];
     
     return;
     }
     */
    
    
    if ([self.delegate respondsToSelector:@selector(applicationDidBecomeActive:)]) {
        [self.delegate applicationDidBecomeActive:nil];
    }    
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    AppLog(@"%s", __func__);
    //[[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    
    if (_enableLog) {
        [self stopLog];
    }
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    TRACE();
}

#pragma mark - Log

- (void)startLogToFile
{
    // Get the document directory
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    // Name the log folder & file
    NSDate *date = [NSDate date];
    NSDateFormatter *dateformatter = [[NSDateFormatter alloc] init];
    [dateformatter setDateFormat:@"yyyyMMdd-HHmmss"];
    NSString *name = [dateformatter stringFromDate:date];
    NSString *appLogFileName = [NSString stringWithFormat:@"APP-%@.log", name];
    // Create the log folder
    NSString *logDirectory = [documentsDirectory stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] createDirectoryAtPath:logDirectory withIntermediateDirectories:NO attributes:nil error:nil];
    // Create(Open) the log file
    NSString *appLogFilePath = [logDirectory stringByAppendingPathComponent:appLogFileName];
    self.appLogFile = freopen([appLogFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
    
    //NSString *sdkLogFileName = [NSString stringWithFormat:@"SDK-%@.log", [NSDate date]];
    //NSString *sdkLogFilePath = [documentsDirectory stringByAppendingPathComponent:sdkLogFileName];
    //self.sdkLogFile = freopen([sdkLogFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
    
    // Log4SDK
    [[SDK instance] enableLogSdkAtDiretctory:logDirectory enable:YES];
    
    TRACE();
}

- (void)stopLog
{
    TRACE();
    fclose(_appLogFile);
    //fclose(_sdkLogFile);
}

- (void)cleanLogs
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSArray *documentsDirectoryContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:documentsDirectory error:nil];
    NSString *logFilePath = nil;
    for (NSString *fileName in  documentsDirectoryContents) {
        if (![fileName isEqualToString:@"Camera.sqlite"] && ![fileName isEqualToString:@"Camera.sqlite-shm"] && ![fileName isEqualToString:@"Camera.sqlite-wal"]) {
            
            logFilePath = [documentsDirectory stringByAppendingPathComponent:fileName];
            [[NSFileManager defaultManager] removeItemAtPath:logFilePath error:nil];
        }
        
    }
}

// retrieve the default setting values
- (void)registerDefaultsFromSettingsBundle {
    NSString *settingsBundle = [[NSBundle mainBundle] pathForResource:@"Settings" ofType:@"bundle"];
    if(!settingsBundle) {
        NSLog(@"Could not find Settings.bundle");
        return;
    }
    
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:[settingsBundle stringByAppendingPathComponent:@"Root.plist"]];
    NSArray *preferences = [settings objectForKey:@"PreferenceSpecifiers"];
    
    NSMutableDictionary *defaultsToRegister = [[NSMutableDictionary alloc] initWithCapacity:[preferences count]];
    for(NSDictionary *prefSpecification in preferences) {
        NSString *key = [prefSpecification objectForKey:@"Key"];
        if(key) {
            [defaultsToRegister setObject:[prefSpecification objectForKey:@"DefaultValue"] forKey:key];
        }
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsToRegister];
}

#pragma mark - Core Data stack

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    return _managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel {
    
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    //NSURL* modelURL=[[NSBundle mainBundle] URLForResource:@"Camera" withExtension:@"momd"];
    //_managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    
    return _managedObjectModel;
}

/**
 Returns the URL to the application's documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    // copy the default store (with a pre-populated data) into our Documents folder
    //
    NSString *documentsStorePath =
    [[[self applicationDocumentsDirectory] path] stringByAppendingPathComponent:@"Camera.sqlite"];
    AppLog(@"sqlite's path: %@", documentsStorePath);
   
    // if the expected store doesn't exist, copy the default store
    if (![[NSFileManager defaultManager] fileExistsAtPath:documentsStorePath]) {
        NSString *defaultStorePath = [[NSBundle mainBundle] pathForResource:@"Camera" ofType:@"sqlite"];
        if (defaultStorePath) {
            [[NSFileManager defaultManager] copyItemAtPath:defaultStorePath toPath:documentsStorePath error:NULL];
        }
    }
    
    _persistentStoreCoordinator =
    [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    // add the default store to our coordinator
    NSError *error;
    NSURL *defaultStoreURL = [NSURL fileURLWithPath:documentsStorePath];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil
                                                             URL:defaultStoreURL
                                                         options:nil
                                                           error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible
         * The schema for the persistent store is incompatible with current managed object model
         Check the error message to determine what the actual problem was.
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
#ifdef DEBUG
        abort();
#endif
    }
    
    
    return _persistentStoreCoordinator;
}

#pragma mark - Core Data Saving support
- (void)saveContext {
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        NSError *error = nil;
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
#ifdef DEBUG
            abort();
#endif
        }
    }
}
#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (alertView.tag) {
        case APP_RECONNECT_ALERT_TAG:
            if (buttonIndex == 0) {
               [self globalReconnect];
            } else if (buttonIndex == 1) {
                [self.window.rootViewController dismissViewControllerAnimated:YES completion: nil];
                //exit(0);
            }
            
            break;
            
        case APP_CONNECT_ERROR_TAG:
            if (buttonIndex == 0) {
                [self.window.rootViewController dismissViewControllerAnimated:YES completion: nil];
                //exit(0);
            }
            break;
            
        case APP_CUSTOMER_ALERT_TAG:
            [[SDK instance] destroySDK];
            exit(0);
            break;
            
        case APP_TIMEOUT_ALERT_TAG:
            if (buttonIndex == 0) {
                AppLogTRACE();
                [self.window.rootViewController dismissViewControllerAnimated:YES completion:^{
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        [[SDK instance] destroySDK];
                    });
                }];
            }
            break;
            
        default:
            break;
    }
}

#pragma mark - Observer
-(void)addGlobalObserver {
#if USE_SDK_EVENT_DISCONNECTED
    WifiCamSDKEventListener *listener = new WifiCamSDKEventListener(self, @selector(notifyDisconnectionEvent));
    self.globalObserver = [[WifiCamObserver alloc] initWithListener:listener eventType:ICATCH_EVENT_CONNECTION_DISCONNECTED isCustomized:NO isGlobal:YES];
    [[SDK instance] addObserver:_globalObserver];
#else
#endif
    
    WifiCamSDKEventListener *sdcardRemovelistener = new WifiCamSDKEventListener(self, @selector(notifySdCardRemoveEvent));
    self.sdcardRemoveObserver = [[WifiCamObserver alloc] initWithListener:sdcardRemovelistener eventType:ICATCH_EVENT_SDCARD_REMOVED isCustomized:NO isGlobal:YES];
    [[SDK instance] addObserver:self.sdcardRemoveObserver];
}

-(void)removeGlobalObserver {
#if USE_SDK_EVENT_DISCONNECTED
    [[SDK instance] removeObserver:_globalObserver];
    delete _globalObserver.listener;
    _globalObserver.listener = NULL;
    self.globalObserver = nil;
#esle
#endif
    
    [[SDK instance] removeObserver:self.sdcardRemoveObserver];
    delete self.sdcardRemoveObserver.listener;
    self.sdcardRemoveObserver.listener = NULL;
    self.sdcardRemoveObserver = nil;
}

- (void)notifySdCardRemoveEvent
{
    AppLog(@"SDCardRemoved event was received.");
    if ([self.delegate respondsToSelector:@selector(sdcardRemoveCallback)]) {
        [self.delegate sdcardRemoveCallback];
    }
}

-(void)notifyDisconnectionEvent {
#if USE_SDK_EVENT_DISCONNECTED
#else
    if (_current_ssid && [[self checkSSID] isEqualToString:_current_ssid] && [Reachability didConnectedToCameraHotspot]) {
        return;
    }
#endif
    
    AppLog(@"Disconnectino event was received.");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"kCameraNetworkDisconnectedNotification"
                                                        object:nil];

    _current_ssid = nil;
    if ([self.delegate respondsToSelector:@selector(notifyConnectionBroken)]) {
        _current_ssid = [self.delegate notifyConnectionBroken];
    } else {
        dispatch_async([[SDK instance] sdkQueue], ^{
            [[SDK instance] destroySDK];
        });
    }
    
    if (_current_ssid) {
        [NSThread sleepForTimeInterval:0.03];
        [self globalReconnect];
        
        if (![self.timeOutTimer isValid]) {
            self.timeOutTimer = [NSTimer scheduledTimerWithTimeInterval:55.0 target:self selector:@selector(timeOutHandle) userInfo:nil repeats:NO];
        }
    } else {
        if (!_reconnectionAlertView.visible) {
            dispatch_async(dispatch_get_main_queue(), ^{
                //[_reconnectionAlertView show];
                _isReconnecting = YES;
            });
        }
    }
//    //[self removeGlobalObserver];
//    if (!_reconnectionAlertView.visible) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [_reconnectionAlertView show];
//        });
//    }
}

-(void)globalReconnect
{
    TRACE();
    // [self addGlobalObserver];
#if USE_SDK_EVENT_DISCONNECTED
    if ([[SDK instance] isConnected]) {
        return;
    }
#else
    if (!_isTimeout) {
        if ([Reachability didConnectedToCameraHotspot] && [[SDK instance] isConnected]) {
            return;
        }
    }
#endif
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!_current_ssid) {
            TRACE();
            if (!_connectingAlertView) {
                self.connectingAlertView = [[UIAlertView alloc] initWithTitle:nil
                                                                      message:NSLocalizedString(@"Connecting", nil)
                                                                     delegate:nil
                                                            cancelButtonTitle:nil
                                                            otherButtonTitles:nil, nil];
            }
            
            [_connectingAlertView show];
        } else {
            TRACE();
            NSString *connectingMessage = [NSString stringWithFormat:@"%@ %@ ...", NSLocalizedString(@"Reconnect to",nil),_current_ssid];
            [self showGCDNoteWithMessage:connectingMessage withAnimated:YES withAcvity:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"kCameraReconnectNotification"
                                                                object:self.notificationView];
        }
        
        _isReconnecting = YES;
        dispatch_async([[SDK instance] sdkQueue], ^{
//            [NSThread sleepForTimeInterval:1.0];
            
            int totalCheckCount = 30; // 60times : 30s
            while (totalCheckCount-- > 0 && !_isTimeout) {
                @autoreleasepool {
                    if ([Reachability didConnectedToCameraHotspot]) {
                        [[SDK instance] destroySDK];
                        if ([[SDK instance] initializeSDK]) {
                            [WifiCamControl scan];
                            
                            WifiCamManager *app = [WifiCamManager instance];
                            WifiCam *wifiCam = [app.wifiCams objectAtIndex:0];
                            wifiCam.camera = [WifiCamControl createOneCamera];
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                _isReconnecting = NO;
                                
                                if (!_current_ssid) {
                                    [_connectingAlertView dismissWithClickedButtonIndex:0 animated:NO];
                                } else {
                                    [self hideGCDiscreetNoteView:YES];
                                }
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"kCameraNetworkConnectedNotification"
                                                                                    object:nil];
                            });
                            break;
                        }
                    }
                    
                    AppLog(@"[%d]NotReachable -- Sleep 500ms", totalCheckCount);
                    [NSThread sleepForTimeInterval:0.5];
                }
            }
            
            if (totalCheckCount <= 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!_current_ssid) {
                        [_connectingAlertView dismissWithClickedButtonIndex:0 animated:NO];
                    } else {
                        [self hideGCDiscreetNoteView:YES];
                    }
//                    [_reconnectionAlertView show];
                    NSString *ssid = [self checkSSID];
                    if (ssid == nil) {
                        [_connectionErrorAlertView show];
                    } else {
                        if (_current_ssid && ![ssid isEqualToString:_current_ssid]) {
                            [_connectionErrorAlertView1 show];
                        } else {
                            //[_reconnectionAlertView show];
                        }
                    }
                });
            }
            self.isTimeout = NO;
            [self.timeOutTimer invalidate];
        });
    });
}

- (void)timeOutHandle
{
    if (![[SDK instance] isConnected]) {
        TRACE();
        self.isTimeout = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            /*if (!_current_ssid) {
                [_connectingAlertView dismissWithClickedButtonIndex:0 animated:NO];
            } else {
                [self hideGCDiscreetNoteView:YES];
            }
            NSString *ssid = [self checkSSID];
            if (ssid == nil) {
                [_connectionErrorAlertView show];
            } else {
                if (_current_ssid && ![ssid isEqualToString:_current_ssid]) {
                    [_connectionErrorAlertView1 show];
                } else {
                    [_reconnectionAlertView show];
                }
            }*/
            UIAlertView *timeOutAlert = [[UIAlertView alloc] initWithTitle:nil
                                               message           :NSLocalizedString(@"ActionTimeOut.", nil)
                                               delegate          :self
                                               cancelButtonTitle :NSLocalizedString(@"Exit", nil)
                                               otherButtonTitles :nil, nil];
            timeOutAlert.tag = APP_TIMEOUT_ALERT_TAG;
            [timeOutAlert show];
        });
    }
}

- (NSString *)checkSSID
{
    //    NSArray * networkInterfaces = [NEHotspotHelper supportedNetworkInterfaces];
    //    NSLog(@"Networks: %@",networkInterfaces);
    
    NSString *ssid = nil;
    //NSString *bssid = @"";
    CFArrayRef myArray = CNCopySupportedInterfaces();
    if (myArray) {
        CFDictionaryRef myDict = CNCopyCurrentNetworkInfo((CFStringRef)CFArrayGetValueAtIndex(myArray, 0));
        /*
         Core Foundation functions have names that indicate when you own a returned object:
         
         Object-creation functions that have “Create” embedded in the name;
         Object-duplication functions that have “Copy” embedded in the name.
         If you own an object, it is your responsibility to relinquish ownership (using CFRelease) when you have finished with it.
         
         */
        CFRelease(myArray);
        if (myDict) {
            NSDictionary *dict = (NSDictionary *)CFBridgingRelease(myDict);
            ssid = [dict valueForKey:@"SSID"];
            //bssid = [dict valueForKey:@"BSSID"];
        }
    }
    AppLog(@"ssid : %@", ssid);
    //NSLog(@"bssid: %@", bssid);
    
    return ssid;
}

-(GCDiscreetNotificationView *)notificationView {
    if (!_notificationView) {
        _notificationView = [[GCDiscreetNotificationView alloc] initWithText:nil
                                                                showActivity:NO
                                                          inPresentationMode:GCDiscreetNotificationViewPresentationModeTop
                                                                      inView:((ViewController *)(self.delegate)).view];
    }
    return _notificationView;
}

- (void)showGCDNoteWithMessage:(NSString *)message
                  withAnimated:(BOOL)animated
                    withAcvity:(BOOL)activity{
    TRACE();
    if ([self.delegate respondsToSelector:@selector(setButtonEnable:)]) {
        [self.delegate setButtonEnable:NO];
    }
    [self.notificationView setView:((ViewController *)(self.delegate)).view];
    [self.notificationView setTextLabel:message];
    [self.notificationView setShowActivity:activity];
    [self.notificationView show:animated];
    
}

- (void)showGCDNoteWithMessage:(NSString *)message
                       andTime:(NSTimeInterval) timeInterval
                    withAcvity:(BOOL)activity{
    [self.notificationView setTextLabel:message];
    [self.notificationView setShowActivity:activity];
    [self.notificationView showAndDismissAfter:timeInterval];
    
}

- (void)hideGCDiscreetNoteView:(BOOL)animated {
    if ([self.delegate respondsToSelector:@selector(setButtonEnable:)]) {
        [self.delegate setButtonEnable:YES];
    }
    [self.notificationView hide:animated];
    
}

@end
