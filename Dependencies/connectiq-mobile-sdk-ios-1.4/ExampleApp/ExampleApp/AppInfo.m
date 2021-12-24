//
//  AppInfo.m
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import "AppInfo.h"

// --------------------------------------------------------------------------------
#pragma mark - LITERAL CONSTANTS
// --------------------------------------------------------------------------------

// --------------------------------------------------------------------------------
#pragma mark - PRIVATE DECLARATIONS
// --------------------------------------------------------------------------------

@interface AppInfo ()

@end

// --------------------------------------------------------------------------------
#pragma mark - CLASS DEFINITION
// --------------------------------------------------------------------------------

@implementation AppInfo

// --------------------------------------------------------------------------------
#pragma mark - STATIC METHODS
// --------------------------------------------------------------------------------

// --------------------------------------------------------------------------------
#pragma mark - INITIALIZERS AND DEALLOCATOR
// --------------------------------------------------------------------------------

- (instancetype)initWithName:(NSString *)name IQApp:(IQApp *)app {
    if ((self = [super init])) {
        _name = name;
        _app = app;
        _status = nil;
    }
    return self;
}

- (instancetype)initWithName:(NSString *)name IQApp:(IQApp *)app status:(IQAppStatus *)status {
    if ((self = [super init])) {
        _name = name;
        _app = app;
        _status = status;
    }
    return self;
}

// --------------------------------------------------------------------------------
#pragma mark - METHODS
// --------------------------------------------------------------------------------

- (void)updateStatusWithCompletion:(void(^)(AppInfo *appInfo))completion {
    [[ConnectIQ sharedInstance] getAppStatus:self.app completion:^(IQAppStatus *appStatus) {
        self.status = appStatus;
        completion(self);
    }];
}

@end
