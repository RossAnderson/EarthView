//
//  RAPage.m
//  Jetsnapper
//
//  Created by Ross Anderson on 3/11/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAPage.h"

static NSUInteger sTotalPageCount = 0;

@implementation RAPage {
    RABoundingSphere *  _bound;
    __weak RAPage *     _parent;
}

@synthesize tile, key;
@synthesize bound = _bound;
@synthesize parent = _parent, child1, child2, child3, child4;
@synthesize lastRequestedTimestamp;
@synthesize geometryState, geometry, imageryState, imagery, terrainState, terrain;

+ (NSUInteger)count {
    return sTotalPageCount;
}

- (RAPage *)initWithTileID:(TileID)t andParent:(RAPage *)parent;
{
    self = [super init];
    if (self) {
        tile = t;
        key = [NSString stringWithFormat:@"{%d,%d,%d}", t.z, t.x, t.y];
        _parent = parent;
        sTotalPageCount++;
        
        geometryState = NotLoaded;
        imageryState = NotLoaded;
        terrainState = NotLoaded;
    }
    return self;
}

- (void)dealloc {
    sTotalPageCount--;
}

- (void)setCenter:(GLKVector3)center andRadius:(double)radius {
    _bound = [RABoundingSphere new];
    _bound.center = center;
    _bound.radius = radius;
}

- (float)calculateTiltWithCamera:(RACamera *)camera {
    // calculate dot product between page normal and camera vector
    const GLKVector3 unitZ = { 0, 0, -1 };
    GLKVector3 pageNormal = GLKVector3Normalize(self.bound.center);
    GLKVector3 cameraLook = GLKVector3Normalize(GLKMatrix4MultiplyAndProjectVector3( GLKMatrix4Invert(camera.modelViewMatrix, NULL), unitZ ));
    return GLKVector3DotProduct(pageNormal, cameraLook);
}

- (float)calculateScreenSpaceErrorWithCamera:(RACamera *)camera {
    GLKVector3 center = GLKMatrix4MultiplyAndProjectVector3( camera.modelViewMatrix, self.bound.center );
    double distance = GLKVector3Length(center);
    
    // convert object error to screen error
    CGSize size = camera.viewport.size;
    float epsilon = ( 2. * self.bound.radius ) / 256.;    // object error
    float x = MAX(size.width, size.height) * [[UIScreen mainScreen] scale];    // screen size
    float w = 2. * distance * camera.tanThetaOverTwo;
    return ( epsilon * x ) / w;
}

- (BOOL)isOnscreenWithCamera:(RACamera *)camera {
    // convert the bounding sphere center into camera space
    GLKVector3 s = GLKMatrix4MultiplyAndProjectVector3( camera.modelViewMatrix, self.bound.center );
    
    float radius = self.bound.radius * 1.5f;

    // test against near/far planes
    if ( s.z - radius > -camera.near ) return NO;
    if ( s.z + radius < -camera.far ) return NO;

    // left, right, top, bottom planes
    if ( GLKVector3DotProduct( camera.leftPlaneNormal, s ) > radius ) return NO;
    if ( GLKVector3DotProduct( camera.rightPlaneNormal, s ) > radius ) return NO;
    if ( GLKVector3DotProduct( camera.topPlaneNormal, s ) > radius ) return NO;
    if ( GLKVector3DotProduct( camera.bottomPlaneNormal, s ) > radius ) return NO;
    
    return YES;
}

- (BOOL)isReady {
    return ( geometryState == Complete ) || ( geometryState == NeedsUpdate );
}

@end
