//
//  RAGeometry.h
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <GLKit/GLKit.h>

#import "RANode.h"
#import "RATextureWrapper.h"


@interface RAGeometry : RANode

// set to -1 if N/A
@property (assign, nonatomic) NSInteger positionOffset; // GLFloat X, Y, Z
@property (assign, nonatomic) NSInteger normalOffset;   // GLFloat X, Y, Z
@property (assign, nonatomic) NSInteger colorOffset;    // GLFloat r, g, b, a
@property (assign, nonatomic) NSInteger textureOffset;  // GLFloat s, t

@property (strong, nonatomic) RATextureWrapper * texture0;
@property (strong, nonatomic) RATextureWrapper * texture1;
@property (assign, nonatomic) GLKVector4 color;         // set 1st component to -1 to disable
@property (assign, nonatomic) GLenum elementStyle;      // default: GL_TRIANGLES

+ (void)cleanup;

- (void)setObjectData:(const void *)data withSize:(NSUInteger)length withStride:(NSUInteger)stride;
- (void)setIndexData:(const void *)data withSize:(NSUInteger)length withStride:(NSUInteger)stride;

// these methods must be called from within a context
- (void)setupGL;
- (void)releaseGL;
- (void)renderGL;

@end
