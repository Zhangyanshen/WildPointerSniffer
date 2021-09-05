//
//  ViewController.m
//  HookDeallocDemo
//
//  Created by 张延深 on 2021/9/5.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)btnClick:(UIButton *)sender {
    NSLog(@"11111");
    
    UIView *view = [[UIView alloc] init];
    [view release];
    
    UIView *view1 = [[UIView alloc] init];
//    [self.view addSubview:view1];
    
    [view setNeedsLayout];
}

@end
