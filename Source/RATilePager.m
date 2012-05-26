//
//  RATilePager.m
//  RASceneGraphTest
//
//  Created by Ross Anderson on 3/3/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RATilePager.h"

#import "RAGeographicUtils.h"
#import "RAPage.h"
#import "RAPageNode.h"
#import "RAImageSampler.h"

#import <Foundation/Foundation.h>
#import <GLKit/GLKVector2.h>


NSString * RATilePagerContentChangedNotification = @"RATilePagerContentChangedNotification";


@interface RAPageDelta : NSObject
@property (strong) NSSet * pagesToAdd;
@property (strong) NSSet * pagesToRemove;
@end

@implementation RAPageDelta
@synthesize pagesToAdd, pagesToRemove;
@end


@implementation RATilePager {
    RATextureWrapper *      _defaultTexture;
        
    NSOperationQueue *      _updateQueue;
    NSOperationQueue *      _graphicsQueue;
    
    BOOL                    _updateAgain;
}

@synthesize imageryDatabase, terrainDatabase, auxilliaryContext, rootPages, camera;

- (id)init
{
    self = [super init];
    if (self) {
        _updateQueue = [[NSOperationQueue alloc] init];
        [_updateQueue setName:@"org.dancingrobots.traversequeue"];

        _graphicsQueue = [[NSOperationQueue alloc] init];
        [_graphicsQueue setName:@"org.dancingrobots.graphicsqueue"];
        [_graphicsQueue setMaxConcurrentOperationCount: 1];
    }
    return self;
}

- (void)dealloc {
    [_updateQueue cancelAllOperations];
    [_updateQueue waitUntilAllOperationsAreFinished];

    [_graphicsQueue cancelAllOperations];
    [_graphicsQueue waitUntilAllOperationsAreFinished];
}

- (void)setup {
    // build root pages
    NSMutableSet * pages = [NSMutableSet set];
    
    int basezoom = self.imageryDatabase.minzoom;
    if ( basezoom < 2 ) basezoom = 2;
    int tilecount = 1 << basezoom;  // fast way to calc 2 ^ basezoom
    
    TileID t;
    t.z = basezoom;
    for( t.y = 0; t.y < tilecount; t.y++ ) {
        for( t.x = 0; t.x < tilecount; t.x++ ) {
            RAPage * page = [self makeLeafPageForTile:t withParent:nil];
            [pages addObject:page];
        }
    }
    
    rootPages = [NSSet setWithSet:pages];
    
    // load the default "grid" texture
    if ( _defaultTexture == nil ) {
        [EAGLContext setCurrentContext: self.auxilliaryContext];

        UIImage * gridImage = [UIImage imageNamed:@"grid256"];
        _defaultTexture = [[RATextureWrapper alloc] initWithImage:gridImage];
        
        glFlush();
        [EAGLContext setCurrentContext: nil];
    }
}

- (void)contentUpdated {
    [[NSNotificationCenter defaultCenter] postNotificationName:RATilePagerContentChangedNotification object:self];
}

- (RAGeometry *)createGeometryForTile:(TileID)tile
{
    // create geometry node
    RAGeometry * geom = [RAGeometry new];
    geom.positionOffset = (0*sizeof(GLfloat));
    geom.normalOffset = (3*sizeof(GLfloat));
    geom.textureOffset = (6*sizeof(GLfloat));    
    return geom;
}

