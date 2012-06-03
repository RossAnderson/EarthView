//
//  RACamera.m
//  Jetsnapper
//
//  Created by Ross Anderson on 3/18/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RACamera.h"


NSString * RACameraStateChangedNotification = @"RACameraStateChangedNotification";

@implementation RACamera {
    RABoundingSphere *  _bound;
    __weak RACamera *   _follow;
    
    GLKMatrix4          _modelViewMatrix;
    GLKMatrix4          _projectionMatrix;
}

@synthesize viewport, fieldOfView;
@synthesize near=_near, far=_far;
@synthesize tanThetaOverTwo=_tanThetaOverTwo;
@synthesize sinThetaOverTwo=_sinThetaOverTwo;
@synthesize cosThetaOverTwo=_cosThetaOverTwo;
@synthesize aspect=_aspect;
@synthesize leftPlaneNormal=_leftPlaneNormal;
@synthesize rightPlaneNormal=_rightPlaneNormal;
@synthesize topPlaneNormal=_topPlaneNormal;
@synthesize bottomPlaneNormal=_bottomPlaneNormal;

- (id)init
{
    self = [super init];
    if (self) {
        self.fieldOfView = 65.0f;
        _modelViewMatrix = GLKMatrix4Identity;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    RACamera * camera = [[[self class] allocWithZone:zone] init];
    camera.viewport = self.viewport;
    camera.fieldOfView = self.fieldOfView;
    camera.modelViewMatrix = self.modelViewMatrix;
    if ( _bound ) [camera calculateProjectionForBounds:_bound];
    if ( _follow ) [camera followCamera:_follow];
    return camera;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)stateUpdated {
    [[NSNotificationCenter defaultCenter] postNotificationName:RACameraStateChangedNotification object:self];
}

- (GLKMatrix4)modelViewMatrix {
    return _modelViewMatrix;
}

- (void)setModelViewMatrix:(GLKMatrix4)modelViewMatrix {
    _modelViewMatrix = modelViewMatrix;
    [self stateUpdated];
}

- (GLKMatrix4)projectionMatrix {
    return _projectionMatrix;
}

- (void)calculateProjectionForBounds:(RABoundingSphere *)bound {
    _bound = bound;
    
    _aspect = fabsf(viewport.size.width / viewport.size.height);

    // calculate min/max scene distance
    GLKVector3 center = GLKMatrix4MultiplyAndProjectVector3(_modelViewMatrix, bound.center);
    _near = -center.z - bound.radius;
    _far = -center.z + bound.radius;
    if ( _near < 0.0001f ) _near = 0.0001f;
    
    _projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(self.fieldOfView), _aspect, _near, _far);
    
    float rad = GLKMathDegreesToRadians(self.fieldOfView / 2.0f);
    _tanThetaOverTwo = tanf(rad);
    _sinThetaOverTwo = sinf(rad);
    _cosThetaOverTwo = cosf(rad);

    _leftPlaneNormal = GLKVector3Make( -_cosThetaOverTwo, 0, _sinThetaOverTwo );
    _rightPlaneNormal = GLKVector3Make( _cosThetaOverTwo, 0, _sinThetaOverTwo );
    _topPlaneNormal = GLKVector3Make( 0, _cosThetaOverTwo/_aspect, _sinThetaOverTwo );
    _bottomPlaneNormal = GLKVector3Make( 0, -_cosThetaOverTwo/_aspect, _sinThetaOverTwo );
}

- (void)followCamera:(RACamera *)primary {
    _follow = primary;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(followCameraFromNotification:) name:RACameraStateChangedNotification object:primary];
}

- (void)followCameraFromNotification:(NSNotification *)note {
    RACamera * primary = note.object;
    
    [self setModelViewMatrix:primary.modelViewMatrix];
}

@end
