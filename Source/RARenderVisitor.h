//
//  RARenderVisitor.h
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/18/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <GLKit/GLKBaseEffect.h>

#import "RANodeVisitor.h"
#import "RACamera.h"


@interface RARenderVisitor : RANodeVisitor

@property (strong) RACamera * camera;
@property (assign) GLKVector3 lightPosition;
@property (assign) GLKVector4 lightAmbientColor;
@property (assign) GLKVector4 lightDiffuseColor;

- (void)clear;
- (void)sortBackToFront;

- (void)setupGL;
- (void)tearDownGL;

- (void)render;

@end
