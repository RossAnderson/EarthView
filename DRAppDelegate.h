//
//  DRAppDelegate.h
//  EarthViewExample
//
//  Created by Ross Anderson on 4/14/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <UIKit/UIKit.h>

@class RASceneGraphController;

@interface DRAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) RASceneGraphController *viewController;

@end