- (void)setupGeometry:(RAGeometry *)geom forPage:(RAPage *)page withTextureFromPage:(RAPage *)texPage withHeightFromPage:(RAPage *)hgtPage {
    
    RAPolarCoordinate lowerLeft = [self.imageryDatabase tileLatLonOrigin:page.tile];
    RAPolarCoordinate upperRight = [self.imageryDatabase tileLatLonOrigin:TileOppositeCorner(page.tile)];
    
    // use more precision for large tiles
    const int gridSize = 32;
    const int border = 1;
    const int totalSize = gridSize + border + border;
    const int indexSize = totalSize - 1;
    const double borderInterval = 1e-5;
    
    double latInterval = ( upperRight.latitude - lowerLeft.latitude ) / (gridSize-1);
    double lonInterval = ( upperRight.longitude - lowerLeft.longitude ) / (gridSize-1);
    
    // fits in index value?
    NSAssert( gridSize*gridSize < 65535, @"too many grid elements" );

    const NSUInteger vertexElements = 8;
    size_t vertexDataSize = vertexElements*sizeof(GLfloat) * totalSize*totalSize;
    GLfloat * vertexData = (GLfloat *)calloc(totalSize*totalSize, vertexElements*sizeof(GLfloat));
    
    const NSUInteger indexElements = 6;
    size_t indexDataSize = indexElements*sizeof(GLushort) * indexSize*indexSize;
    GLushort * indexData = (GLushort *)calloc(indexSize*indexSize, indexElements*sizeof(GLushort));
    
    RAImageSampler * sampler = [[RAImageSampler alloc] initWithImage:hgtPage.terrain];
        
    size_t vertexDataPos = 0;
    size_t indexDataPos = 0;
    BOOL isPartOfSkirt = NO;

    // calculate mesh vertices and indices
    for( int gy = 0; gy < totalSize; gy++ ) {
        for( int gx = 0; gx < totalSize; gx++ ) {
            RAPolarCoordinate gpos;

            isPartOfSkirt = ( gx < border || gy < border || gx > gridSize || gy > gridSize );
            
            if ( gx < border )
                gpos.longitude = lowerLeft.longitude - borderInterval;
            else if ( gx > gridSize )
                gpos.longitude = upperRight.longitude + borderInterval;
            else
                gpos.longitude = lowerLeft.longitude + (gx-border)*lonInterval;
            
            if ( gy < border )
                gpos.latitude = lowerLeft.latitude - borderInterval;
            else if ( gy > gridSize )
                gpos.latitude = upperRight.latitude + borderInterval;
            else
                gpos.latitude = lowerLeft.latitude + (gy-border)*latInterval;

            gpos.height = lowerLeft.height;

            GLKVector3 ecef = ConvertPolarToEcef(gpos);
            GLKVector2 tex = [self.imageryDatabase textureCoordsForLatLon:gpos inTile:texPage.tile];
            
            GLKVector3 normal = GLKVector3Normalize(ecef);
            
            // extrude as appropriate
            float extrude = 0.0f;
            
            if ( isPartOfSkirt ) {
                extrude = -0.0001f;    // skirt
            } else if ( sampler ) {
                GLKVector2 hgtPixel = [self.terrainDatabase textureCoordsForLatLon:gpos inTile:hgtPage.tile];

                CGPoint p = CGPointMake((sampler.width-1) * hgtPixel.x, 
                                        (sampler.height-1) * hgtPixel.y );
                extrude = 0.015f * [sampler grayByInterpolatingPixels:p];
            }
            
            ecef = GLKVector3Add( ecef, GLKVector3MultiplyScalar(normal, extrude) );
            
            // fill vertex data
            vertexData[vertexDataPos+0] = ecef.x;
            vertexData[vertexDataPos+1] = ecef.y;
            vertexData[vertexDataPos+2] = ecef.z;
            
            vertexData[vertexDataPos+3] = normal.x;
            vertexData[vertexDataPos+4] = normal.y;
            vertexData[vertexDataPos+5] = normal.z;

            vertexData[vertexDataPos+6] = tex.x;
            vertexData[vertexDataPos+7] = tex.y;
            
            if ( gx < indexSize && gy < indexSize ) {
                GLushort baseElement = gy*totalSize + gx;
                indexData[indexDataPos+0] = baseElement;
                indexData[indexDataPos+1] = baseElement + 1;
                indexData[indexDataPos+2] = baseElement + totalSize;
                
                indexData[indexDataPos+3] = baseElement + 1;
                indexData[indexDataPos+4] = baseElement + totalSize + 1;
                indexData[indexDataPos+5] = baseElement + totalSize;
                
                indexDataPos += indexElements;
            }
            
            vertexDataPos += vertexElements;
        }
    }

    NSAssert( vertexDataPos == vertexElements*totalSize*totalSize, @"didn't fill vertex array" );
    NSAssert( indexDataPos == indexElements*indexSize*indexSize, @"didn't fill index array" );
    
    // calculate normals
    const int rowOffset = vertexElements * totalSize;
    GLKVector3 ecef0, ecef1;
    int offset = 0;
    for( unsigned int gy = border; gy < totalSize-border; gy++ ) {
        for( unsigned int gx = border; gx < totalSize-border; gx++ ) {
            GLKVector3 vectorLeft, vectorRight;
            
            // index of center element
            vertexDataPos = ( gy * rowOffset ) + ( gx * vertexElements );
            
            // eastward component
            offset = ( gx > border ) ? -vertexElements : 0;
            ecef0 = GLKVector3Make( vertexData[vertexDataPos+offset+0], vertexData[vertexDataPos+offset+1], vertexData[vertexDataPos+offset+2] );
            offset = ( gx < gridSize ) ? vertexElements : 0;
            ecef1 = GLKVector3Make( vertexData[vertexDataPos+offset+0], vertexData[vertexDataPos+offset+1], vertexData[vertexDataPos+offset+2] );
            vectorLeft = GLKVector3Subtract(ecef1, ecef0);
            
            // northward component
            offset = ( gy > border ) ? -rowOffset : 0;
            ecef0 = GLKVector3Make( vertexData[vertexDataPos+offset+0], vertexData[vertexDataPos+offset+1], vertexData[vertexDataPos+offset+2] );
            offset = ( gy < gridSize ) ? rowOffset : 0;
            ecef1 = GLKVector3Make( vertexData[vertexDataPos+offset+0], vertexData[vertexDataPos+offset+1], vertexData[vertexDataPos+offset+2] );
            vectorRight = GLKVector3Subtract(ecef1, ecef0);

            GLKVector3 normal = GLKVector3CrossProduct( vectorLeft, vectorRight );
            normal = GLKVector3Normalize(normal);
            
            vertexData[vertexDataPos+3] = normal.x;
            vertexData[vertexDataPos+4] = normal.y;
            vertexData[vertexDataPos+5] = normal.z;
        }
    }
    
    [geom setObjectData:vertexData withSize:vertexDataSize withStride:(vertexElements*sizeof(GLfloat))];
    [geom setIndexData:indexData withSize:indexDataSize withStride:sizeof(GLushort)];
    
    free( vertexData );
    free( indexData );
}

