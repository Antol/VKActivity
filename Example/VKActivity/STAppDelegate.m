//
//  STAppDelegate.m
//  VKActivity
//
//  Created by Antol Peshkov on 23.09.14.
//  Copyright (c) 2014 brainSTrainer. All rights reserved.
//

#import "STAppDelegate.h"
#import "VKSdk.h"

@implementation STAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [VKSdk initializeWithDelegate:nil andAppId:VK_CLIENT_ID];
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    BOOL openUrl = [VKSdk processOpenURL:url fromApplication:sourceApplication];
    return openUrl;
}

@end
