//
//  RAShaderProgram.h
//  EarthViewExample
//
//  Created by Ross Anderson on 4/28/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GLKit/GLKVector3.h>
#import <GLKit/GLKMatrix4.h>


@interface RAShaderProgram : NSObject

- (BOOL)isReady;

// GLES context must be valid when calling these methods, and they must be called in this order:
- (BOOL)loadShader:(NSString *)resourceName;
- (void)bindAttribute:(NSString *)name toIdentifier:(NSUInteger)ident;
- (BOOL)link;
- (NSUInteger)indexForIdentifier:(NSUInteger)ident;
- (BOOL)bindUniform:(NSString *)name toIdentifier:(NSUInteger)ident;

- (void)use;
- (void)setUniform:(NSUInteger)ident toInt:(GLint)v;
- (void)setUniform:(NSUInteger)ident toVector3:(GLKVector3)v;
- (void)setUniform:(NSUInteger)ident toVector4:(GLKVector4)v;
- (void)setUniform:(NSUInteger)ident toMatrix4:(GLKMatrix4)m;

- (void)tearDownGL;

@end
