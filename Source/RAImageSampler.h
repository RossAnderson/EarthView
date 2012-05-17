//
//  RAImageSampler.h
//  EarthViewExample
//
//  Created by Ross Anderson on 5/4/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RAImageSampler : NSObject

@property (readonly) NSUInteger width;
@property (readonly) NSUInteger height;

- (id)initWithImage:(UIImage *)img;

- (CGFloat)grayAtNearestPixel:(CGPoint)p;
- (CGFloat)grayByInterpolatingPixels:(CGPoint)p;

- (UIColor *)colorAtNearestPixel:(CGPoint)p;
- (UIColor *)colorByInterpolatingPixels:(CGPoint)p;

@end
