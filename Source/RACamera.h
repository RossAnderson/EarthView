//
//  RACamera.h
//  Jetsnapper
//
//  Created by Ross Anderson on 3/18/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKit.h>


@interface RACamera : NSObject

@property (assign) GLKMatrix4 modelViewMatrix;
@property (assign) GLKMatrix4 projectionMatrix;
@property (assign) GLKMatrix4 modelViewProjectionMatrix;
@property (assign) CGRect viewport;

@end
