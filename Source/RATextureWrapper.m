//
//  RATextureWrapper.m
//  Jetsnapper
//
//  Created by Ross Anderson on 3/11/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RATextureWrapper.h"

#define kMaxDeleteBatchSize (8)


@implementation RATextureWrapper {
    NSString *  _contextKey;
}

@synthesize name = _name;
@synthesize target = _target;
@synthesize width = _width;
@synthesize height = _height;
@synthesize alphaState = _alphaState;
@synthesize textureOrigin = _textureOrigin;
@synthesize containsMipmaps = _containsMipmaps;

+ (NSMutableDictionary *)textureSetDictionary {
    static NSMutableDictionary * dict = nil;
    if ( dict == nil ) dict = [NSMutableDictionary dictionary];
    return dict;
}

+ (NSMutableSet *)textureSetForKey:(NSString *)key {
    // get or create a set for this context
    NSMutableDictionary * dict = [[self class] textureSetDictionary];
    NSMutableSet * set = [dict objectForKey:key];
    if ( !set ) {
        set = [NSMutableSet set];
        [dict setValue:set forKey:key];
    }
    return set;
}

+ (void)cleanup {
    EAGLContext * context = [EAGLContext currentContext];
    NSAssert( context, @"OpenGL ES context must be valid!" );
    
    NSString * key = [context description];
    NSMutableSet * set = [self textureSetForKey:key];
    
    GLuint * textureNames = NULL;
    NSUInteger count = 0;
    
    @synchronized (set) {
        if ( [set count] < 1 ) return;

        textureNames = (GLuint *)alloca( kMaxDeleteBatchSize );
        
        while( count < kMaxDeleteBatchSize && [set count] ) {
            NSNumber * nameValue = [set anyObject];
            [set removeObject:nameValue];
            
            textureNames[count] = [nameValue intValue];
            count++;
        }
    }

    glDeleteTextures(count, textureNames);
    NSLog(@"Deleted %d textures.", count);

    // check for errors
    GLenum err = glGetError();
    if ( err != GL_NO_ERROR )
        NSLog(@"+[RATextureWrapper cleanup]: glGetError = %d", err);
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

        EAGLContext * context = [EAGLContext currentContext];
        NSAssert( context, @"OpenGL ES context must be valid!" );
        _contextKey = [context description];
    }
    return self;
}

- (void)dealloc {
    if ( _name && _contextKey ) {
        NSMutableSet * set = [[self class] textureSetForKey:_contextKey];

        // mark for cleanup
        @synchronized (set) {
            [set addObject:[NSNumber numberWithInt:_name]];
        }
    }
}


@end
