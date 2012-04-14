//
//  RAManipulator.h
//  RASceneGraphTest
//
//  Created by Ross Anderson on 3/4/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RARenderVisitor.h"

#import <GLKit/GLKit.h>
#import "RAGeographicUtils.h"
#import "RACamera.h"

@interface RAManipulator : NSObject <UIGestureRecognizerDelegate>

@property (readonly) RACamera * camera;
@property (weak) UIView * view;

// animatable
@property (assign) double latitude;
@property (assign) double longitude;
@property (assign) double azimuth;
@property (assign) double elevation;
@property (assign) double distance;

- (void)update;

@end
