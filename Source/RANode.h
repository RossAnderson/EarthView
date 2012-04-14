//
//  RANode.h
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RABoundingSphere;
@class RANodeVisitor;


@interface RANode : NSObject {
    __weak RANode *     _parent;
    RABoundingSphere *  _bound;
}

@property (weak, atomic) RANode * parent;
@property (retain, atomic) RABoundingSphere * bound;

- (SEL)visitorSelector;
- (void)accept:(RANodeVisitor *)visitor;
- (void)traverse:(RANodeVisitor *)visitor;

- (void)dirtyBound;
- (void)calculateBound;

@end
