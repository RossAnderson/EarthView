//
//  RACamera.m
//  Jetsnapper
//
//  Created by Ross Anderson on 3/18/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RACamera.h"

@implementation RACamera

@synthesize modelViewMatrix=_modelViewMatrix;
@synthesize projectionMatrix=_projectionMatrix;
@synthesize tanThetaOverTwo=_tanThetaOverTwo;
@synthesize viewport, fieldOfView;

- (id)init
{
    self = [super init];
    if (self) {
        self.fieldOfView = 65.0f;
        _modelViewMatrix = GLKMatrix4Identity;
    }
    return self;
}

- (void)calculateProjectionForBounds:(RABoundingSphere *)bound {
    float aspect = fabsf(viewport.size.width / viewport.size.height);

    // calculate min/max scene distance
    GLKVector3 center = GLKMatrix4MultiplyAndProjectVector3(_modelViewMatrix, bound.center);
    float minDistance = -center.z - bound.radius;
    float maxDistance = -center.z + bound.radius;
    if ( minDistance < 0.0001f ) minDistance = 0.0001f;
    
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(self.fieldOfView), aspect, minDistance, maxDistance);
    _tanThetaOverTwo = tan(GLKMathDegreesToRadians(self.fieldOfView)/2.);
}

@end
