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
    
    RAGeometry *        _geometry;

    NSURLConnection *   _connection;
    NSMutableData *     _imageData;
}

@synthesize tile, key;
@synthesize bound = _bound;
@synthesize parent = _parent, child1, child2, child3, child4;
@synthesize texture = _texture;
@synthesize geometry = _geometry;
//@synthesize lastRequestTime;

- (RAPage *)initWithTileID:(TileID)t andParent:(RAPage *)parent;
{
    self = [super init];
    if (self) {
        tile = t;
        key = [NSString stringWithFormat:@"{%d,%d,%d}", t.z, t.x, t.y];
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

- (BOOL)isReady {
    return _geometry != nil;
}

- (BOOL)isLeaf {
    return ( child1 == nil && child2 == nil && child3 == nil && child4 == nil );
}

@end
