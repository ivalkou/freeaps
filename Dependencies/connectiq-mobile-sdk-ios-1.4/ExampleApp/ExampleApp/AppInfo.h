//
//  AppInfo.h
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ConnectIQ/ConnectIQ.h>

@interface AppInfo : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) IQApp *app;
@property (nonatomic, strong) IQAppStatus *status;

- (instancetype)initWithName:(NSString *)name IQApp:(IQApp *)app;
- (instancetype)initWithName:(NSString *)name IQApp:(IQApp *)app status:(IQAppStatus *)status;

- (void)updateStatusWithCompletion:(void(^)(AppInfo *appInfo))completion;

@end
