//
//  WifiCamSDKEventListener.h
//  WifiCamMobileApp
//
//  Created by Guo on 6/26/15.
//  Copyright (c) 2015 iCatchTech. All rights reserved.
//

#ifndef __WifiCamMobileApp__WifiCamSDKEventListener__
#define __WifiCamMobileApp__WifiCamSDKEventListener__

class WifiCamSDKEventListener: public ICatchWificamListener {
private:
    id object;
    SEL callback;
    void eventNotify(ICatchEvent *icatchEvt);
public:
    WifiCamSDKEventListener(id object, SEL callback);
};
#endif /* defined(__WifiCamMobileApp__WifiCamSDKEventListener__) */
