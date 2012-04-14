//
//  RANode.m
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RANode.h"
#import "RANodeVisitor.h"

@implementation RANode

@synthesize parent = _parent;
@synthesize bound = _bound;

- (SEL)visitorSelector
{
    return @selector(applyNode:);
}

- (void)accept:(RANodeVisitor *)visitor
{
    [visitor pushOnPath: self];
    
    // call the appropriate apply*: method based on object type
    SEL applySelector = [self visitorSelector];
    NSAssert( [visitor respondsToSelector:applySelector], @"%@ does not respond to %@", visitor, NSStringFromSelector(applySelector) );
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [visitor performSelector:applySelector withObject:self];
#pragma clang diagnostic pop
    
    [visitor popFromPath];
}

- (void)traverse:(RANodeVisitor *)visitor
{
}

- (RABoundingSphere *)bound
{
    if ( _bound == nil ) [self calculateBound];
    return _bound;
}

- (void)setBound:(RABoundingSphere *)newBound
{
    _bound = newBound;
    [_parent calculateBound];
}

- (void)dirtyBound
{
    _bound = nil;
    [_parent dirtyBound];
}

- (void)calculateBound
{
    // overload in subclasses, but do not set bound property
}

@end
