//
//  MpbSDKEventListener.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-6-13.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#ifndef WifiCamMobileApp_MpbSDKEventListener_h
#define WifiCamMobileApp_MpbSDKEventListener_h

#import "VideoPlaybackViewController.h"

class MpbSDKEventListener : public ICatchWificamListener
{
private:
  VideoPlaybackViewController *controller;
protected:
  void eventNotify(ICatchEvent* icatchEvt);
  MpbSDKEventListener(VideoPlaybackViewController *controller);
  void updateVideoPbProgress(ICatchEvent* icatchEvt);
  void updateVideoPbProgressState(ICatchEvent* icatchEvt);
  void stopVideoPb(ICatchEvent* icatchEvt);
  void showServerStreamError(ICatchEvent *icatchEvt);
};


class VideoPbProgressListener : public MpbSDKEventListener
{
private:
  void eventNotify(ICatchEvent* icatchEvt) {
    updateVideoPbProgress(icatchEvt);
  }
public:
  VideoPbProgressListener(VideoPlaybackViewController *controller):MpbSDKEventListener(controller){}
};

class VideoPbProgressStateListener : public MpbSDKEventListener
{
private:
  void eventNotify(ICatchEvent* icatchEvt) {
    updateVideoPbProgressState(icatchEvt);
  }
public:
  VideoPbProgressStateListener(VideoPlaybackViewController *controller):MpbSDKEventListener(controller){}
};

class VideoPbDoneListener : public MpbSDKEventListener
{
private:
  void eventNotify(ICatchEvent* icatchEvt) {
    stopVideoPb(icatchEvt);
  }
public:
  VideoPbDoneListener(VideoPlaybackViewController *controller):MpbSDKEventListener(controller){}
};

class VideoPbServerStreamErrorListener : public MpbSDKEventListener {
private:
  void eventNotify(ICatchEvent* icatchEvt) {
    showServerStreamError(icatchEvt);
  }
public:
  VideoPbServerStreamErrorListener(VideoPlaybackViewController *controller):MpbSDKEventListener(controller){}
};

#endif
