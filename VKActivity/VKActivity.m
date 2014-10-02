//
//  VKontakteActivity.m
//  VKActivity
//
//  Created by Denivip Group on 28.01.14.
//  Copyright (c) 2014 Denivip Group. All rights reserved.
//

#import "VKActivity.h"
#import "VKSdk.h"
#import "MBProgressHUD.h"
#import "REComposeViewController.h"

@interface VKActivity () <VKSdkDelegate, REComposeViewControllerDelegate>
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSString *string;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) UIViewController *parent;
@property (nonatomic, strong) MBProgressHUD *HUD;
@end

@implementation VKActivity

#pragma mark - NSObject

- (id)init
{
    NSAssert(NO, @"You cannot init this class directly. Instead, use initWithParent");
    return nil;
}

- (id)initWithParent:(UIViewController *)parent
{
    self = [super init];
    
    if (self) {
        self.parent = parent;
    }
    
    return self;
}

#pragma mark - UIActivity

- (NSString *)activityType
{
    return @"VKActivityTypeVKontakte";
}

- (NSString *)activityTitle
{
    return @"VK";
}

- (UIImage *)activityImage
{
    return [VKActivity imageVK];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
+ (UIActivityCategory)activityCategory
{
    return UIActivityCategoryShare;
}
#endif

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for (UIActivityItemProvider *item in activityItems) {
        if ([item isKindOfClass:[UIImage class]]) {
            return YES;
        }
        else if ([item isKindOfClass:[NSString class]]){
            return YES;
        }
        else if ([item isKindOfClass:[NSURL class]]){
            return YES;
        }
    }
    return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSString class]]) {
            self.string = self.string ? [NSString stringWithFormat:@"%@ %@", self.string, item] : item;
        }
        else if([item isKindOfClass:[UIImage class]]) {
            self.image = item;
        }
        else if([item isKindOfClass:[NSURL class]]) {
            self.URL = item;
        }
    }
}

- (void)performActivity
{
    [VKSdk instance].delegate = self;
    
    [self.parent dismissViewControllerAnimated:YES completion:^(void)
     {
         if ([VKSdk wakeUpSession]) {
             [self startComposeViewController];
         }
         else {
             [VKSdk authorize:@[VK_PER_WALL, VK_PER_PHOTOS] revokeAccess:NO forceOAuth:NO inApp:YES display:VK_DISPLAY_IOS];
         }
     }];
}

- (void)activityDidFinish:(BOOL)completed
{
    [super activityDidFinish:completed];
    
    [VKSdk instance].delegate = nil;
}

#pragma mark - Upload

- (void)postToWall
{
    if (self.image) {
        [self uploadPhoto];
    }
    else {
        [self uploadText];
    }
}

- (void)uploadPhoto
{
    NSString *userId = [VKSdk getAccessToken].userId;
    VKRequest *request = [VKApi uploadWallPhotoRequest:self.image
                                            parameters:[VKImageParameters jpegImageWithQuality:1.f]
                                                userId:[userId integerValue]
                                               groupId:0];
    
	[request executeWithResultBlock: ^(VKResponse *response) {
	    VKPhoto *photoInfo = [(VKPhotoArray*)response.parsedModel objectAtIndex:0];
	    NSString *photoAttachment = [NSString stringWithFormat:@"photo%@_%@", photoInfo.owner_id, photoInfo.id];
        [self postToWall:@{ VK_API_ATTACHMENTS : [@[photoAttachment, [self.URL absoluteString]] componentsJoinedByString:@","],
                            VK_API_FRIENDS_ONLY : @(0),
                            VK_API_OWNER_ID : userId,
                            VK_API_MESSAGE : self.string}];
    } errorBlock: ^(NSError *error) {
	    NSLog(@"Error: %@", error);
        [self activityDidFinish:NO];
	}];
}

- (void)uploadText
{
    [self postToWall:@{ VK_API_ATTACHMENTS : [self.URL absoluteString],
                        VK_API_FRIENDS_ONLY : @(0),
                        VK_API_OWNER_ID : [VKSdk getAccessToken].userId,
                        VK_API_MESSAGE : self.string}];
}

