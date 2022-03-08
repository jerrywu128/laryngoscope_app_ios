//
//  SaveMediaInAlbum.h
//  laryngoscope_app_ios
//
//  Created by 吳旻洋 on 2022/2/24.
//  Copyright © 2022 HonestMedical. All rights reserved.
//

#import <Photos/Photos.h>
#import "FileDes.h"
NS_ASSUME_NONNULL_BEGIN



@interface SaveMediaInAlbum : PHAsset
- (void)savePhoto:(UIImage *)image;
- (void)saveVideo:(NSURL *)videoUrl;
@end

NS_ASSUME_NONNULL_END
