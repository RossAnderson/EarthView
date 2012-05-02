//
//  RAPage.m
//  Jetsnapper
//
//  Created by Ross Anderson on 3/11/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAPage.h"

@implementation RAPage {
    RABoundingSphere *  _bound;
    RAPage *            _parent;
    
    NSURLConnection *   _connection;
    NSMutableData *     _imageData;
}

@synthesize tile, key;
@synthesize bound = _bound;
@synthesize parent = _parent, child1, child2, child3, child4;
@synthesize geometry, imagery, terrain;
@synthesize needsUpdate, imageryLoadOp, terrainLoadOp, updatePageOp;

- (RAPage *)initWithTileID:(TileID)t andParent:(RAPage *)parent;
{
    self = [super init];
    if (self) {
        tile = t;
        key = [NSString stringWithFormat:@"{%d,%d,%d}", t.z, t.x, t.y];
        needsUpdate = YES;
        _parent = parent;
    }
    return self;
}

- (void)dealloc {
    [_connection cancel];
}

- (void)setCenter:(GLKVector3)center andRadius:(double)radius {
    _bound = [RABoundingSphere new];
    _bound.center = center;
    _bound.radius = radius;
}

@end
