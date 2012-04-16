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
    // the following code snippet was ported from OpenSceneGraph: BoundingSphere
    
    // ignore operation if incoming BoundingSphere is invalid
    if ( ![bound valid] ) return;
    
    // if the sphere is currently invalid, set to the provided sphere
    if ( ![self valid] ) {
        center = bound.center;
        radius = bound.radius;
        return;
    }
    
    // calculate the distance between sphere centers   
    double d = GLKVector3Distance( center, bound.center );
    
    // new sphere is already entirely inside this one
    if ( d + bound.radius <= radius ) return;
    
    //  new sphere completely contains this one
    if ( d + radius <= bound.radius ) {
        center = bound.center;
        radius = bound.radius;
        return;
    }
    
    // build a new sphere that completely contains the other two
    // the center point lies halfway along the line between the furthest
    // points on the edges of the two spheres
    
    // computing those two points is ugly - so we'll use similar triangles
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
    
    // this algorithm was ported from OpenSceneGraph: Transform.cpp
    
    GLKVector3 x_prime = self.center;
    x_prime.x += self.radius;
    x_prime = GLKMatrix4MultiplyAndProjectVector3( tr, x_prime );
    
    GLKVector3 y_prime = self.center;
    y_prime.y += self.radius;
    y_prime = GLKMatrix4MultiplyAndProjectVector3( tr, y_prime );
    
    GLKVector3 z_prime = self.center;
    z_prime.z += self.radius;
    z_prime = GLKMatrix4MultiplyAndProjectVector3( tr, z_prime );
    
    newbounds.center = GLKMatrix4MultiplyAndProjectVector3( tr, self.center );
    
    // calculate the radius from center
    float x_prime_radius = GLKVector3Length( GLKVector3Subtract( x_prime, newbounds.center ) );
    float y_prime_radius = GLKVector3Length( GLKVector3Subtract( y_prime, newbounds.center ) );
    float z_prime_radius = GLKVector3Length( GLKVector3Subtract( z_prime, newbounds.center ) );
    
    // choose the longest radius
    newbounds.radius = x_prime_radius;
    if (newbounds.radius < y_prime_radius) newbounds.radius = y_prime_radius;
    if (newbounds.radius < z_prime_radius) newbounds.radius = z_prime_radius;

    return newbounds;
    
}


@end
