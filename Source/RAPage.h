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


@interface RAPage : NSObject

@property (readonly, nonatomic) TileID tile;
@property (readonly, nonatomic) NSString * key;
@property (readonly, nonatomic) RABoundingSphere * bound;

@property (readonly, nonatomic) RAPage * parent;
@property (strong, nonatomic) RAPage * child1;
@property (strong, nonatomic) RAPage * child2;
@property (strong, nonatomic) RAPage * child3;
@property (strong, nonatomic) RAPage * child4;

@property (strong, nonatomic) RAGeometry * geometry;

@property (strong, nonatomic) RATextureWrapper * imagery;
@property (strong, nonatomic) UIImage * terrain;

@property (assign, atomic) BOOL needsUpdate;
@property (weak, atomic) NSOperation * imageryLoadOp;
@property (weak, atomic) NSOperation * terrainLoadOp;
@property (weak, atomic) NSOperation * updatePageOp;

- (RAPage *)initWithTileID:(TileID)t andParent:(RAPage *)parent;

- (void)setCenter:(GLKVector3)center andRadius:(double)radius;

- (float)calculateTiltWithCamera:(RACamera *)camera;
- (float)calculateScreenSpaceErrorWithCamera:(RACamera *)camera;
- (BOOL)isOnscreenWithCamera:(RACamera *)camera;

@end
