//
//  ViewController.m
//  WCPlayer
//
//  Created by Kina on 2018/9/6.
//  Copyright © 2018 zdx. All rights reserved.
//

#import "ViewController.h"
#import "WCPlayerDecoder.h"


@interface ViewController ()

@property(nonatomic, strong) WCPlayerDecoder *decoder;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.decoder = [[WCPlayerDecoder alloc] init];
    
    dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.decoder startDecoder];
    });
    
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    const char *config = avcodec_configuration();
    NSLog(@"config: %s", config);
}

@end