- (void)postToWall:(NSDictionary *)params
{
    VKRequest *post = [[VKApi wall] post:params];
    
    [post executeWithResultBlock: ^(VKResponse *response) {
        [self activityDidFinish:YES];
    } errorBlock: ^(NSError *error) {
        NSLog(@"Error: %@", error);
        [self activityDidFinish:NO];
    }];
}

#pragma mark - vkSdk

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError
{
	VKCaptchaViewController *vc = [VKCaptchaViewController captchaControllerWithError:captchaError];
	[vc presentIn:self.parent];
}

- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken
{
    [VKSdk authorize:@[VK_PER_WALL, VK_PER_PHOTOS] revokeAccess:NO forceOAuth:NO inApp:YES display:VK_DISPLAY_IOS];
}

-(void)vkSdkReceivedNewToken:(VKAccessToken *)newToken
{
    [self startComposeViewController];
}

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller
{
	[self.parent presentViewController:controller animated:YES completion:nil];
}

- (void)vkSdkDidAcceptUserToken:(VKAccessToken *)token
{
    [self startComposeViewController];
}

- (void)vkSdkUserDeniedAccess:(VKError *)authorizationError
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Access denied"
                                                       delegate:nil
                                              cancelButtonTitle:@"Close"
                                              otherButtonTitles:nil];
    [alertView show];
    
    [self activityDidFinish:NO];
}

- (void)startComposeViewController
{
    REComposeViewController *composeViewController = [[REComposeViewController alloc] init];
    composeViewController.title = @"VK";
    composeViewController.hasAttachment = YES;
    composeViewController.attachmentImage = self.image;
    composeViewController.text = self.string;
    [composeViewController setDelegate:self];
    [composeViewController presentFromRootViewController];
}

- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result
{
    [composeViewController dismissViewControllerAnimated:YES completion:nil];
    
    if (result == REComposeResultCancelled) {
        [self activityDidFinish:NO];
    }
    
    if (result == REComposeResultPosted) {
        self.string = composeViewController.text;
        [self postToWall];
    }
}

#pragma mark - Private

