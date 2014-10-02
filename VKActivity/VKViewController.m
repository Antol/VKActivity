//
//  VKViewController.m
//  Pods
//
//  Created by Antol Peshkov on 02.10.14.
//
//

#import "VKViewController.h"
#import "VKActivity.h"
#import "VKSdk.h"
#import "REComposeViewController.h"

@interface VKViewController () <VKSdkDelegate, REComposeViewControllerDelegate>
@property (nonatomic, assign) BOOL isShareInProgress;
@end

@implementation VKViewController

//- (void)viewDidLoad
//{
//    [super viewDidLoad];
//    self.view.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.3f];
//}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (!self.isShareInProgress) {
        [self share];
    }
}

- (void)share
{
    NSAssert(self.vkActivity, @"");
    
    self.isShareInProgress = YES;
    
    [VKSdk instance].delegate = self;
    
    if ([VKSdk wakeUpSession]) {
        [self startComposeViewController];
    }
    else {
        [VKSdk authorize:@[VK_PER_WALL, VK_PER_PHOTOS] revokeAccess:NO forceOAuth:NO inApp:NO];
    }
}

- (void)shareDidFinish:(BOOL)completed
{
    [self.vkActivity activityDidFinish:completed];
    [VKSdk instance].delegate = nil;
}

#pragma mark - VKSdkDelegate

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError
{
    VKCaptchaViewController *vc = [VKCaptchaViewController captchaControllerWithError:captchaError];
    [vc presentIn:self];
}

- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken
{
    [VKSdk authorize:@[VK_PER_WALL, VK_PER_PHOTOS] revokeAccess:NO forceOAuth:NO inApp:NO];
}

- (void)vkSdkReceivedNewToken:(VKAccessToken *)newToken
{
    [self startComposeViewController];
}

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller
{
    [self presentViewController:controller animated:YES completion:nil];
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
    
    [self shareDidFinish:NO];
}

#pragma mark - REComposeViewController

- (void)startComposeViewController
{
    REComposeViewController *composeViewController = [[REComposeViewController alloc] init];
    composeViewController.delegate = self;
    composeViewController.title = @"VK";
    composeViewController.text = self.vkActivity.string;
    
    if (self.vkActivity.image) {
        composeViewController.hasAttachment = YES;
        composeViewController.attachmentImage = self.vkActivity.image;
    }
    
    [composeViewController presentFromViewController:self];
}

- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result
{
    [composeViewController dismissViewControllerAnimated:YES completion:nil];
    
    if (result == REComposeResultCancelled) {
        [self shareDidFinish:NO];
    }
    
    if (result == REComposeResultPosted) {
        self.vkActivity.string = composeViewController.text;
        [self postToWall];
    }
}

#pragma mark - Private

- (void)postToWall
{
    if (self.vkActivity.image) {
        [self uploadPhoto];
    }
    else {
        [self uploadText];
    }
}

- (void)uploadPhoto
{
    NSString *userId = [VKSdk getAccessToken].userId;
    VKRequest *request = [VKApi uploadWallPhotoRequest:self.vkActivity.image
                                            parameters:[VKImageParameters jpegImageWithQuality:1.f]
                                                userId:[userId integerValue]
                                               groupId:0];
    
    [request executeWithResultBlock: ^(VKResponse *response) {
        VKPhoto *photoInfo = [(VKPhotoArray*)response.parsedModel objectAtIndex:0];
        NSString *photoAttachment = [NSString stringWithFormat:@"photo%@_%@", photoInfo.owner_id, photoInfo.id];
        [self postToWall:@{ VK_API_ATTACHMENTS : [@[photoAttachment, [self.vkActivity.URL absoluteString]] componentsJoinedByString:@","],
                            VK_API_FRIENDS_ONLY : @(0),
                            VK_API_OWNER_ID : userId,
                            VK_API_MESSAGE : self.vkActivity.string}];
    } errorBlock: ^(NSError *error) {
        NSLog(@"Error: %@", error);
        [self shareDidFinish:NO];
    }];
}

- (void)uploadText
{
    [self postToWall:@{ VK_API_ATTACHMENTS : [self.vkActivity.URL absoluteString],
                        VK_API_FRIENDS_ONLY : @(0),
                        VK_API_OWNER_ID : [VKSdk getAccessToken].userId,
                        VK_API_MESSAGE : self.vkActivity.string}];
}

- (void)postToWall:(NSDictionary *)params
{
    VKRequest *post = [[VKApi wall] post:params];
    
    [post executeWithResultBlock: ^(VKResponse *response) {
        [self shareDidFinish:YES];
    } errorBlock: ^(NSError *error) {
        NSLog(@"Error: %@", error);
        [self shareDidFinish:NO];
    }];
}

@end


