//
//  RATextureWrapper.m
//  Jetsnapper
//
//  Created by Ross Anderson on 3/11/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RATextureWrapper.h"

#define kMaxDeleteBatchSize (32)


@implementation RATextureWrapper {
    NSString *  _contextKey;
}

@synthesize name = _name;
@synthesize target = _target;
@synthesize width = _width;
@synthesize height = _height;

+ (NSMutableSet *)textureDeletionSetForKey:(NSString *)key {
    static NSMutableDictionary * dict = nil;
    if ( dict == nil ) dict = [NSMutableDictionary dictionary];
    
    // get or create a set for this context
    NSMutableSet * set = [dict objectForKey:key];
    if ( !set ) {
        set = [NSMutableSet set];
        [dict setValue:set forKey:key];
    }
    return set;
}

+ (void)cleanupAll:(BOOL)all {
    NSAssert( [EAGLContext currentContext], @"OpenGL ES context must be valid!" );
    
    NSString * key = [[[EAGLContext currentContext] sharegroup] description];
    NSMutableSet * set = [self textureDeletionSetForKey:key];
    
    GLuint textureNames[kMaxDeleteBatchSize];
    NSUInteger count = 0;
    
    @synchronized (set) {
        if ( set.count < 1 ) return;
        
        NSNumber * nameValue = nil;
        while( (nameValue = [set anyObject]) ) {
            [set removeObject:nameValue];
            
            textureNames[count] = [nameValue intValue];
            count++;
            
            if ( count == kMaxDeleteBatchSize ) break;
        }
    }
    
    if ( count > 0 ) {
        glDeleteTextures(count, textureNames);
        //NSLog(@"Deleted %d textures.", count);

        // check for errors
        GLenum err = glGetError();
        if ( err != GL_NO_ERROR )
            NSLog(@"+[RATextureWrapper cleanup]: glGetError = %d", err);
    }
    
    // cleanup more if requested
    if ( all ) [self cleanupAll:YES];
}

- (id)init
{
    self = [super init];
    if (self) {
        NSAssert( [EAGLContext currentContext], @"OpenGL ES context must be valid!" );
        NSString * key = [[[EAGLContext currentContext] sharegroup] description];
        _contextKey = key;
    }
    return self;
}

- (id)initWithTextureInfo:(GLKTextureInfo *)info {
    self = [self init];
    if ( self && info ) {
        _name = info.name;
        _target = info.target;
        _width = info.width;
        _height = info.height;
    }
    return self;
}

- (id)initWithImage:(UIImage *)image {
    self = [self init];
    if ( self && image ) {
        // get raw access to image data
        CGImageRef imageRef = [image CGImage];
        _width = CGImageGetWidth(imageRef);
        _height = CGImageGetHeight(imageRef);
        
        char * pixels = (char *)calloc( _height * _width * 4, sizeof(char) );
        NSUInteger bitsPerComponent = 8;
        NSUInteger bytesPerPixel = 4;
        NSUInteger bytesPerRow = bytesPerPixel * _width;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        CGContextRef context = CGBitmapContextCreate( pixels, _width, _height, 
                                                     bitsPerComponent, bytesPerRow, colorSpace,
                                                     kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big );
        
        // draw, y-flipped
        CGContextTranslateCTM( context, 0, _height );
        CGContextScaleCTM( context, 1.0f, -1.0f );
        CGContextDrawImage(context, CGRectMake(0, 0, _width, _height), imageRef);
        
        // generate texture object
        GLuint texture;
        glGenTextures( 1, &texture );
        glBindTexture( GL_TEXTURE_2D, texture );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE );
        glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE );
        _target = GL_TEXTURE_2D;
        _name = texture;
        
        // upload image
        glPixelStorei( GL_UNPACK_ALIGNMENT, 1 );
        glTexImage2D( GL_TEXTURE_2D, 0, GL_RGBA, _width, _height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels );
        //glGenerateMipmap( GL_TEXTURE_2D );    // results in poor image quality when tilted
        
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        free( pixels );

        // simple way to check that we don't have too many textures active
        if ( texture > 600 )
            NSLog(@"Warning: high texture id = %d", texture);
    }
    return self;
}

- (void)dealloc {
    if ( _name && _contextKey ) {
        NSMutableSet * set = [[self class] textureDeletionSetForKey:_contextKey];

        // mark for cleanup
        @synchronized (set) {
            [set addObject:[NSNumber numberWithInt:_name]];
        }
    }
}


@end
