//
//  RATilePager.h
//  RASceneGraphTest
//
//  Created by Ross Anderson on 3/3/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GLKit/GLKMathTypes.h>

#import "RATileDatabase.h"
#import "RAGeographicUtils.h"
#import "RAGroup.h"
#import "RAGeometry.h"
#import "RACamera.h"


@interface RATilePager : NSObject

@property (strong) RATileDatabase * database;

@property (readonly) RAGroup * nodes;
@property (readonly) NSSet * rootPages;
@property (strong) RACamera * camera;

- (void)updateSceneGraph;

@end
