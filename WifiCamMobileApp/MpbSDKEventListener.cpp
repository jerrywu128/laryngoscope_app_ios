//
//  MpbSDKEventListener.cpp
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-6-13.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#include "MpbSDKEventListener.h"

void MpbSDKEventListener::eventNotify(ICatchEvent* icatchEvt) {}

MpbSDKEventListener::MpbSDKEventListener(VideoPlaybackViewController *controller) {
  this->controller = controller;
}

void MpbSDKEventListener::updateVideoPbProgress(ICatchEvent* icatchEvt) {
  if (icatchEvt) {
//    AppLog(@"updateVideoPbProgress: %f", icatchEvt->getDoubleValue1());
    [controller updateVideoPbProgress:icatchEvt->getDoubleValue1() ];
  }
}

void MpbSDKEventListener::updateVideoPbProgressState(ICatchEvent* icatchEvt) {
  if (icatchEvt) {
    if (icatchEvt->getIntValue1() == 1) {
      AppLog(@"I received an event: Pause");
      //sdk.videoPbNeedPause = YES;
      [controller updateVideoPbProgressState:YES];
    } else if (icatchEvt->getIntValue1() == 2) {
      AppLog(@"I received an event: Resume");
      //sdk.videoPbNeedPause = NO;
      [controller updateVideoPbProgressState:NO];
    }
  }
}

void MpbSDKEventListener::stopVideoPb(ICatchEvent* icatchEvt) {
  AppLog(@"I received an event: *Playback done");
  //[[SDK instance] setVideoPbDone:YES];
  [controller stopVideoPb];
}

void MpbSDKEventListener::showServerStreamError(ICatchEvent *icatchEvt) {
  AppLog(@"I received an event: *Server Stream Error: %f,%f,%f", icatchEvt->getDoubleValue1(), icatchEvt->getDoubleValue2(), icatchEvt->getDoubleValue3());
  [controller showServerStreamError];
}