+ (UIImage*)imageVK;
{
    static UIImage* image = nil;
    if (image) {
        return image;
    }
    
    CGRect frame = CGRectMake(0.f, 0.f, 200.f, 200.f);
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.f) {
        UIGraphicsBeginImageContextWithOptions(frame.size, NO, 0);
        [self drawVKColoredWithFrame:frame];
    }
    else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            frame = CGRectMake(0.f, 0.f, 50.f, 50.f);
        }
        else {
            frame = CGRectMake(0.f, 0.f, 40.f, 40.f);
        }
        
        UIGraphicsBeginImageContextWithOptions(frame.size, NO, 0);
        [self drawVKBlackWithFrame:frame];
    }
    
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (void)drawVKColoredWithFrame:(CGRect)frame;
{
    //// Color Declarations
    UIColor* color0 = [UIColor colorWithRed: 0.236 green: 0.378 blue: 0.572 alpha: 1];
    UIColor* color1 = [UIColor colorWithRed: 1 green: 1 blue: 1 alpha: 1];
    
    
    //// Subframes
    CGRect g5608 = CGRectMake(CGRectGetMinX(frame), CGRectGetMinY(frame), CGRectGetWidth(frame), CGRectGetHeight(frame));
    
    
    //// g5608
    {
        //// rect2987 Drawing
        UIBezierPath* rect2987Path = [UIBezierPath bezierPathWithRect: CGRectMake(CGRectGetMinX(g5608) + floor(CGRectGetWidth(g5608) * 0.00000 + 0.5), CGRectGetMinY(g5608) + floor(CGRectGetHeight(g5608) * 0.00000 + 0.5), floor(CGRectGetWidth(g5608) * 1.00000 + 0.5) - floor(CGRectGetWidth(g5608) * 0.00000 + 0.5), floor(CGRectGetHeight(g5608) * 1.00000 + 0.5) - floor(CGRectGetHeight(g5608) * 0.00000 + 0.5))];
        [color0 setFill];
        [rect2987Path fill];
        
        
        //// path9 Drawing
        UIBezierPath* path9Path = UIBezierPath.bezierPath;
        [path9Path moveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.49162 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72099 * CGRectGetHeight(g5608))];
        [path9Path addLineToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.53831 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72099 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.55962 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.71167 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.53831 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72099 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.55241 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.71943 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.56605 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.69116 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.56626 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.70454 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.56605 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.69116 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.59421 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.61928 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.56605 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.69116 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.56512 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.62850 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.69871 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.70661 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.62288 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.61019 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.65969 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.67983 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.75064 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72244 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.72821 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72687 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.75064 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72244 * CGRectGetHeight(g5608))];
        [path9Path addLineToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.85497 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72099 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.88366 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.67470 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.85497 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72099 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.90954 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.71762 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.80609 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.58496 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.88155 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.67120 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.86858 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.64296 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.82824 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.42902 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.74066 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.52423 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.74943 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.53406 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.88941 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.30929 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.87622 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.36506 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.89542 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.32602 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.84840 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29756 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.88370 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29335 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.84840 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29756 * CGRectGetHeight(g5608))];
        [path9Path addLineToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.73093 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29829 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.71576 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.30096 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.73093 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29829 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.72222 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29710 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.70540 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31357 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.70945 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.30475 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.70540 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31357 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.66200 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.40516 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.70540 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31357 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.68679 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.36307 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.58023 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.49315 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.60970 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.49398 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.58878 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.49868 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.56532 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.41397 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.56034 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.48030 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.56532 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.44152 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.53989 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.28271 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.56532 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.32789 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.57837 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29199 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.48505 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.27725 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.52712 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.27962 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.51771 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.27758 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.38758 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.28722 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.44314 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.27682 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.40766 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.27738 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.37019 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.30919 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.37422 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29378 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.36390 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.30835 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.40486 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.32662 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.37796 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31023 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.39554 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31393 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.41647 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.37977 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.41689 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.34300 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.41647 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.37977 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.40032 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.49368 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.41647 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.37977 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.42339 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.48110 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.31612 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.40411 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.38448 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.50232 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.36276 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.48469 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.27419 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31720 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.29223 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.36284 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.27419 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31720 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.26451 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.30411 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.27419 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31720 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.27072 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.30868 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.24646 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29683 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.25698 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29858 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.24646 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29683 * CGRectGetHeight(g5608))];
        [path9Path addLineToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.13483 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29755 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.11193 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.30532 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.13483 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29755 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.11807 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.29803 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.11149 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.32520 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.10645 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.31180 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.11149 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.32520 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.29783 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.63270 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.11149 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.32520 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.19888 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.52967 * CGRectGetHeight(g5608))];
        [path9Path addCurveToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.49162 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72099 * CGRectGetHeight(g5608)) controlPoint1: CGPointMake(CGRectGetMinX(g5608) + 0.38859 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72719 * CGRectGetHeight(g5608)) controlPoint2: CGPointMake(CGRectGetMinX(g5608) + 0.49162 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72099 * CGRectGetHeight(g5608))];
        [path9Path addLineToPoint: CGPointMake(CGRectGetMinX(g5608) + 0.49162 * CGRectGetWidth(g5608), CGRectGetMinY(g5608) + 0.72099 * CGRectGetHeight(g5608))];
        [path9Path closePath];
        path9Path.miterLimit = 4;
        
        path9Path.usesEvenOddFillRule = YES;
        
        [color1 setFill];
        [path9Path fill];
    }
}

