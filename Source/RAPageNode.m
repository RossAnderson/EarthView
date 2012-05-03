//
//  RAPageNode.m
//  EarthViewExample
//
//  Created by Ross Anderson on 5/3/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAPageNode.h"

@implementation RAPageNode

@synthesize page = _page;


- (SEL)visitorSelector {
    return @selector(applyPageNode:);
}

- (void)calculateBound {
    _bound = self.page.bound;
}

- (RAPage *)page {
    return _page;
}

- (void)setPage:(RAPage *)page {
    _page = page;
    [self dirtyBound];
}

@end
