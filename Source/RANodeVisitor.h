//
//  RANodeVisitor.h
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKMatrixStack.h>

#import "RANode.h"
#import "RAGroup.h"
#import "RATransform.h"
#import "RAGeometry.h"


@interface RANodeVisitor : NSObject {
    NSMutableArray *    path;
    GLKMatrixStackRef   stack;
}

- (void)pushOnPath:(RANode *)node;
- (void)popFromPath;

- (GLKMatrix4)currentTransform;

- (void)applyNode:(RANode *)node;
- (void)applyGroup:(RAGroup *)node;
- (void)applyTransform:(RATransform *)node;
- (void)applyGeometry:(RAGeometry *)node;

@end