+ (void)drawVKBlackWithFrame: (CGRect)frame;
{
    //// Subframes
    CGRect frame2 = CGRectMake(CGRectGetMinX(frame), CGRectGetMinY(frame) + floor(CGRectGetHeight(frame) * 0.20833 + 0.5), CGRectGetWidth(frame), floor(CGRectGetHeight(frame) * 0.77083 + 0.5) - floor(CGRectGetHeight(frame) * 0.20833 + 0.5));
    CGRect group = CGRectMake(CGRectGetMinX(frame2), CGRectGetMinY(frame2), CGRectGetWidth(frame2), CGRectGetHeight(frame2));
    
    
    //// Group
    {
        //// Bezier 2 Drawing
        UIBezierPath* bezier2Path = UIBezierPath.bezierPath;
        [bezier2Path moveToPoint: CGPointMake(CGRectGetMinX(group) + 0.95859 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.81001 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.86062 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.63588 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.92881 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.74691 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.89378 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.69305 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.85287 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.49492 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.83072 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.58431 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.82882 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.55441 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.93380 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.30290 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.87911 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.42998 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.90733 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.36754 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.99679 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.10991 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.95851 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.24249 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.98379 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.18224 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.97103 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03551 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 1.00503 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.06389 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.99774 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.04356 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.95699 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03402 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.96643 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03410 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.96168 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03402 * CGRectGetHeight(group))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group) + 0.79855 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03369 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.76134 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.07878 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.77903 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03318 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.76825 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.04822 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.73131 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.20123 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.75202 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.12009 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.74242 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.16136 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.63857 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.45296 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.70614 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.29162 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.67801 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.37898 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.60573 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.48140 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.62988 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.46928 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.62026 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.48990 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.58250 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.39887 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.58755 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.46968 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.58220 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.41676 * CGRectGetHeight(group))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group) + 0.58234 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.07572 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.54708 * CGRectGetWidth(group), CGRectGetMinY(group) + -0.00000 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.57882 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.02956 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.57302 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.00897 * CGRectGetHeight(group))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group) + 0.38250 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.00005 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.33778 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03933 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.36053 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.00005 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.34951 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.01505 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.34288 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.06711 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.33101 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.05336 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.32897 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.06246 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.38967 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.15591 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.37019 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.07627 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.38558 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.10751 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.39199 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.38852 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.39622 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.23324 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.39576 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.31088 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.38358 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.45498 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.39088 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.41119 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.38867 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.43381 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.34589 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.47455 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.37562 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.48825 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.36277 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.49503 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.30936 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.40361 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.33061 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.45602 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.31987 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.42987 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.21271 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.08709 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.26989 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.30506 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.23839 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.19878 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.17315 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03474 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.20529 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.05483 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.19250 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03527 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.03053 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03481 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.12561 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03340 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.07807 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03318 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.00505 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.10612 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.00193 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.03576 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + -0.00660 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.06030 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.18968 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.68770 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.05682 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.30962 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.11445 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.50748 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.32993 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.91972 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.22830 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.78020 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.27265 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.86185 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.53836 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.99895 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.39486 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.98531 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.46475 * CGRectGetWidth(group), CGRectGetMinY(group) + 1.00505 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.58478 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.91955 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.57283 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.99609 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.58318 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.98026 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.60011 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.79942 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.58585 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.87804 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.58852 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.83673 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.64859 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.77862 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.61149 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.76280 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.62873 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.75582 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.67481 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.81986 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.65853 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.79003 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.66689 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.80453 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.73305 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.93222 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.69421 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.85735 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.71292 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.89600 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.82584 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.99899 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.75831 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.97765 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.78823 * CGRectGetWidth(group), CGRectGetMinY(group) + 1.00448 * CGRectGetHeight(group))];
        [bezier2Path addLineToPoint: CGPointMake(CGRectGetMinX(group) + 0.97149 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.99902 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.99365 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.89921 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.99495 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.99631 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 1.00712 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.94550 * CGRectGetHeight(group))];
        [bezier2Path addCurveToPoint: CGPointMake(CGRectGetMinX(group) + 0.95859 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.81001 * CGRectGetHeight(group)) controlPoint1: CGPointMake(CGRectGetMinX(group) + 0.98418 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.86681 * CGRectGetHeight(group)) controlPoint2: CGPointMake(CGRectGetMinX(group) + 0.97177 * CGRectGetWidth(group), CGRectGetMinY(group) + 0.83793 * CGRectGetHeight(group))];
        [bezier2Path closePath];
        bezier2Path.miterLimit = 4;
        
        bezier2Path.usesEvenOddFillRule = YES;
        
        [UIColor.blackColor setFill];
        [bezier2Path fill];
    }
}


@end


