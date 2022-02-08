//
//  WifiCamPlaybackControl.m
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-7-2.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#import "WifiCamPlaybackControl.h"

@implementation WifiCamPlaybackControl

- (double)play:(ICatchFile *)f
{
  return [[SDK instance] play:f];
}

- (BOOL)pause
{
  return [[SDK instance] pause];
}

- (BOOL)resume
{
  return [[SDK instance] resume];
}

- (BOOL)stop
{
  return [[SDK instance] stop];
}

- (BOOL)seek:(double)point
{
  return [[SDK instance] seek:point];
}

- (BOOL)videoPlaybackStreamEnabled {
  return [[SDK instance] videoPlaybackStreamEnabled];
}

- (BOOL)audioPlaybackStreamEnabled {
  return [[SDK instance] audioPlaybackStreamEnabled];
}

@end
