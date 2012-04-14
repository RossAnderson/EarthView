//
//  RAPage.m
//  Jetsnapper
//
//  Created by Ross Anderson on 3/11/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAPage.h"

@implementation RAPage {
    RABoundingSphere *  _bound;
    RAPage *            _parent;
    
    RAGeometry *        _geometry;
    UIImage *           _image;

    NSURLConnection *   _connection;
    NSMutableData *     _imageData;
}

@synthesize tile, key;
@synthesize bound = _bound;
@synthesize geometry = _geometry;
@synthesize image = _image;
@synthesize parent = _parent, child1, child2, child3, child4;
@synthesize buildOp, needsUpdate, lastRequestTime;

- (RAPage *)initWithTileID:(TileID)t andParent:(RAPage *)parent;
{
    self = [super init];
    if (self) {
        tile = t;
        key = [NSString stringWithFormat:@"{%d,%d,%d}", t.z, t.x, t.y];
        _parent = parent;
    }
    return self;
}

- (void)dealloc {
    NSLog(@"Page %@ is deallocated.", key);
    [_connection cancel];
}

- (void)prune {
    [child1 prune]; child1 = nil;
    [child2 prune]; child2 = nil;
    [child3 prune]; child3 = nil;
    [child4 prune]; child4 = nil;
    
    _parent = nil;
}

- (void)setCenter:(GLKVector3)center andRadius:(double)radius {
    _bound = [RABoundingSphere new];
    _bound.center = center;
    _bound.radius = radius;
}

- (BOOL)isReady {
    return _geometry != nil; //&& _image != nil;
}

- (BOOL)isLeaf {
    return ( child1 == nil && child2 == nil && child3 == nil && child4 == nil );
}

- (void)setupGL {
    if ( self.needsUpdate == NO ) return;
    
    // create texture
    GLKTextureInfo * textureInfo = nil;
    if ( _image ) {
        NSError * err = nil;
        NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
        textureInfo = [GLKTextureLoader textureWithCGImage:[_image CGImage] options:options error:&err];
        if ( err ) NSLog(@"Error loading texture: %@", err);

        self.geometry.texture = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
    } /*else {
        NSLog(@"No image available for tile %@.", key);
    }*/
    
    self.needsUpdate = NO;
}

- (void)releaseGL {
    [self.geometry releaseGL];
    
    // release texture
    self.needsUpdate = YES;
}

@end
