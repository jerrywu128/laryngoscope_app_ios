//
//  PreviewSDKEventListener.h
//  WifiCamMobileApp
//
//  Created by Sunmedia Apple on 14-6-13.
//  Copyright (c) 2014年 iCatchTech. All rights reserved.
//

#ifndef WifiCamMobileApp_PreviewSDKEventListener_h
#define WifiCamMobileApp_PreviewSDKEventListener_h

#import "ViewController.h"
#import "HomeVC.h"

class PreviewSDKEventListener: public ICatchWificamListener
{
private:
    ViewController *controller;
    HomeVC *homeVC;
protected:
    void eventNotify(ICatchEvent *icatchEvt);
    PreviewSDKEventListener(ViewController *controller);
    PreviewSDKEventListener(HomeVC *homeVC);
    
    void showReconnectAlert(ICatchEvent *iCatchEvt);
    void updateMovieRecState(ICatchEvent *icatchEvt, MovieRecState state);
    void updateBatteryLevel(ICatchEvent *icatchEvt);
    void stopStillCapture(ICatchEvent *icatchEvt);
    void stopTimelapse(ICatchEvent *icatchEvt);
    void timelapseStartedNotice(ICatchEvent *icatchEvt);
    void timelapseCompletedNotice(ICatchEvent *icatchEvt);
    void sdCardFull(ICatchEvent *icatchEvt);
    void postMovieRecordTime(ICatchEvent *icatchEvt);
    void postMovieRecordFileAddedEvent(ICatchEvent *icatchEvt);
    void postFileDownloadEvent(ICatchEvent *icatchEvt);
    void sdFull(ICatchEvent *icatchEvt);
};

// ICATCH_EVENT_CONNECTION_DISCONNECTED
class ConnectionListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *iCatchEvt) {
        AppLog(@"Disconnected event");
        showReconnectAlert(iCatchEvt);
    }
public:
    ConnectionListener(HomeVC *homeVC) : PreviewSDKEventListener(homeVC) {}
};

// VideoRecOffListener
class VideoRecOffListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *icatchEvt) {
        AppLog(@"video rec off");
        updateMovieRecState(icatchEvt, MovieRecStoped);
    }
public:
    VideoRecOffListener(ViewController *controller): PreviewSDKEventListener(controller) {}
};

// VideoRecOnListener
class VideoRecOnListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *icatchEvt) {
        AppLog(@"video rec on");
        updateMovieRecState(icatchEvt, MovieRecStarted);
    }
public:
    VideoRecOnListener(ViewController *controller): PreviewSDKEventListener(controller) {}
};

class VideoRecPostTimeListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent* icatchEvt) {
        AppLog(@"video rec post time");
        postMovieRecordTime(icatchEvt);
    }
public:
    VideoRecPostTimeListener(ViewController *controller): PreviewSDKEventListener(controller) {}
};

class VideoRecFileAddedListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent* icatchEvt) {
        AppLog(@"video rec file Added.");
        postMovieRecordFileAddedEvent(icatchEvt);
    }
public:
    VideoRecFileAddedListener(ViewController *controller): PreviewSDKEventListener(controller) {}
};

// BatteryLevelListener
class BatteryLevelListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent* icatchEvt) {
        AppLog(@"battery level changed");
        updateBatteryLevel(icatchEvt);
    }
public:
    BatteryLevelListener(ViewController *controller): PreviewSDKEventListener(controller) {}
};

// StillCaptureDoneListener
class StillCaptureDoneListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *icatchEvt) {
        AppLog(@"capture done event received !");
        stopStillCapture(icatchEvt);
    }
public:
    StillCaptureDoneListener (ViewController *controller): PreviewSDKEventListener(controller) {}
};

class SDCardFullListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *icatchEvt) {
        AppLog(@"sd full event received !");
        sdFull(icatchEvt);
        /*
        NSDate *begin = [NSDate date];
        [NSThread sleepForTimeInterval:0.030];
        NSDate *end = [NSDate date];
        NSTimeInterval elapse = [end timeIntervalSinceDate:begin];
        AppLog(@"elapse: %f", elapse);
         */
    }
public:
    SDCardFullListener (ViewController *controller): PreviewSDKEventListener(controller) {}
};

class TimelapseStopListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *icatchEvt) {
        AppLog(@"timelapse stop event received !");
        stopTimelapse(icatchEvt);
    }
public:
    TimelapseStopListener (ViewController *controller): PreviewSDKEventListener(controller) {}
};

class TimelapseCaptureStartedListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *icatchEvt) {
        AppLog(@"timelapse start event received !");
        timelapseStartedNotice(icatchEvt);
    }
public:
    TimelapseCaptureStartedListener (ViewController *controller): PreviewSDKEventListener(controller) {}
};

class TimelapseCaptureCompleteListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *icatchEvt) {
        AppLog(@"timelapse complete event received !");
        timelapseCompletedNotice(icatchEvt);
    }
public:
    TimelapseCaptureCompleteListener (ViewController *controller): PreviewSDKEventListener(controller) {}
};

class FileDownloadListener : public PreviewSDKEventListener
{
private:
    void eventNotify(ICatchEvent *icatchEvt) {
        AppLog(@"file download event received !");
        postFileDownloadEvent(icatchEvt);
    }
public:
    FileDownloadListener (ViewController *controller): PreviewSDKEventListener(controller) {}
};

#endif
