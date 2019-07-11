//
//  ViewController.m
//  YZMonitorRunLoopDemo
//
//  Created by eagle on 2019/6/18.
//  Copyright © 2019 yongzhen. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
     usleep(1 * 1000 * 1000); // 1秒
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
     usleep(1 * 1000 * 1000); // 1秒
   
}

@end
