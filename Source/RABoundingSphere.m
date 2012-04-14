//
//  RABoundingSphere.m
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RABoundingSphere.h"

#import <GLKit/GLKVector3.h>
#import <GLKit/GLKMatrix4.h>
#import <GLKit/GLKMathUtils.h>


@implementation RABoundingSphere

@synthesize center, radius;

- (id)init
{
    self = [super init];
    if (self) {
        center = GLKVector3Make(0, 0, 0);
        radius = -1.0f;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: center=%@, radius=%f",
            NSStringFromClass([self class]),
            NSStringFromGLKVector3(center),
            radius];
}

- (float)radius2
{
    return radius*radius;
}

- (BOOL)valid
{
    return radius >= 0.0f;
}

- (void)expandByPoint:(GLKVector3)point
{
    if ( [self valid] )
    {
        GLKVector3 dv = GLKVector3Subtract( point, center );
        float r = GLKVector3Length( dv );
        if ( r > radius )
        {
            float dr = ( r - radius ) * 0.5f;
            dv = GLKVector3MultiplyScalar( dv, dr/r );
            center = GLKVector3Add( center, dv );
            radius += dr;
        }
    }
    else
    {
        center = point;
        radius = 0.0;
    }
}

- (void)expandByBoundingSphere:(RABoundingSphere *)bound
{
    // ignore operation if incomming BoundingSphere is invalid.
    if ( ![bound valid] ) return;
    
    // This sphere is not set so use the inbound sphere
    if ( ![self valid] ) {
        center = bound.center;
        radius = bound.radius;
        return;
    }
    
    // Calculate d == The distance between the sphere centers   
    double d = GLKVector3Distance( center, bound.center );
    
    // New sphere is already inside this one
    if ( d + bound.radius <= radius ) return;
    
    //  New sphere completely contains this one 
    if ( d + radius <= bound.radius ) {
        center = bound.center;
        radius = bound.radius;
        return;
    }
    
    // Build a new sphere that completely contains the other two:
    //
    // The center point lies halfway along the line between the furthest
    // points on the edges of the two spheres.
    //
    // Computing those two points is ugly - so we'll use similar triangles
    double new_radius = (radius + d + bound.radius ) * 0.5;
    double ratio = ( new_radius - radius ) / d ;
    
    center.v[0] += ( bound.center.v[0] - center.v[0] ) * ratio;
    center.v[1] += ( bound.center.v[1] - center.v[1] ) * ratio;
    center.v[2] += ( bound.center.v[2] - center.v[2] ) * ratio;
    
    radius = new_radius;
}

- (BOOL)contains:(GLKVector3)point
{
    if ( radius <= 0.0f ) return NO;
    
    GLKVector3 diff = GLKVector3Subtract( point, center );
    return [self valid] && ( GLKVector3DotProduct(diff, diff) <= radius*radius );
}

- (BOOL)intersectsBoundingSphere:(RABoundingSphere *)bound
{
    if ( ![self valid] || ![bound valid] ) return NO;
    
    GLKVector3 diff = GLKVector3Subtract( center, bound.center );

    return ( GLKVector3DotProduct(diff, diff) <= (radius + bound.radius)*(radius + bound.radius));
}

- (RABoundingSphere *)transform:(GLKMatrix4)tr
{
    RABoundingSphere * newbounds = [RABoundingSphere new];
    
    GLKVector3 xdash = self.center;
    xdash.x += self.radius;
    xdash = GLKMatrix4MultiplyAndProjectVector3( tr, xdash );
    
    GLKVector3 ydash = self.center;
    ydash.y += self.radius;
    ydash = GLKMatrix4MultiplyAndProjectVector3( tr, ydash );
    
    GLKVector3 zdash = self.center;
    zdash.z += self.radius;
    zdash = GLKMatrix4MultiplyAndProjectVector3( tr, zdash );
    
    newbounds.center = GLKMatrix4MultiplyAndProjectVector3( tr, self.center );
    
    xdash = GLKVector3Subtract( xdash, newbounds.center );
    float len_xdash = GLKVector3Length( xdash );
    
    ydash = GLKVector3Subtract( ydash, newbounds.center );
    float len_ydash = GLKVector3Length( ydash );
    
    zdash = GLKVector3Subtract( zdash, newbounds.center );
    float len_zdash = GLKVector3Length( zdash );
    
    newbounds.radius = len_xdash;
    if (newbounds.radius < len_ydash) newbounds.radius = len_ydash;
    if (newbounds.radius < len_zdash) newbounds.radius = len_zdash;
    
    return newbounds;
    
}


@end
