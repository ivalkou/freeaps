//
//  AppDelegate.m
//  ExampleApp
//
//  Copyright (c) 2014 Garmin. All rights reserved.
//

#import "AppDelegate.h"
#import <ConnectIQ/ConnectIQ.h>
#import "Constants.h"
#import "DeviceManager.h"
#import "DeviceListViewController.h"

@interface AppDelegate () <IQUIOverrideDelegate>

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // To bypass the default alert dialog shown by the SDK when Garmin Connect
    // Mobile is not installed, pass an instance of IQUIOverrideDelegate to this
    // method(such as self in this example). You can then bypass the alert dialog
    // or provide your own.
    [[ConnectIQ sharedInstance] initializeWithUrlScheme:ReturnURLScheme uiOverrideDelegate:nil];
    [[DeviceManager sharedManager] restoreDevicesFromFileSystem];

    // Override point for customization after application launch.
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    DeviceListViewController *viewController = [[DeviceListViewController alloc] initWithNibName:nil bundle:nil];
    UINavigationController *controller = [[UINavigationController alloc] initWithRootViewController:viewController];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    NSLog(@"Received URL from '%@': %@", sourceApplication, url);

    return [[DeviceManager sharedManager] handleOpenURL:url sourceApplication:sourceApplication];
}

- (void)needsToInstallConnectMobile {
    // If you set self as the UI override delegate in the SDK's initialize method,
    // this method will be called if the SDK needs to install GCM. In this example,
    // we'll just bypass the alert view completely and always let the SDK launch
    // the App Store to GCM's page so the user can install it.
    [[ConnectIQ sharedInstance] showAppStoreForConnectMobile];
}

@end
