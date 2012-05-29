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
#import "RAManipulator.h"

@interface RASceneGraphController : UIViewController <GLKViewDelegate, UITextFieldDelegate>

@property (strong) EAGLContext * context;
@property (strong, nonatomic) IBOutlet GLKView * glView;
@property (strong, nonatomic) IBOutlet UITextField * flyToLocationField;

@property (strong, nonatomic) RANode * sceneRoot;
@property (strong, nonatomic) RACamera * camera;
@property (strong, nonatomic) RATilePager * pager;
@property (strong, nonatomic) RAManipulator * manipulator;

- (IBAction)flyToLocationFrom:(id)sender;

@end
