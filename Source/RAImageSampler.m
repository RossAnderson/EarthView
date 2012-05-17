//
//  RAImageSampler.m
//  EarthViewExample
//
//  Created by Ross Anderson on 5/4/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAImageSampler.h"

@implementation RAImageSampler {
    NSUInteger      _bytesPerPixel;
    NSUInteger      _bytesPerRow;
    NSUInteger      _width;
    NSUInteger      _height;
    unsigned char * _rawData;
}

- (id)initWithImage:(UIImage *)img {
    self = [super init];
    if ( self ) {
        
        // valid image?
        if ( img == nil ) return nil;
        
        CGImageRef imageRef = [img CGImage];
        _width = CGImageGetWidth(imageRef);
        _height = CGImageGetHeight(imageRef);
        _bytesPerPixel = 4;
        _bytesPerRow = _bytesPerPixel * _width;
        
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSUInteger bitsPerComponent = 8;

        // get raw access to image data
        _rawData = (unsigned char*)calloc(_height * _width * 4, sizeof(unsigned char));
        CGContextRef context = CGBitmapContextCreate(_rawData, _width, _height, 
            bitsPerComponent, _bytesPerRow, colorSpace,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(colorSpace);
        
        CGContextDrawImage(context, CGRectMake(0, 0, _width, _height), imageRef);
        CGContextRelease(context);
    }
    return self;
}

- (void)dealloc {
    if ( _rawData ) free( _rawData );
}

- (NSUInteger)width {
    return _width;
}

- (NSUInteger)height {
    return _height;
}

- (BOOL)extractNearestRgba:(CGPoint)p to:(CGFloat*)rgba {
    // y-flip
    p.y = _height - 1.0f - p.y;
    
    int x = round(p.x);
    int y = round(p.y);
    
    if ( x < 0 || x >= _width ) return NO;
    if ( y < 0 || y >= _height ) return NO;
    
    unsigned char * pixel = _rawData + (_bytesPerRow * y) + (_bytesPerPixel * x);
    
    rgba[0] = pixel[0] / 255.0;
    rgba[1] = pixel[1] / 255.0;
    rgba[2] = pixel[2] / 255.0;
    rgba[3] = pixel[3] / 255.0;
    return YES;
}

- (BOOL)extractInterpolatedRgba:(CGPoint)p to:(CGFloat*)rgba {
    // snap to bounds of image
    if ( p.x < 0 ) return [self extractInterpolatedRgba:CGPointMake(0, p.y) to:rgba];
    if ( p.x > _width-2 ) return [self extractInterpolatedRgba:CGPointMake(_width-2, p.y) to:rgba];
    if ( p.y < 0 ) return [self extractInterpolatedRgba:CGPointMake(p.x, 0) to:rgba];
    if ( p.y > _height-2 ) return [self extractInterpolatedRgba:CGPointMake(p.x, _height-2) to:rgba];
    
    // y-flip
    p.y = _height-2 - p.y;
    
    int x0 = floor(p.x);
    int y0 = floor(p.y);
    int x1 = x0 + 1;
    int y1 = y0 + 1;
    
    CGFloat ipart;
    CGFloat xf0 = 1.0f - modff(p.x, &ipart);
    CGFloat yf0 = 1.0f - modff(p.y, &ipart);
    CGFloat xf1 = 1.0f - xf0;
    CGFloat yf1 = 1.0f - yf0;
    
    unsigned char * pixel_x0y0 = _rawData + (_bytesPerRow * y0) + (_bytesPerPixel * x0);
    unsigned char * pixel_x1y0 = _rawData + (_bytesPerRow * y0) + (_bytesPerPixel * x1);
    unsigned char * pixel_x0y1 = _rawData + (_bytesPerRow * y1) + (_bytesPerPixel * x0);
    unsigned char * pixel_x1y1 = _rawData + (_bytesPerRow * y1) + (_bytesPerPixel * x1);
    
    // do bilinear interpolation
    float sy0[4] = { pixel_x0y0[0] * xf0 + pixel_x1y0[0] * xf1,
        pixel_x0y0[1] * xf0 + pixel_x1y0[1] * xf1,
        pixel_x0y0[2] * xf0 + pixel_x1y0[2] * xf1,
        pixel_x0y0[3] * xf0 + pixel_x1y0[3] * xf1 };
    float sy1[4] = { pixel_x0y1[0] * xf0 + pixel_x1y1[0] * xf1,
        pixel_x0y1[1] * xf0 + pixel_x1y1[1] * xf1,
        pixel_x0y1[2] * xf0 + pixel_x1y1[2] * xf1,
        pixel_x0y1[3] * xf0 + pixel_x1y1[3] * xf1 };
    float sxy[4] = { sy0[0] * yf0 + sy1[0] * yf1,
        sy0[1] * yf0 + sy1[1] * yf1,
        sy0[2] * yf0 + sy1[2] * yf1,
        sy0[3] * yf0 + sy1[3] * yf1 };
    
    rgba[0] = sxy[0] / 255.0;
    rgba[1] = sxy[1] / 255.0;
    rgba[2] = sxy[2] / 255.0;
    rgba[3] = sxy[3] / 255.0;
    return YES;
}

- (CGFloat)grayAtNearestPixel:(CGPoint)p {
    CGFloat rgba[4];
    if ( ![self extractNearestRgba:p to:rgba] ) return -1;
    return ( rgba[0] + rgba[1] + rgba[2] ) * 0.33f;
}

- (CGFloat)grayByInterpolatingPixels:(CGPoint)p {
    CGFloat rgba[4];
    if ( ![self extractInterpolatedRgba:p to:rgba] ) return -1;
    return ( rgba[0] + rgba[1] + rgba[2] ) * 0.33f;
}

- (UIColor *)colorAtNearestPixel:(CGPoint)p {
    CGFloat rgba[4];
    if ( ![self extractNearestRgba:p to:rgba] ) return nil;
    return [UIColor colorWithRed:rgba[0] green:rgba[1] blue:rgba[2] alpha:rgba[3]];
}

- (UIColor *)colorByInterpolatingPixels:(CGPoint)p {
    CGFloat rgba[4];
    if ( ![self extractInterpolatedRgba:p to:rgba] ) return nil;
    return [UIColor colorWithRed:rgba[0] green:rgba[1] blue:rgba[2] alpha:rgba[3]];
}

@end
