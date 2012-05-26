//
//  RAManipulator.h
//  RASceneGraphTest
//
//  Created by Ross Anderson on 3/4/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GLKit/GLKit.h>

#import "RACamera.h"
#import "RAGeographicUtils.h"

extern NSString * RAManipulatorStateChangedNotification;


@interface RAManipulator : NSObject <UIGestureRecognizerDelegate>

@property (strong) RACamera * camera;

// animatable
@property (assign) double latitude;
@property (assign) double longitude;
@property (assign) double azimuth;
@property (assign) double elevation;
@property (assign) double distance;

- (void)addGesturesToView:(UIView *)view;

- (GLKMatrix4)modelViewMatrix;

@end
