//
//  SaveMediaInAlbum.m
//  laryngoscope_app_ios
//
//  Created by 吳旻洋 on 2022/2/24.
//  Copyright © 2022 HonestMedical. All rights reserved.
//

#import "SaveMediaInAlbum.h"

@implementation SaveMediaInAlbum
- (void)savePhoto:(UIImage *)image
 {
     /*---Check photo folder existed---*/
     NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,   NSUserDomainMask, YES);
     NSString *documentsDirectory = [paths lastObject];
     
     NSString *dataFilePath = [documentsDirectory stringByAppendingPathComponent:@"photo"];
     NSFileManager *fileManager = [NSFileManager defaultManager];

     BOOL isDir = NO;
     BOOL existed = [fileManager fileExistsAtPath:dataFilePath isDirectory:&isDir];

     if (!(isDir && existed)) {
         [fileManager createDirectoryAtPath:dataFilePath withIntermediateDirectories:YES attributes:nil error:nil];
     }
     /*--- photo save ---*/
     [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
         
         PHAssetCreationRequest *assetCreationRequest = [PHAssetCreationRequest creationRequestForAssetFromImage:image];

         
         [FileDes desEncrypt:@"test" imageData:image];
         
         /*
         NSDate *date = [NSDate date];
         AppLogDebug(AppLogTagAPP, @"date ----> %@", date);
         NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
         NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];
         [dateFormatter setTimeZone:GTMzone];
         [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
         
         NSString *actualStartTime = [dateFormatter stringFromDate:date];
         NSString *temp =[actualStartTime stringByAppendingString:@".png"];
         NSString *document = @"Documents/photo/";
         NSString *result = [document stringByAppendingString:temp];
         NSData *imgData = UIImagePNGRepresentation(image);
         NSString  *pngPath = [NSHomeDirectory() stringByAppendingPathComponent:result];
         [imgData writeToFile:pngPath atomically:YES];*/
         PHAssetCollectionChangeRequest *assetCollectionChangeRequest = nil;


         PHAssetCollection *assetCollection = [self fetchAssetCollection:NSLocalizedString(@"appName",nil)];

       
         if (assetCollection) {
             
             assetCollectionChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
         } else {
             assetCollectionChangeRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:NSLocalizedString(@"appName",nil)];
         }
       

         [assetCollectionChangeRequest addAssets:@[assetCreationRequest.placeholderForCreatedAsset]];

     } completionHandler:^(BOOL success, NSError * _Nullable error) {

         if (success) {
             AppLog(@"success savePhoto");
         } else {
             AppLog(@"failed savePhoto");
         }

     }];
 }

- (void)saveVideo:(NSURL *)videoUrl
 {
     [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
         
         PHAssetCreationRequest *assetCreationRequest = [PHAssetCreationRequest creationRequestForAssetFromVideoAtFileURL:videoUrl];

       
         PHAssetCollectionChangeRequest *assetCollectionChangeRequest = nil;


         PHAssetCollection *assetCollection = [self fetchAssetCollection:NSLocalizedString(@"appName",nil)];

       
         if (assetCollection) {
             
             assetCollectionChangeRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:assetCollection];
         } else {
             assetCollectionChangeRequest = [PHAssetCollectionChangeRequest creationRequestForAssetCollectionWithTitle:NSLocalizedString(@"appName",nil)];
         }
       
         [assetCollectionChangeRequest addAssets:@[assetCreationRequest.placeholderForCreatedAsset]];

     } completionHandler:^(BOOL success, NSError * _Nullable error) {
         if (success) {
             AppLog(@"success saveVideo");
             
         } else {
             AppLog(@"failed saveVideo");
         }
     }];
 }



 // 指定相册名称,获取相册
 - (PHAssetCollection *)fetchAssetCollection:(NSString *)title
 {
     // 获取相簿中所有自定义相册
     PHFetchResult *result = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    
     for (PHAssetCollection *assetCollection in result) {
         if ([title isEqualToString:assetCollection.localizedTitle]) {
             return assetCollection;
         }
     }
     return nil;
 }


@end
