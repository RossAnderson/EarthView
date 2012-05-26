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


@interface RACamera : NSObject

@property (assign) CGRect viewport;
@property (assign) float fieldOfView;   // degrees
@property (assign) GLKMatrix4 modelViewMatrix;

@property (readonly) GLKMatrix4 projectionMatrix;
@property (readonly) float tanThetaOverTwo;

- (void)calculateProjectionForBounds:(RABoundingSphere *)bound;

@end
