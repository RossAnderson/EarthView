//
//  RAGeometry.m
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "RAGeometry.h"

#import <GLKit/GLKEffects.h>
#import <GLKit/GLKMathTypes.h>
#import <GLKit/GLKVector3.h>

#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#import "RABoundingSphere.h"

#define BUFFER_INVALID ((GLuint)-1)


@implementation RAGeometry {
    GLuint          _vertexArray;
    GLuint          _vertexBuffer;
    GLuint          _indexBuffer;
    
    NSMutableData * _vertexData;
    GLint           _vertexStride;
    GLint           _positionOffset;
    GLint           _normalOffset;
    GLint           _colorOffset;
    
    NSMutableData * _indexData;
    GLint           _indexStride;
}

@synthesize positionOffset = _positionOffset;
@synthesize normalOffset = _normalOffset;
@synthesize colorOffset = _colorOffset;
@synthesize textureOffset = _textureOffset;
@synthesize texture = _texture;
@synthesize color = _color;
@synthesize material = _material;
@synthesize elementStyle = _elementStyle;


- (id)init
{
    self = [super init];
    if (self) {
        _vertexArray = BUFFER_INVALID;
        _vertexBuffer = BUFFER_INVALID;
        _indexBuffer = BUFFER_INVALID;
        
        _vertexStride = 0;
        _indexStride = 0;
        
        _positionOffset = -1;
        _normalOffset = -1;
        _colorOffset = -1;
        _textureOffset = -1;
        
        _color = GLKVector4Make(-1, -1, -1, -1);
        _elementStyle = GL_TRIANGLES;
    }
    return self;
}

- (SEL)visitorSelector
{
    return @selector(applyGeometry:);
}

- (void)calculateBound
{
    if ( !_vertexData || !_indexData ) return;
        
    size_t vertexCount = [_vertexData length]/_vertexStride;

    GLKVector3 center = GLKVector3Make(0, 0, 0);
    float maximumRadius = 0;

    // calculate average vertex position
    for( unsigned int i = 0; i < vertexCount; ++i ) {
        GLfloat * posPtr = (GLfloat *)( [_vertexData bytes] + i*_vertexStride + _positionOffset );
        GLKVector3 pos = GLKVector3Make( posPtr[0], posPtr[1], posPtr[2] );
        
        center.x += pos.x;
        center.y += pos.y;
        center.z += pos.z;
    }
    center.x /= vertexCount;
    center.y /= vertexCount;
    center.z /= vertexCount;
    
    // calculate maximum distance from center
    for( unsigned int i = 0; i < vertexCount; ++i ) {
        GLfloat * posPtr = (GLfloat *)( [_vertexData bytes] + i*_vertexStride + _positionOffset );
        GLKVector3 pos = GLKVector3Make( posPtr[0], posPtr[1], posPtr[2] );
        
        float distance = GLKVector3Distance(center, pos);
        
        if ( distance > maximumRadius ) maximumRadius = distance;
    }
    
    RABoundingSphere * newBound = [RABoundingSphere new];
    newBound.center = center;
    newBound.radius = maximumRadius;
    _bound = newBound;
}

- (void)setObjectData:(const void *)data withSize:(NSUInteger)length withStride:(NSUInteger)stride
{
    NSAssert( stride > 0, @"stride must be non-zero" );
    
    _vertexData = [NSMutableData dataWithBytes:data length:length];
    _vertexStride = stride;
    
    [self dirtyBound];
    
    // force re-gen of vertex buffer
    if ( _vertexBuffer != BUFFER_INVALID ) {
        glDeleteBuffers(1, &_vertexBuffer);
        _vertexBuffer = BUFFER_INVALID;
    }
}

- (void)setIndexData:(const void *)data withSize:(NSUInteger)length withStride:(NSUInteger)stride
{
    NSAssert( stride > 0, @"stride must be non-zero" );

    _indexData = [NSMutableData dataWithBytes:data length:length];
    _indexStride = stride;
    
    [self dirtyBound];

    // force re-gen of index buffer
    if ( _indexBuffer != BUFFER_INVALID ) {
        glDeleteBuffers(1, &_indexBuffer);
        _indexBuffer = BUFFER_INVALID;
    }
}

- (void)setupGL
{
    // create vertex array if needed
    if ( _vertexArray == BUFFER_INVALID ) {
        glGenVertexArraysOES(1, &_vertexArray);
    }
    
    glBindVertexArrayOES(_vertexArray);
    
    // create and setup data buffers
    if ( _vertexBuffer == BUFFER_INVALID && _vertexData && _vertexStride > 0 ) {
        glGenBuffers(1, &_vertexBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
        glBufferData(GL_ARRAY_BUFFER, [_vertexData length], [_vertexData bytes], GL_STATIC_DRAW);
    } else {
        glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    }
    
    if ( _indexBuffer == BUFFER_INVALID && _indexData && _indexStride > 0 ) {
        glGenBuffers(1, &_indexBuffer);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, [_indexData length], [_indexData bytes], GL_STATIC_DRAW);
    } else {
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    }
    
    // set attribute pointers
    if ( _positionOffset >= 0 ) {
        glEnableVertexAttribArray(GLKVertexAttribPosition);        
        glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, _vertexStride, (const GLvoid *)_positionOffset);
    }
    
    if ( _normalOffset >= 0 ) {
        glEnableVertexAttribArray(GLKVertexAttribNormal);        
        glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, _vertexStride, (const GLvoid *)_normalOffset);
    }
    
    if ( _colorOffset >= 0 ) {
        glEnableVertexAttribArray(GLKVertexAttribColor);
        glVertexAttribPointer(GLKVertexAttribColor, 4, GL_FLOAT, GL_FALSE, _vertexStride, (const GLvoid *)_colorOffset);
    }

    if ( _textureOffset >= 0 ) {
        glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
        glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, _vertexStride, (const GLvoid *)_textureOffset);
    }

    glBindVertexArrayOES(0);
}

- (void)releaseGL
{
    if ( _vertexBuffer != BUFFER_INVALID ) glDeleteBuffers(1, &_vertexBuffer);
    if ( _indexBuffer != BUFFER_INVALID ) glDeleteBuffers(1, &_indexBuffer);
    if ( _vertexArray != BUFFER_INVALID ) glDeleteVertexArraysOES(1, &_vertexArray);
    
    _vertexBuffer = BUFFER_INVALID;
    _indexBuffer = BUFFER_INVALID;
    _vertexArray = BUFFER_INVALID;
}

- (void)renderGL
{
    [self setupGL];
    
    glBindVertexArrayOES(_vertexArray);
    
    if ( _indexStride > 0 && [_indexData length] > 0 ) {
        GLenum type = -1;
        switch( _indexStride ) {
            case 1: type = GL_UNSIGNED_BYTE; break;
            case 2: type = GL_UNSIGNED_SHORT; break;
        }

        glDrawElements(self.elementStyle, [_indexData length]/_indexStride, type, 0);
    } else {
        NSLog(@"Nothing to draw in %@", self);
    }
}

@end
