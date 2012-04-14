//
//  RANodeVisitor.m
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RANodeVisitor.h"

@implementation RANodeVisitor

- (id)init
{
    self = [super init];
    if ( self ) {
        stack = GLKMatrixStackCreate( kCFAllocatorDefault );
        path = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    CFRelease(stack);
}

- (void)pushOnPath:(RANode *)node
{
    [path addObject: node];
    if ( [node isKindOfClass:[RATransform class]] ) {
        RATransform * transformNode = (RATransform *)node;
        
        GLKMatrixStackPush(stack);
        GLKMatrixStackMultiplyMatrix4(stack, transformNode.transform);
    }
}

- (void)popFromPath
{
    RANode * node = [path lastObject];
    [path removeLastObject];
    if ( [node isKindOfClass:[RATransform class]] ) {
        GLKMatrixStackPop(stack);
    }
}

- (GLKMatrix4)currentTransform
{
    return GLKMatrixStackGetMatrix4(stack);
}

- (void)applyNode:(RANode *)node
{
    [node traverse: self];
}

- (void)applyGroup:(RAGroup *)node
{
    [self applyNode: node];
}

- (void)applyTransform:(RATransform *)node
{
    [self applyGroup: node];
}

- (void)applyGeometry:(RAGeometry *)node
{
    [self applyNode: node];
}

@end
