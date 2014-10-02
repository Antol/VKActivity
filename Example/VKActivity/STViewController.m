//
//  STViewController.m
//  VKActivity
//
//  Created by Antol Peshkov on 23.09.14.
//  Copyright (c) 2014 brainSTrainer. All rights reserved.
//

#import "STViewController.h"
#import "VKActivity.h"

@implementation STViewController {
    UIPopoverController *_popover;
}

- (IBAction)share:(UIButton *)sender
{
    UIImage *image = [UIImage imageNamed:@"example.jpg"];
    NSString *string = @"Чебуреки?";
    NSURL *url = [NSURL URLWithString:@"http://gotovim-doma.ru/view.php?r=512-recept-CHebureki-domashnie"];
    
    VKActivity *vkActivity = [VKActivity new];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[image, string, url]
                                                                                         applicationActivities:@[vkActivity]];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        _popover = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
        [_popover presentPopoverFromRect:sender.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
    else {
        [self presentViewController:activityViewController animated:YES completion:nil];
    }
}

@end
