//
//  RATransform.m
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RATransform.h"

#import "RABoundingSphere.h"


@implementation RATransform

@synthesize transform;

- (SEL)visitorSelector
{
    return @selector(applyTransform:);
}

- (id)init
{
    self = [super init];
    if (self) {
        self.transform = GLKMatrix4Identity;
    }
    return self;
}

- (void)calculateBound
{
    RABoundingSphere * newBound = [RABoundingSphere new];
    [_children enumerateObjectsUsingBlock:^(RANode * child, NSUInteger idx, BOOL *stop) {
        [newBound expandByBoundingSphere: [[child bound] transform: self.transform]];
    }];
    _bound = newBound;
}

@end
