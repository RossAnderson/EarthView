//
//  RACamera.h
//  Jetsnapper
//
//  Created by Ross Anderson on 3/18/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>

#import "RABoundingSphere.h"

extern NSString * RACameraStateChangedNotification;


@interface RACamera : NSObject

@property (assign) CGRect viewport;
@property (assign) float fieldOfView;   // degrees
@property (assign) GLKMatrix4 modelViewMatrix;

@property (readonly) GLKMatrix4 projectionMatrix;
@property (readonly) float near, far;
@property (readonly) float tanThetaOverTwo;
@property (readonly) float cosThetaOverTwo;
@property (readonly) float sinThetaOverTwo;
@property (readonly) float aspect;

@property (readonly) GLKVector3 leftPlaneNormal;
@property (readonly) GLKVector3 rightPlaneNormal;
@property (readonly) GLKVector3 topPlaneNormal;
@property (readonly) GLKVector3 bottomPlaneNormal;

- (void)calculateProjectionForBounds:(RABoundingSphere *)bound;

- (void)followCamera:(RACamera *)primary;

@end
