//
//  RASceneGraphController.h
//  RASceneGraphTest
//
//  Created by Ross Anderson on 2/19/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <GLKit/GLKit.h>

#import "RANode.h"
#import "RATileDatabase.h"

@interface RASceneGraphController : GLKViewController <UISplitViewControllerDelegate>

@property (readonly, nonatomic) RANode * sceneRoot;
@property (readonly, nonatomic) RATileDatabase * database;

@end
