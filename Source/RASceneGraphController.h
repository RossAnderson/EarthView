//
//  RASceneGraphController.h
//  RASceneGraphTest
//
//  Created by Ross Anderson on 2/19/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <GLKit/GLKit.h>

#import "RANode.h"
#import "RACamera.h"
#import "RATilePager.h"

@interface RASceneGraphController : GLKViewController

@property (readonly, nonatomic) RANode * sceneRoot;
@property (readonly, nonatomic) RACamera * camera;
@property (readonly, nonatomic) RATilePager * pager;

@end
