//
//  RATextureWrapper.m
//  Jetsnapper
//
//  Created by Ross Anderson on 3/11/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RATextureWrapper.h"

@implementation RATextureWrapper

@synthesize name = _name;
@synthesize target = _target;
@synthesize width = _width;
@synthesize height = _height;
@synthesize alphaState = _alphaState;
@synthesize textureOrigin = _textureOrigin;
@synthesize containsMipmaps = _containsMipmaps;

+ (NSMutableSet *)cleanupTextureNameSet {
    static NSMutableSet * set = nil;
    if ( set == nil ) set = [NSMutableSet set];
    return set;
}

+ (void)cleanup {
    // must be called from within a valid OpenGL ES context!
    NSAssert( [EAGLContext currentContext], @"OpenGL ES context must be valid!" );
    
    GLuint * textureNames = NULL;
    NSUInteger index = 0;
    
    NSMutableSet * set = [[self class] cleanupTextureNameSet];
    @synchronized (set) {
        NSUInteger count = [set count];
        if ( count == 0 ) return;
        
        textureNames = (GLuint *)alloca( count * sizeof(GLuint) );
        
        NSEnumerator * nameEnum = [set objectEnumerator];
        NSNumber * nameValue = nil;
        
        while( nameValue = [nameEnum nextObject] ) {
            textureNames[index] = [nameValue intValue];
            if ( textureNames[index] > 0 ) index++;
        }
        NSAssert( index <= count, @"invalid index after enumeration" );
        
        [set removeAllObjects];
    }

    if ( index > 0 ) {
        glDeleteTextures(index, textureNames);
        //NSLog(@"Deleted %d texture.", index);

        /*
        // check for errors
        GLenum err = glGetError();
        if ( err != GL_NO_ERROR )
            NSLog(@"+[RATextureWrapper cleanup]: glGetError = %d", err);
        */
    }
}

- (id)initWithTextureInfo:(GLKTextureInfo *)info {
    self = [super init];
    if ( self && info ) {
        _name = info.name;
        _target = info.target;
        _width = info.width;
        _height = info.height;
        _alphaState = info.alphaState;
        _textureOrigin = info.textureOrigin;
        _containsMipmaps = info.containsMipmaps;
    }
    return self;
}

- (void)dealloc {
    // mark for cleanup
    NSMutableSet * set = [[self class] cleanupTextureNameSet];
    @synchronized (set) {
        if ( _name ) [set addObject:[NSNumber numberWithInt:_name]];
    }
}


@end
