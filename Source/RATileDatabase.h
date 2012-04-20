//
//  RATileDatabase.h
//  RASceneGraphTest
//
//  Created by Ross Anderson on 3/1/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RAGeographicUtils.h"

typedef struct {
    NSUInteger x;
    NSUInteger y;
    NSUInteger z;
} TileID;

TileID TileOppositeCorner( TileID t );


@interface RATileDatabase : NSObject

// Useful information:
// http://www.maptiler.org/google-maps-coordinates-tile-bounds-projection/

// a base url string is picked at random for each tile
// the base url should contain the replacement tokens {x} {y} {z} for the tile

@property (assign, nonatomic) CGRect bounds;
@property (strong, nonatomic) NSArray * baseUrlStrings;
@property (assign, nonatomic) NSUInteger minzoom;
@property (assign, nonatomic) NSUInteger maxzoom;
@property (assign, nonatomic) BOOL googleTileConvention;

- (double)resolutionAtZoom:(NSUInteger)zoom;
- (CGPoint)latLonToMeters:(RAPolarCoordinate)coord;
- (RAPolarCoordinate)metersToLatLon:(CGPoint)m;
- (GLKVector2)textureCoordsForLatLon:(RAPolarCoordinate)coord inTile:(TileID)t;
- (CGPoint)metersToPixels:(CGPoint)m atZoom:(NSUInteger)zoom;
- (CGPoint)pixelsToMeters:(CGPoint)m atZoom:(NSUInteger)zoom;
- (RAPolarCoordinate)tileLatLonOrigin:(TileID)t;
- (RAPolarCoordinate)tileLatLonCenter:(TileID)t;
- (double)tileRadius:(TileID)t;

- (NSURL *)urlForTile:(TileID)tile;
- (UIImage *)blockingLoadTile:(TileID)tile;

@end
