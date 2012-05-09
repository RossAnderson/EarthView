//
//  RAImageSampler.h
//  EarthViewExample
//
//  Created by Ross Anderson on 5/4/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RAImageSampler : NSObject

- (id)initWithImage:(UIImage *)img;

- (UIColor *)colorAtNearestPixel:(CGPoint)p;
- (UIColor *)colorByInterpolatingPixels:(CGPoint)p;

@end
