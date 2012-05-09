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

- (UIColor *)colorAtNearestPixel:(CGPoint)p {
    // y-flip
    p.y = _height - 1.0f - p.y;
    
    int x = round(p.x);
    int y = round(p.y);
    
    if ( x < 0 || x >= _width ) return nil;
    if ( y < 0 || y >= _height ) return nil;
    
    unsigned char * pixel = _rawData + (_bytesPerRow * y) + (_bytesPerPixel * x);
    
    CGFloat red   = pixel[0] / 255.0;
    CGFloat green = pixel[1] / 255.0;
    CGFloat blue  = pixel[2] / 255.0;
    CGFloat alpha = pixel[3] / 255.0;
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}
- (UIColor *)colorByInterpolatingPixels:(CGPoint)p {
    // snap to bounds of image
    if ( p.x < 0 ) return [self colorByInterpolatingPixels:CGPointMake(0, p.y)];
    if ( p.x > _width-2 ) return [self colorByInterpolatingPixels:CGPointMake(_width-2, p.y)];
    if ( p.y < 0 ) return [self colorByInterpolatingPixels:CGPointMake(p.x, 0)];
    if ( p.y > _height-2 ) return [self colorByInterpolatingPixels:CGPointMake(p.x, _height-2)];

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
    
    CGFloat red   = sxy[0] / 255.0;
    CGFloat green = sxy[1] / 255.0;
    CGFloat blue  = sxy[2] / 255.0;
    CGFloat alpha = sxy[3] / 255.0;
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:alpha];
}

@end
