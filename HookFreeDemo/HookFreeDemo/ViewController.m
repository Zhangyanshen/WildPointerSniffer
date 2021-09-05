//
//  ViewController.m
//  HookFreeDemo
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
    NSLog(@"111");
    UIView *view = [[UIView alloc] init];
    [view release];
    
    UIView *view2 = [[UIView alloc] init];
    [self.view addSubview:view2];
        
    [view setNeedsLayout];
}

@end
