//
//  STViewController.m
//  VKActivity
//
//  Created by Antol Peshkov on 23.09.14.
//  Copyright (c) 2014 brainSTrainer. All rights reserved.
//

#import "STViewController.h"
#import "VKActivity.h"

@implementation STViewController

- (IBAction)share:(id)sender
{
    UIImage *image = [UIImage imageNamed:@"example.jpg"];
    NSString *string = @"Чебуреки?";
    NSURL *url = [NSURL URLWithString:@"http://gotovim-doma.ru/view.php?r=512-recept-CHebureki-domashnie"];
    
    VKActivity *vkActivity = [[VKActivity alloc] initWithParent:self];
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[image, string, url]
                                                                                         applicationActivities:@[vkActivity]];
    
    [self presentViewController:activityViewController animated:YES completion:nil];
}

@end
