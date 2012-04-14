//
//  RATransform.h
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAGroup.h"

#include <GLKit/GLKMathTypes.h>
#include <GLKit/GLKMatrix4.h>


@interface RATransform : RAGroup

@property (assign, atomic) GLKMatrix4 transform;

@end
