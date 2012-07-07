//
//  RAShaderProgram.m
//  EarthViewExample
//
//  Created by Ross Anderson on 4/28/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAShaderProgram.h"

@interface RAShaderProgram (PrivateMethods)
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation RAShaderProgram {
    GLuint      _program;
    BOOL        _linked;
    GLuint      _vertShader;
    GLuint      _fragShader;
    
    NSInteger   _uniformsCount;
    GLint *     _uniforms;
}

- (id)init
{
    self = [super init];
    if ( self ) {
        _program = 0;
        _linked = NO;
        
        _uniformsCount = -1;
        _uniforms = NULL;
    }
    return self;
}

- (void)dealloc
{
    if ( _uniforms ) free( _uniforms );
}

- (BOOL)isReady
{
    return _linked;
}

- (BOOL)loadShader:(NSString *)resourceName
{
    NSString *  vertexShaderPath;
    NSString *  fragmentShaderPath;

    vertexShaderPath = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"vsh"];
    fragmentShaderPath = [[NSBundle mainBundle] pathForResource:resourceName ofType:@"fsh"];

    NSAssert( vertexShaderPath, @"vertex shader path must be valid" );
    NSAssert( fragmentShaderPath, @"fragment shader path must be valid" );

    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    if (![self compileShader:&_vertShader type:GL_VERTEX_SHADER file:vertexShaderPath]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    if (![self compileShader:&_fragShader type:GL_FRAGMENT_SHADER file:fragmentShaderPath]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, _vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, _fragShader);
    return YES;
}

- (void)bindAttribute:(NSString *)name toIdentifier:(NSUInteger)ident
{
    NSAssert( _program > 0, @"program must be loaded when calling bindAttribute:toIndex:");
    NSAssert( _linked == NO, @"program cannot be linked when calling bindAttribute:toIndex:");
    
    glBindAttribLocation( _program, ident, [name UTF8String] );
}

- (BOOL)link
{
    GLint status;
    glLinkProgram(_program);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(_program, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(_program, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    if (status == 0) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (_vertShader) {
            glDeleteShader(_vertShader);
            _vertShader = 0;
        }
        if (_fragShader) {
            glDeleteShader(_fragShader);
            _fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Release vertex and fragment shaders.
    if (_vertShader) {
        glDetachShader(_program, _vertShader);
        glDeleteShader(_vertShader);
        _vertShader = 0;
    }
    if (_fragShader) {
        glDetachShader(_program, _fragShader);
        glDeleteShader(_fragShader);
        _fragShader = 0;
    }
    
    [self validateProgram: _program];

    _linked = YES;
    return YES;
}

- (NSUInteger)indexForIdentifier:(NSUInteger)ident
{
    NSAssert( ident < _uniformsCount, @"identifier out of range" );
    return _uniforms[ident];
}

- (BOOL)bindUniform:(NSString *)name toIdentifier:(NSUInteger)ident
{
    NSAssert( _linked == YES, @"program must be linked before calling indexForUniform:");
    
    GLuint index = glGetUniformLocation( _program, [name UTF8String] );
    if ( index == -1 ) {
        NSLog(@"failed to find index for uniform: %@", name);
        return NO;
    }
    
    if ( (signed)ident >= _uniformsCount ) {
        GLint * uniforms = (GLint *)malloc( (ident + 1) * sizeof(GLint) );
        memset( uniforms, -1, (ident + 1) * sizeof(GLint) );
        if ( _uniforms ) {
            memcpy( uniforms, _uniforms, _uniformsCount * sizeof(GLint) );
            free( _uniforms );
        }
        
        _uniformsCount = ident + 1;
        _uniforms = uniforms;
    }
    
    _uniforms[ident] = index;
    return YES;
}

- (void)use
{
    glUseProgram(_program);
}

- (void)setUniform:(NSUInteger)ident toInt:(GLint)v
{
    NSAssert( ident < _uniformsCount, @"identifier out of range" );
    GLint location = _uniforms[ident];
    glUniform1i( location, v );
}

- (void)setUniform:(NSUInteger)ident toVector3:(GLKVector3)v
{
    NSAssert( ident < _uniformsCount, @"identifier out of range" );
    GLint location = _uniforms[ident];
    glUniform3fv( location, 1, v.v );
}

- (void)setUniform:(NSUInteger)ident toVector4:(GLKVector4)v
{
    NSAssert( ident < _uniformsCount, @"identifier out of range" );
    GLint location = _uniforms[ident];
    glUniform4fv( location, 1, v.v );
}

- (void)setUniform:(NSUInteger)ident toMatrix4:(GLKMatrix4)m
{
    NSAssert( ident < _uniformsCount, @"identifier out of range" );
    GLint location = _uniforms[ident];
    glUniformMatrix4fv( location, 1, 0, m.m );
}

- (void)tearDownGL
{
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
        _linked = NO;
    }
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

@end
