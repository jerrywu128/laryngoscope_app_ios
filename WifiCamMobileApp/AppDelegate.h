//
//  AppDelegate.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 13-12-5.
//  Copyright (c) 2013年 iCatchTech. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AppDelegateProtocol <NSObject>
@optional
-(void)applicationDidEnterBackground:(UIApplication *)application NS_AVAILABLE_IOS(4_0);
-(void)applicationDidBecomeActive:(UIApplication *)application NS_AVAILABLE_IOS(4_0);
-(void)notifyPropertiesReady;
-(NSString *)notifyConnectionBroken;
- (void)sdcardRemoveCallback;
- (void)setButtonEnable:(BOOL)value;
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate, UIAlertViewDelegate>
@property (strong, nonatomic) UIWindow *window;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property(nonatomic) BOOL isReconnecting;
- (void)saveContext;
@property (nonatomic, weak) IBOutlet id<AppDelegateProtocol> delegate;
@end
