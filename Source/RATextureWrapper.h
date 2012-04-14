//
//  RATextureWrapper.h
//  Jetsnapper
//
//  Created by Ross Anderson on 3/11/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GLKit/GLKTextureLoader.h>

// this class is a stand-in for GLKTextureInfo but adds the texture to a cleanup list when deallocated
// this allows the texture to be easily shared across objects
@interface RATextureWrapper : NSObject

@property (readonly) GLuint                     name;
@property (readonly) GLenum                     target;
@property (readonly) GLuint                     width;
@property (readonly) GLuint                     height;
@property (readonly) GLKTextureInfoAlphaState   alphaState;
@property (readonly) GLKTextureInfoOrigin       textureOrigin;
@property (readonly) BOOL                       containsMipmaps;

+ (void)cleanup;

- (id)initWithTextureInfo:(GLKTextureInfo *)info;

@end
