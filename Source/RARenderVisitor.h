//
//  RARenderVisitor.h
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/18/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <GLKit/GLKBaseEffect.h>

#import "RANodeVisitor.h"
#import "RACamera.h"


@interface RARenderVisitor : RANodeVisitor

@property (strong) RACamera * camera;

- (void)clear;
- (void)sortBackToFront;
- (void)renderWithEffect:(GLKBaseEffect *)effect;

@end
