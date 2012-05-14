//
//  RAPage.h
//  Jetsnapper
//
//  Created by Ross Anderson on 3/11/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RAGeographicUtils.h"
#import "RABoundingSphere.h"
#import "RAGeometry.h"
#import "RACamera.h"
#import "RATileDatabase.h"

typedef enum {
    NotLoaded = 0,
    Loading,
    Complete,
    Failed,
    NeedsUpdate
} RAPageLoadState;


@interface RAPage : NSObject

@property (readonly, nonatomic) TileID tile;
@property (readonly, nonatomic) NSString * key;
@property (readonly, nonatomic) RABoundingSphere * bound;

@property (readonly, weak, nonatomic) RAPage * parent;
@property (strong, nonatomic) RAPage * child1;
@property (strong, nonatomic) RAPage * child2;
@property (strong, nonatomic) RAPage * child3;
@property (strong, nonatomic) RAPage * child4;

@property (assign, nonatomic) NSTimeInterval lastRequestedTimestamp;

@property (assign, nonatomic) RAPageLoadState geometryState;
@property (strong, nonatomic) RAGeometry * geometry;

@property (assign, nonatomic) RAPageLoadState imageryState;
@property (strong, nonatomic) RATextureWrapper * imagery;

@property (assign, nonatomic) RAPageLoadState terrainState;
@property (strong, nonatomic) UIImage * terrain;

+ (NSUInteger)count;

- (RAPage *)initWithTileID:(TileID)t andParent:(RAPage *)parent;

- (void)setCenter:(GLKVector3)center andRadius:(double)radius;

- (float)calculateTiltWithCamera:(RACamera *)camera;
- (float)calculateScreenSpaceErrorWithCamera:(RACamera *)camera;
- (BOOL)isOnscreenWithCamera:(RACamera *)camera;

- (BOOL)isReady;

@end
