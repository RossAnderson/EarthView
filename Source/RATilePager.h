//
//  RATilePager.h
//  RASceneGraphTest
//
//  Created by Ross Anderson on 3/3/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <GLKit/GLKit.h>

#import "RATileDatabase.h"
#import "RAGeographicUtils.h"
#import "RAGroup.h"
#import "RAGeometry.h"
#import "RACamera.h"

extern NSString * RATilePagerContentChangedNotification;


@interface RATilePager : NSObject

@property (strong) RATileDatabase * imageryDatabase;
@property (strong) RATileDatabase * terrainDatabase;
@property (strong) EAGLContext * auxilliaryContext;

@property (readonly) NSSet * rootPages;
@property (strong) RACamera * camera;

- (void)setup;  // call once the databases are configured
- (void)requestUpdate;

@end
