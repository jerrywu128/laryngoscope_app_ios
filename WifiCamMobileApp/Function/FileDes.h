//
//  FileDes.h
//  laryngoscope_app_ios
//
//  Created by 吳旻洋 on 2022/3/8.
//  Copyright © 2022 HonestMedical. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCrypto.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileDes : NSData
+ (void)desDecrypt:(NSString *)key imageData:(NSData *)image fileName:(NSString *)fileName;
+ (void)desEncrypt:(NSString *)key imageData:(UIImage *)image ;
+ (NSString *) randomStringWithLength: (int) len;
+ (void)EncryptVideo:(NSString *) key videoUrl:(NSURL *)videoUrl fileName:(NSString *)filename;
+ (void)DecryptVideo:(NSString *) key videoUrl:(NSString *)videoUrl fileName:(NSString *)filename;
@end

NS_ASSUME_NONNULL_END
