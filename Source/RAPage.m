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
    // in this case, should test all four corners of the tile and take min distance
    GLKVector3 center = GLKMatrix4MultiplyAndProjectVector3( camera.modelViewMatrix, self.bound.center );
    double distance = GLKVector3Length(center); // !!! this does not work so well on large, curved pages
    //double distance = -center.z;  // seem like this should be more accurate, but the math isn't quite right. It favors pages near the equator
        
    // !!! this should be based upon the Camera parameters
    double theta = GLKMathDegreesToRadians(65.0f);
    double w = 2. * distance * tan(theta/2.);
    
    // convert object error to screen error
    double x = camera.viewport.size.width;    // screen size
    double epsilon = ( 2. * self.bound.radius ) / 256.;    // object error
    return ( epsilon * x ) / w;
}

- (BOOL)isOnscreenWithCamera:(RACamera *)camera {
    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply( camera.projectionMatrix, camera.modelViewMatrix );
    
    RABoundingSphere * sb = [self.bound transform:modelViewProjectionMatrix];
    if ( sb.center.x + sb.radius < -1 || sb.center.x - sb.radius > 1 ) return NO;
    if ( sb.center.y + sb.radius < -1 || sb.center.y - sb.radius > 1 ) return NO;
    
    return YES;
}

- (BOOL)isReady {
    return ( geometryState == Complete ) || ( geometryState == NeedsUpdate );
}

@end
