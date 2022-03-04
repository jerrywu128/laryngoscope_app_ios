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
     [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
         
         PHAssetCreationRequest *assetCreationRequest = [PHAssetCreationRequest creationRequestForAssetFromImage:image];

         [self des:@"test" imageData:image];
         NSData *imgData = UIImagePNGRepresentation(image);
         NSString  *jpgPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/ori.png"];
         [imgData writeToFile:jpgPath atomically:YES];
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


- (void) des:(NSString*) key imageData:(UIImage *)image
{
    
    
    NSData *data = UIImagePNGRepresentation(image);
    
    CCCryptorStatus ccStatus;
    
    uint8_t *dataOut = NULL;
    size_t dataOutAvailable = 0; //size_t  是操作符sizeof返回的结果类型
    size_t dataOutMoved = 0;
 
    dataOutAvailable = (data.length + kCCBlockSizeDES) & ~(kCCBlockSizeDES - 1);
    dataOut = static_cast<uint8_t *>(malloc( dataOutAvailable * sizeof(uint8_t)));
    memset((void *)dataOut, 0x0, dataOutAvailable);//将已开辟内存空间buffer的首 1 个字节的值设为值 0
 
    NSString *initIv = key;
    const void *vkey = (const void *) [key UTF8String];
    const void *iv = (const void *) [initIv UTF8String];
 
    //CCCrypt函数 加密/解密
    ccStatus = CCCrypt(kCCEncrypt,               //  加密/解密
                       kCCAlgorithmDES,          //  加密根据哪个标准（des，3des，aes。。。。）
                       kCCOptionPKCS7Padding,    //  选项分组密码算法(des:对每块分组加一次密  3DES：对每块分组加三个不同的密)
                       vkey,                     //  密钥
                       kCCKeySizeDES,            //  DES 密钥的大小（kCCKeySizeDES=8）
                       iv,                       //  可选的初始矢量
                       [data bytes],             //  数据的存储单元
                       data.length,              // 数据的大小
                       (void *)dataOut,          // 用于返回数据
                       dataOutAvailable,
                       &dataOutMoved);
    @autoreleasepool {
    NSString  *jpgPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Test.png"];
        // Write the file.  Choose YES atomically to enforce an all or none write. Use the NO flag if partially written files are okay which can occur in cases of corruption
    [[NSData dataWithBytes:(const void *)dataOut length:(NSUInteger)dataOutMoved] writeToFile:jpgPath atomically:YES];
    
    if (ccStatus == kCCSuccess) {
        AppLog(@"success encryptPhoto");
    }else{
        AppLog(@"failed encryptPhoto");
    }
   
    }
}

- (void) ddes:(NSString*) key imageData:(NSData *)image
{
    
    
    NSData *data = image;
    
    CCCryptorStatus ccStatus;
    
    uint8_t *dataOut = NULL;
    size_t dataOutAvailable = 0; //size_t  是操作符sizeof返回的结果类型
    size_t dataOutMoved = 0;
 
    dataOutAvailable = (data.length + kCCBlockSizeDES) & ~(kCCBlockSizeDES - 1);
    dataOut = static_cast<uint8_t *>(malloc( dataOutAvailable * sizeof(uint8_t)));
    memset((void *)dataOut, 0x0, dataOutAvailable);//将已开辟内存空间buffer的首 1 个字节的值设为值 0
 
    NSString *initIv = key;
    const void *vkey = (const void *) [key UTF8String];
    const void *iv = (const void *) [initIv UTF8String];
 
    //CCCrypt函数 加密/解密
    ccStatus = CCCrypt(kCCDecrypt,               //  加密/解密
                       kCCAlgorithmDES,          //  加密根据哪个标准（des，3des，aes。。。。）
                       kCCOptionPKCS7Padding,    //  选项分组密码算法(des:对每块分组加一次密  3DES：对每块分组加三个不同的密)
                       vkey,                     //  密钥
                       kCCKeySizeDES,            //  DES 密钥的大小（kCCKeySizeDES=8）
                       iv,                       //  可选的初始矢量
                       [data bytes],             //  数据的存储单元
                       data.length,              // 数据的大小
                       (void *)dataOut,          // 用于返回数据
                       dataOutAvailable,
                       &dataOutMoved);
    @autoreleasepool {
    NSString  *jpgPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/Test2.png"];
        // Write the file.  Choose YES atomically to enforce an all or none write. Use the NO flag if partially written files are okay which can occur in cases of corruption
    [[NSData dataWithBytes:(const void *)dataOut length:(NSUInteger)dataOutMoved] writeToFile:jpgPath atomically:YES];
    
    if (ccStatus == kCCSuccess) {
        AppLog(@"success decryptPhoto");
    }else{
        AppLog(@"failed decryptPhoto");
    }
   
    }
}

@end
