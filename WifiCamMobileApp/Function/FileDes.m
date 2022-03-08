//
//  FileDes.m
//  laryngoscope_app_ios
//
//  Created by 吳旻洋 on 2022/3/8.
//  Copyright © 2022 HonestMedical. All rights reserved.
//

#import "FileDes.h"

@implementation FileDes
+ (void) desEncrypt:(NSString*) key imageData:(UIImage *)image
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
        NSDate *date = [NSDate date];
        AppLogDebug(AppLogTagAPP, @"date ----> %@", date);
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        NSTimeZone* GTMzone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        [dateFormatter setTimeZone:GTMzone];
        [dateFormatter setDateFormat:@"yyyyMMddHHmmss"];
        
        NSString *actualStartTime = [dateFormatter stringFromDate:date];
        NSString *temp =[actualStartTime stringByAppendingString:@"E.png"];
        NSString *document = @"Documents/photo/";
        NSString *result = [document stringByAppendingString:temp];
        NSString  *pngPath = [NSHomeDirectory() stringByAppendingPathComponent:result];
        
        [[NSData dataWithBytes:(const void *)dataOut length:(NSUInteger)dataOutMoved] writeToFile:pngPath atomically:YES];
        
        if (ccStatus == kCCSuccess) {
            AppLog(@"success encryptPhoto");
        }else{
            AppLog(@"failed encryptPhoto");
        }
    }
}

+ (void) desDecrypt:(NSString*) key imageData:(NSData *)image fileName:(NSString *)fileName
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
        NSString *document = @"Documents/media/";
        NSString *result = [document stringByAppendingPathComponent:fileName];
        NSString  *pngPath = [NSHomeDirectory() stringByAppendingPathComponent:result];
            // Write the file.  Choose YES atomically to enforce an all or none write. Use the NO flag if partially written files are okay which can occur in cases of corruption
        [[NSData dataWithBytes:(const void *)dataOut length:(NSUInteger)dataOutMoved] writeToFile:pngPath atomically:YES];
        
        if (ccStatus == kCCSuccess) {
            AppLog(@"success decryptPhoto");
        }else{
            AppLog(@"failed decryptPhoto");
        }
    }
}
@end
