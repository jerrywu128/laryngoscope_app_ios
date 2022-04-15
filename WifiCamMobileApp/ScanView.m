//
//  ScanView.m
//  laryngoscope_app_ios
//
//  Created by 吳旻洋 on 2022/1/7.
//  Copyright © 2022 HonestMedical. All rights reserved.
//

#import "ScanView.h"

@implementation ScanView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
 self = [super initWithCoder:aDecoder];
 
 if (self) {
  self.backgroundColor = [UIColor clearColor];
 }
 
 return self;
}
- (void)drawRect:(CGRect)rect
{
 CGContextRef context = UIGraphicsGetCurrentContext();
 

 // 绘制四角：
 CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
 CGContextSetLineWidth(context, 3.5);
 
 // 左上角：
 CGContextMoveToPoint(context, 0, 0);
 CGContextAddLineToPoint(context, 0, 47);
 CGContextMoveToPoint(context, 0, 0);
 CGContextAddLineToPoint(context, 47, 0);
 CGContextStrokePath(context);
 
 // 右上角：
 CGContextMoveToPoint(context, self.bounds.size.width, 0);
 CGContextAddLineToPoint(context, self.bounds.size.width-47, 0);
 CGContextMoveToPoint(context, self.bounds.size.width, 0);
 CGContextAddLineToPoint(context, self.bounds.size.width, 47);
 CGContextStrokePath(context);
 
 // 右下角：
 CGContextMoveToPoint(context, self.bounds.size.width, self.bounds.size.height);
 CGContextAddLineToPoint(context, self.bounds.size.width-47, self.bounds.size.height);
 CGContextMoveToPoint(context, self.bounds.size.width, self.bounds.size.height);
 CGContextAddLineToPoint(context, self.bounds.size.width , self.bounds.size.height-47);
 CGContextStrokePath(context);
 
 // 左下角：
 CGContextMoveToPoint(context, 0, self.bounds.size.height);
 CGContextAddLineToPoint(context, 0, self.bounds.size.height-47);
 CGContextMoveToPoint(context, 0, self.bounds.size.height);
 CGContextAddLineToPoint(context, 47, self.bounds.size.height);
 CGContextStrokePath(context);
}


@end




