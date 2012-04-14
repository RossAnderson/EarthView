//
//  RAGroup.m
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAGroup.h"

#import "RABoundingSphere.h"


@implementation RAGroup

@synthesize children=_children;

- (id)init {
    self = [super init];
    if ( self ) {
        _children = [NSMutableArray array];
    }
    return self;
}

- (SEL)visitorSelector {
    return @selector(applyGroup:);
}

- (void)traverse:(RANodeVisitor *)visitor {
    [_children makeObjectsPerformSelector:@selector(accept:) withObject:visitor];
}

- (void)calculateBound {
    RABoundingSphere * newBound = [RABoundingSphere new];
    [_children enumerateObjectsUsingBlock:^(RANode * child, NSUInteger idx, BOOL *stop) {
        [newBound expandByBoundingSphere: [child bound]];
    }];
    _bound = newBound;
}

- (void)addChild:(RANode *)node {
    if ( !node ) return;
    
    [_children addObject: node];
    node.parent = self;
    [self dirtyBound];
}

- (void)removeChild:(RANode *)node {
    if ( !node ) return;
    
    [_children removeObject: node];
    node.parent = nil;
    [self dirtyBound];
}

- (BOOL)containsChild:(RANode *)node {
    if ( !node ) return NO;
    
    return [_children containsObject: node];
}

@end
