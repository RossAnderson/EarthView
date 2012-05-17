//
//  RATileDatabase.m
//  RASceneGraphTest
//
//  Created by Ross Anderson on 3/1/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RATileDatabase.h"

#import <GLKit/GLKVector2.h>

const NSUInteger TileSize = 256;
const double InitialResolution = 2 * M_PI * 6378137 / TileSize;
const double OriginShift = 2 * M_PI * 6378137 / 2.0;

TileID TileOppositeCorner( TileID t ) {
    return (TileID){ t.x+1, t.y+1, t.z };
}


@implementation RATileDatabase

@synthesize bounds;
@synthesize baseUrlStrings;
@synthesize minzoom;
@synthesize maxzoom;
@synthesize googleTileConvention;

- (double)resolutionAtZoom:(NSUInteger)zoom {
    int tilecount = 1 << zoom;  // fast way to calc 2 ^ zoom
    return InitialResolution / (double)tilecount;
}

- (CGPoint)latLonToMeters:(RAPolarCoordinate)coord {
    CGPoint m;
    m.x = coord.longitude * OriginShift / 180.0;
    m.y = log( tan((90 + coord.latitude) * M_PI / 360.0 )) / (M_PI / 180.0);
    m.y = m.y * OriginShift / 180.0;
    return m;
}

- (RAPolarCoordinate)metersToLatLon:(CGPoint)m {
    RAPolarCoordinate p;
    p.longitude = (m.x / OriginShift) * 180.0;
    p.latitude = (m.y / OriginShift) * 180.0;
    p.latitude = 180 / M_PI * (2 * atan( exp( p.latitude * M_PI / 180.0)) - M_PI / 2.0);
    p.height = 0;
    return p;
}

- (GLKVector2)textureCoordsForLatLon:(RAPolarCoordinate)coord inTile:(TileID)t {
    CGPoint m = [self latLonToMeters:coord];
    CGPoint p = [self metersToPixels:m atZoom:t.z];
    
    p.x -= t.x * TileSize;
    p.y -= t.y * TileSize;
    
    // clip to tile bounds
    if ( p.x < 0 ) p.x = 0;
    if ( p.y < 0 ) p.y = 0;
    if ( p.x > TileSize ) p.x = TileSize;
    if ( p.y > TileSize ) p.y = TileSize;

    return GLKVector2Make( p.x/TileSize, p.y/TileSize );
}

- (CGPoint)metersToPixels:(CGPoint)m atZoom:(NSUInteger)zoom {
    CGPoint p;
    double res = [self resolutionAtZoom: zoom];
    p.x = (m.x + OriginShift) / res;
    p.y = (m.y + OriginShift) / res;
    return p;
}

- (CGPoint)pixelsToMeters:(CGPoint)p atZoom:(NSUInteger)zoom {
    CGPoint m;
    double res = [self resolutionAtZoom: zoom];
    m.x = p.x * res - OriginShift;
    m.y = p.y * res - OriginShift;
    return m;
}

- (RAPolarCoordinate)tileLatLonOrigin:(TileID)t {
    CGPoint ogn = [self pixelsToMeters:CGPointMake( t.x*TileSize, t.y*TileSize ) atZoom:t.z];
    return [self metersToLatLon: ogn];
}

- (RAPolarCoordinate)tileLatLonCenter:(TileID)t {
    CGPoint ogn = [self pixelsToMeters:CGPointMake( (t.x+0.5)*TileSize, (t.y+0.5)*TileSize ) atZoom:t.z];
    return [self metersToLatLon: ogn];
}

- (double)tileRadius:(TileID)t {
    return [self resolutionAtZoom:t.z] * (TileSize/2);
}

- (NSURL *)urlForTile:(TileID)tile {
    if ( tile.z < self.minzoom || tile.z > self.maxzoom )
        return nil;
    
    if ( self.googleTileConvention ) {
        int tilecount = 1 << tile.z;    // fast way to calc 2 ^ tile.z
        
        tile.y = tilecount - 1 - tile.y;
    }
    
    // !!! check in bounds
    
    // pick base string at random
    NSUInteger urlIndex = rand() % baseUrlStrings.count;
    NSMutableString * urlString = [[self.baseUrlStrings objectAtIndex:urlIndex] mutableCopy];
    
    [urlString replaceOccurrencesOfString:@"{x}" withString:[NSString stringWithFormat:@"%d", tile.x] options:NSCaseInsensitiveSearch range:NSMakeRange(0, [urlString length])];
    [urlString replaceOccurrencesOfString:@"{y}" withString:[NSString stringWithFormat:@"%d", tile.y] options:NSCaseInsensitiveSearch range:NSMakeRange(0, [urlString length])];
    [urlString replaceOccurrencesOfString:@"{z}" withString:[NSString stringWithFormat:@"%d", tile.z] options:NSCaseInsensitiveSearch range:NSMakeRange(0, [urlString length])];
    
    return [NSURL URLWithString:urlString];
}

- (UIImage *)blockingLoadTile:(TileID)tile {
    NSURL * url = [self urlForTile:tile];
    NSData * imageData = [NSData dataWithContentsOfURL:url];
    
    //NSLog(@"URL %@, Size = %d", url, [imageData length]);
    
    UIImage * image = [UIImage imageWithData:imageData];
    return image;
}

@end
