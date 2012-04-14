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

@property (strong) RAGeometry * geometry;
@property (strong) UIImage * image;

@property (weak) NSOperation * buildOp;
@property (assign) BOOL needsUpdate;
@property (assign) NSTimeInterval lastRequestTime;

- (RAPage *)initWithTileID:(TileID)t andParent:(RAPage *)parent;
- (void)prune;

- (BOOL)isReady;
- (BOOL)isLeaf;

- (void)setCenter:(GLKVector3)center andRadius:(double)radius;

- (void)setupGL;
- (void)releaseGL;

@end