- (void)updatePageIfNeeded:(RAPage *)page {
    NSAssert( page != nil, @"the requested page must be valid");
    
    // build geometry if needed
    if ( page.geometryState == NotLoaded ) {
        NSAssert( page.geometry == nil, @"geometry must be nil if unloaded" );
        
        page.geometry = [self createGeometryForTile:page.tile];
        page.geometryState = Loading;
    }
    
    // update if needed
    if ( page.geometryState == NeedsUpdate || page.geometryState == Loading ) {
        NSAssert( page.geometry != nil, @"geometry must be not nil if updating" );
        
        // find an ancestor tile with a valid texture
        RAPage * imgAncestor = page;
        while( imgAncestor ) {
            // texture valid? use this page
            if ( imgAncestor.imagery ) break;
            
            imgAncestor = imgAncestor.parent;
        }
    
        RAPage * hgtAncestor = page;
        while( hgtAncestor ) {
            // terrain valid? use this page
            if ( hgtAncestor.terrain ) break;
            
            hgtAncestor = hgtAncestor.parent;
        }
                    
        if ( imgAncestor ) {
            // recycle texture with appropriate tex coords
            [self setupGeometry:page.geometry forPage:page withTextureFromPage:imgAncestor withHeightFromPage:hgtAncestor];
            page.geometry.texture0 = imgAncestor.imagery;
        } else {
            // show grid if necessary
            [self setupGeometry:page.geometry forPage:page withTextureFromPage:page withHeightFromPage:hgtAncestor];
            page.geometry.texture0 = _defaultTexture;
        }
            
        page.geometryState = Complete;
        [self contentUpdated];
    }
}

