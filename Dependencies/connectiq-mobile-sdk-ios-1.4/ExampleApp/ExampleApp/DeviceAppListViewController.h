//
//  DeviceAppListViewController.h
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <ConnectIQ/ConnectIQ.h>

@interface DeviceAppListViewController : UIViewController

- (instancetype)initWithDevice:(IQDevice *)device;

@end
