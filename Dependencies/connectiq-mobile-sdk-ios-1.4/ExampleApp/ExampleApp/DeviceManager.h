//
//  DeviceManager.h
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ConnectIQ/ConnectIQ.h>

@protocol DeviceManagerDelegate <NSObject>
@optional
- (void)devicesChanged;
@end

@interface DeviceManager : NSObject

@property (nonatomic, weak) id<DeviceManagerDelegate> delegate;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (DeviceManager *)sharedManager;

- (BOOL)handleOpenURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication;

- (NSArray *)allDevices;

- (void)saveDevicesToFileSystem;
- (void)restoreDevicesFromFileSystem;

@end
