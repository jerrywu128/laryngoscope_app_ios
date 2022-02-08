//
//  SettingViewSDKEventListener.h
//  WifiCamMobileApp
//
//  Created by Guo on 4/9/15.
//  Copyright (c) 2015 iCatchTech. All rights reserved.
//

#ifndef __WifiCamMobileApp__SettingViewSDKEventListener__
#define __WifiCamMobileApp__SettingViewSDKEventListener__

#import "SettingViewController.h"


class SettingViewSDKEventListener : public ICatchWificamListener {
private:
  SettingViewController *controller;
protected:
  void eventNotify(ICatchEvent *icatchEvt);
  SettingViewSDKEventListener(SettingViewController *controller);
  void udpateFWCompleted(ICatchEvent *icatchEvt);
  void udpateFWPowerOff(ICatchEvent *icatchEvt);
};

class UpdateFWCompleteListener : public SettingViewSDKEventListener {
private:
  void eventNotify(ICatchEvent *iCatchEvt) {
    AppLog(@"Update FW Completed Event Received.");
    udpateFWCompleted(iCatchEvt);
  }
public:
  UpdateFWCompleteListener(SettingViewController *controller) : SettingViewSDKEventListener(controller) {}
};

class UpdateFWCompletePowerOffListener : public SettingViewSDKEventListener {
private:
  void eventNotify(ICatchEvent *iCatchEvt) {
    AppLog(@"Update FW Power Off Event Received.");
    udpateFWPowerOff(iCatchEvt);
  }
public:
  UpdateFWCompletePowerOffListener(SettingViewController *controller) : SettingViewSDKEventListener(controller) {}
};

#endif /* defined(__WifiCamMobileApp__SettingViewSDKEventListener__) */
