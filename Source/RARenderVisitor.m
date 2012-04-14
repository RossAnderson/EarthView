//
//  RARenderVisitor.m
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/18/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RARenderVisitor.h"

#import <GLKit/GLKVector3.h>
#import <GLKit/GLKMatrix4.h>
#import <GLKit/GLKMathUtils.h>

#import "RABoundingSphere.h"


#pragma mark -

@interface RenderData : NSObject
@property (retain, atomic) RAGeometry * geometry;
@property (assign, atomic) GLKMatrix4 modelviewMatrix;
@property (assign, atomic) float distanceFromCamera;
@end

@implementation RenderData
@synthesize geometry = _geometry;
@synthesize modelviewMatrix = _modelviewMatrix;
@synthesize distanceFromCamera = _distanceFromCamera;
@end

#pragma mark -

@implementation RARenderVisitor {
    NSMutableArray * renderQueue;
}

@synthesize camera;

- (id)init
{
    self = [super init];
    if (self) {
        renderQueue = [NSMutableArray new];
        
        self.camera = [RACamera new];
        self.camera.projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), 1, 1, 100);
        self.camera.modelViewMatrix = GLKMatrix4Identity;
    }
    return self;
}

- (void)clear
{
    [renderQueue removeAllObjects];
}

- (void)sortBackToFront
{
    [renderQueue sortUsingComparator:(NSComparator)^(RenderData* obj1, RenderData* obj2) {
        return obj1.distanceFromCamera > obj2.distanceFromCamera;
    }];
}

- (void)renderWithEffect:(GLKBaseEffect *)effect
{
    [self sortBackToFront];
    
    effect.transform.projectionMatrix = self.camera.projectionMatrix;
    
    [renderQueue enumerateObjectsUsingBlock:^(RenderData * child, NSUInteger idx, BOOL *stop) {
        effect.transform.modelviewMatrix = child.modelviewMatrix;
        effect.colorMaterialEnabled = child.geometry.colorOffset > -1;
        
        if ( child.geometry.material ) {
            effect.material.ambientColor = child.geometry.material.ambientColor;
            effect.material.diffuseColor = child.geometry.material.diffuseColor;
            effect.material.specularColor = child.geometry.material.specularColor;
            effect.material.emissiveColor = child.geometry.material.emissiveColor;
            effect.material.shininess = child.geometry.material.shininess;
        } else {
            effect.material.ambientColor = (GLKVector4){ 0.2, 0.2, 0.2, 1.0};
            effect.material.diffuseColor = (GLKVector4){ 0.8, 0.8, 0.8, 1.0};
            effect.material.specularColor = (GLKVector4){ 0.0, 0.0, 0.0, 1.0};
            effect.material.emissiveColor = (GLKVector4){ 0.0, 0.0, 0.0, 1.0};
            effect.material.shininess = 0.0;
        }
        
        effect.useConstantColor = child.geometry.color.x > -1;
        effect.constantColor = child.geometry.color;
        
        if (child.geometry.texture != nil) {
            effect.texture2d0.envMode = GLKTextureEnvModeModulate;
            effect.texture2d0.target = GLKTextureTarget2D;
            effect.texture2d0.name = child.geometry.texture.name;
            effect.texture2d0.enabled = YES;
        } else {
            effect.texture2d0.name = child.geometry.texture.name;
            effect.texture2d0.enabled = NO;
        }
        
        [effect prepareToDraw];
        [child.geometry renderGL];
    }];
}

/*- (void)applyNode:(RANode *)node
{
    GLKMatrix4 modelProj = GLKMatrix4Multiply( [self currentTransform], self.projection );
    
    // project node center into viewport
    GLKVector3 pc = GLKMatrix4MultiplyVector3( modelProj, node.bound.center );
    
    //NSLog(@"Node %@, transform = %@", node, NSStringFromGLKMatrix4([self currentTransform]));
    
    // reject subgraphs behind camera
    //if ( pc.z > 0.0f ) return;
    
    [node traverse: self];
}*/

- (void)applyGeometry:(RAGeometry *)node
{
    GLKMatrix4 modelViewMatrix = GLKMatrix4Multiply( self.camera.modelViewMatrix, [self currentTransform] );
    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply( self.camera.projectionMatrix, modelViewMatrix );
    
    // project node center into viewport
    GLKVector3 pc = GLKMatrix4MultiplyAndProjectVector3( modelViewProjectionMatrix, node.bound.center );
    
    // !!! if it's outside the viewport, chuck it
        
    // insert into render queue
    RenderData * data = [RenderData new];
    data.geometry = node;
    data.modelviewMatrix = modelViewMatrix;
    data.distanceFromCamera = -pc.z;
    [renderQueue addObject: data];
}


@end