- (void)requestPage:(RAPage *)page {
    NSAssert( page != nil, @"the requested page must be valid");
    //const NSUInteger kMaxQueueDepth = 8;
    const NSTimeInterval kTimeoutInterval = 5.0f;
    
    __block RATilePager * mySelf = self;
                                    
    // request the tile image if needed
    if ( page.imageryState == NotLoaded ) {
        NSURL * url = [self.imageryDatabase urlForTile: page.tile];
        
        if ( url == nil ) {
            page.imageryState = Failed;
        } else {
            page.imageryState = Loading;
            
            // capture ivar locally to avoid retain cycle
            NSOperationQueue * graphicsQueue = _graphicsQueue;
            
            [_updateQueue addOperationWithBlock:^{
                NSURLRequest * request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:kTimeoutInterval];
                NSURLResponse * response = nil;
                NSError * error = nil;
                
                NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                
                if ( error ) {
                    // attempt to reload if the connection timed out
                    if ( [[error domain] isEqualToString:NSURLErrorDomain] && [error code] == NSURLErrorTimedOut ) {
                        page.imageryState = NotLoaded;
                        return;
                    }
                    
                    NSLog(@"URL loading error): %@", error);
                    page.imageryState = Failed;
                    return;
                } else if ( [[response MIMEType] isEqualToString:@"text/html"] ) {
                    NSString * content = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                    NSLog(@"Request Returned: %@", content);
                    page.imageryState = Failed;
                    return;
                }
                
                [graphicsQueue addOperationWithBlock:^{
                    [EAGLContext setCurrentContext: self.auxilliaryContext];
                    
                    UIImage * image = [UIImage imageWithData:data];
                    if ( image == nil ) {
                        NSLog(@"Bad image for URL: %@", url);
                        page.imageryState = Failed;
                        return;
                    }
                    
                    // create texture
                    RATextureWrapper * texture = [[RATextureWrapper alloc] initWithImage:image];
                    page.imagery = texture;
                    page.imageryState = Complete;
                    
                    // mark the geometry to get refreshed
                    page.geometryState = NeedsUpdate;
                    [mySelf contentUpdated];

                    glFlush();
                    [EAGLContext setCurrentContext: nil];
                }];
            }];
        }
    }
    
    // request the terrain if needed
    if ( page.terrainState == NotLoaded ) {
        NSURL * url = [self.terrainDatabase urlForTile: page.tile];
        
        if ( url == nil ) {
            page.terrainState = Failed;
        } else {
            page.terrainState = Loading;

            // capture ivar locally to avoid retain cycle
            NSOperationQueue * updateQueue = _updateQueue;

            [_updateQueue addOperationWithBlock:^{
                NSURLRequest * request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:kTimeoutInterval];

                NSURLResponse * response = nil;
                NSError * error = nil;
                
                NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                
                if ( error ) {
                    // attempt to reload if the connection timed out
                    if ( [[error domain] isEqualToString:NSURLErrorDomain] && [error code] == NSURLErrorTimedOut ) {
                        page.terrainState = NotLoaded;
                        return;
                    }
                    
                    NSLog(@"URL Error loading (%@): %@", url, error);
                    page.terrainState = Failed;
                    return;
                } else if ( [[response MIMEType] isEqualToString:@"text/html"] ) {
                    NSString * content = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                    NSLog(@"Request Returned: %@", content);
                    page.terrainState = Failed;
                    return;
                }
                
                [updateQueue addOperationWithBlock:^{
                    UIImage * image = [UIImage imageWithData:data];
                    if ( image == nil ) {
                        NSLog(@"Bad terrain for URL: %@", url);
                        page.terrainState = Failed;
                        return;
                    }

                    page.terrain = image;
                    page.terrainState = Complete;

                    // mark the geometry to get refreshed
                    page.geometryState = NeedsUpdate;
                    [mySelf contentUpdated];
                }];
            }];
        }
    }
}

