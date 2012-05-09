//
//  RAWorldTour.h
//  EarthViewExample
//
//  Created by Ross Anderson on 5/6/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RAManipulator.h"

@interface RAWorldTour : NSObject

@property (strong) RAManipulator * manipulator;

- (void)start:(id)sender;
- (void)stop:(id)sender;

- (void)startOrStop:(id)sender;

@end
