//
//  RABoundingSphere.h
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GLKit/GLKMathTypes.h>

@interface RABoundingSphere : NSObject {
    GLKVector3  center;
    float       radius;
}

@property (assign, atomic) GLKVector3 center;
@property (assign, atomic) float radius;

@property (readonly) float radius2;
@property (readonly) BOOL valid;


- (void)expandByPoint:(GLKVector3)point;
- (void)expandByBoundingSphere:(RABoundingSphere *)bound;

- (BOOL)contains:(GLKVector3)point;
- (BOOL)intersectsBoundingSphere:(RABoundingSphere *)bound;

- (RABoundingSphere *)transform:(GLKMatrix4)m;

@end