#pragma mark Page Traversal Methods

- (RAPage *)makeLeafPageForTile:(TileID)t withParent:(RAPage *)parent {
    RAPage * page = [[RAPage alloc] initWithTileID:t andParent:parent];
    
    // calculate tile center and radius
    GLKVector3 center = ConvertPolarToEcef( [self.imageryDatabase tileLatLonCenter:page.tile] );
    GLKVector3 corner = ConvertPolarToEcef( [self.imageryDatabase tileLatLonOrigin:page.tile] );
    [page setCenter:center andRadius:GLKVector3Distance(center, corner)];
    
    // any time we add new pages we should re-traverse to give them an oppurtunity to load
    _updateAgain = YES;
    
    return page;
}

- (void)preparePageForTraversal:(RAPage *)page {
    NSAssert( page != nil, @"the prepared page must be valid");
    
    // create child pages
    if ( page.child1 == nil ) page.child1 = [self makeLeafPageForTile:(TileID){ 2*page.tile.x+0, 2*page.tile.y+0, page.tile.z+1 } withParent:page];
    if ( page.child2 == nil ) page.child2 = [self makeLeafPageForTile:(TileID){ 2*page.tile.x+1, 2*page.tile.y+0, page.tile.z+1 } withParent:page];
    if ( page.child3 == nil ) page.child3 = [self makeLeafPageForTile:(TileID){ 2*page.tile.x+0, 2*page.tile.y+1, page.tile.z+1 } withParent:page];
    if ( page.child4 == nil ) page.child4 = [self makeLeafPageForTile:(TileID){ 2*page.tile.x+1, 2*page.tile.y+1, page.tile.z+1 } withParent:page];
}

- (void)traversePage:(RAPage *)page withTimestamp:(NSTimeInterval)timestamp {
    NSAssert( page != nil, @"the traversed page must be valid");
    
    [self updatePageIfNeeded: page];
    [self requestPage: page];
    
    float texelError = [page calculateScreenSpaceErrorWithCamera:self.camera];
    
    if ( page.tile.z >= self.imageryDatabase.maxzoom )
        texelError = 0.0f; // force display at maximum zoom level
    
    // should we traverse to load more detail?
    if ( texelError > 5.0f ) {
        // traverse children
        [self preparePageForTraversal:page];
        
        [self traversePage:page.child1 withTimestamp:timestamp];
        [self traversePage:page.child2 withTimestamp:timestamp];
        [self traversePage:page.child3 withTimestamp:timestamp];
        [self traversePage:page.child4 withTimestamp:timestamp];
    } else {
        // update the page's timestamp
        page.lastRequestedTimestamp = timestamp;
        
        // prune children
        // !!! replace this with another method that doesn't remove children immediately
        page.child1 = page.child2 = page.child3 = page.child4 = nil;
    }
}

- (void)requestUpdate {
    // we only want one traversal running at a time, so if busy, schedule it to run again
    if ( _updateQueue.operationCount > 0 ) {
        _updateAgain = YES;
        return;
    }

    [self update];
}

- (void)update {
    
    NSTimeInterval currentTime = [NSDate timeIntervalSinceReferenceDate];

    // capture self to avoid a retain cycle
    __block RATilePager *mySelf = self;
    
    [_updateQueue addOperationWithBlock:^{
        // traverse pages gathering ones that are active and should be displayed
        [mySelf->rootPages enumerateObjectsUsingBlock:^(RAPage *page, BOOL *stop) {
            [mySelf traversePage:page withTimestamp:currentTime];
        }];
        
        // update again if changes were made during traverse
        if ( mySelf->_updateAgain ) {
            mySelf->_updateAgain = NO;
            [mySelf update];
        }
    }];
}

@end
