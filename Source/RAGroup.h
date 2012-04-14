//
//  RAGroup.h
//  RASceneGraphMac
//
//  Created by Ross Anderson on 2/17/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RANode.h"

@interface RAGroup : RANode {
    NSMutableArray * _children;
}

@property (readonly) NSArray * children;

- (void)addChild:(RANode *)node;
- (void)removeChild:(RANode *)node;
- (BOOL)containsChild:(RANode *)node;

@end
