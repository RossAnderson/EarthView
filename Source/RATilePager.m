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


@interface RAPageDelta : NSObject
@property (strong) NSSet * pagesToAdd;
@property (strong) NSSet * pagesToRemove;
@end

@implementation RAPageDelta
@synthesize pagesToAdd, pagesToRemove;
@end


@implementation RATilePager {
    RATextureWrapper *      _defaultTexture;
    
    NSOperationQueue *      _loadQueue;
    NSOperationQueue *      _traverseQueue;
    NSOperationQueue *      _graphicsQueue;
    __weak NSOperation *    _traverseOp;
}

@synthesize imageryDatabase, terrainDatabase, auxilliaryContext, rootNode, rootPages, camera;

- (id)init
{
    self = [super init];
    if (self) {
        // enlarge shared cache
        NSURLCache * cache = [NSURLCache sharedURLCache];
        [cache setMemoryCapacity: 5*1000*1000];
        [cache setDiskCapacity: 250*1000*1000];
        
        _loadQueue = [[NSOperationQueue alloc] init];
        [_loadQueue setName:@"Loading Queue"];

        _traverseQueue = [[NSOperationQueue alloc] init];
        [_traverseQueue setName:@"Traverse Queue"];

        _graphicsQueue = [[NSOperationQueue alloc] init];
        [_graphicsQueue setName:@"OpenGL ES Serial Queue"];
        [_graphicsQueue setMaxConcurrentOperationCount: 1];
    }
    return self;
}

- (void)dealloc {
    [_loadQueue cancelAllOperations];
    [_loadQueue waitUntilAllOperationsAreFinished];
    
    [_traverseQueue cancelAllOperations];
    [_traverseQueue waitUntilAllOperationsAreFinished];

    [_graphicsQueue cancelAllOperations];
    [_graphicsQueue waitUntilAllOperationsAreFinished];
}

- (void)setup {
    // build root pages
    NSMutableSet * pages = [NSMutableSet set];
    RAGroup * root = [RAGroup new];
    
    int basezoom = self.imageryDatabase.minzoom;
    if ( basezoom < 2 ) basezoom = 2;
    int tilecount = 1 << basezoom;  // fast way to calc 2 ^ basezoom
    
    TileID t;
    t.z = basezoom;
    for( t.y = 0; t.y < tilecount; t.y++ ) {
        for( t.x = 0; t.x < tilecount; t.x++ ) {
            RAPage * page = [self makeLeafPageForTile:t withParent:nil];
            RAPageNode * node = [RAPageNode new];
            node.page = page;
            
            [pages addObject:page];
            [root addChild:node];
        }
    }
    
    rootPages = [NSSet setWithSet:pages];
    rootNode = root;
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
    int gridSize = 64;
    
    RAPolarCoordinate lowerLeft = [self.imageryDatabase tileLatLonOrigin:page.tile];
    RAPolarCoordinate upperRight = [self.imageryDatabase tileLatLonOrigin:TileOppositeCorner(page.tile)];
    
    // use more precision for large tiles
    if ( upperRight.latitude - lowerLeft.latitude > 10. ||
        upperRight.longitude - lowerLeft.longitude > 10. ) gridSize = 32;
    
    double latInterval = ( upperRight.latitude - lowerLeft.latitude ) / (gridSize-1);
    double lonInterval = ( upperRight.longitude - lowerLeft.longitude ) / (gridSize-1);
    
    // fits in index value?
    NSAssert( gridSize*gridSize < 65535, @"too many grid elements" );

    size_t vertexDataSize = 8*sizeof(GLfloat) * gridSize*gridSize;
    GLfloat * vertexData = (GLfloat *)calloc(gridSize*gridSize, 8*sizeof(GLfloat));
    
    size_t indexDataSize = 6*sizeof(GLushort) * (gridSize-1)*(gridSize-1);
    GLushort * indexData = (GLushort *)calloc((gridSize-1)*(gridSize-1), 6*sizeof(GLushort));
    
    RAImageSampler * sampler = [[RAImageSampler alloc] initWithImage:hgtPage.terrain];
        
    size_t vertexDataPos = 0;
    size_t indexDataPos = 0;

    // calculate mesh vertices and indices
    for( unsigned int gy = 0; gy < gridSize; gy++ ) {
        for( unsigned int gx = 0; gx < gridSize; gx++ ) {
            RAPolarCoordinate gpos;
            gpos.latitude = lowerLeft.latitude + gy*latInterval;
            gpos.longitude = lowerLeft.longitude + gx*lonInterval;
            gpos.height = lowerLeft.height;

            GLKVector3 ecef = ConvertPolarToEcef(gpos);
            GLKVector2 tex = [self.imageryDatabase textureCoordsForLatLon:gpos inTile:texPage.tile];
            
            if ( sampler ) {
                GLKVector2 hgtPixel = [self.imageryDatabase textureCoordsForLatLon:gpos inTile:hgtPage.tile];
                hgtPixel.x = (hgtPage.terrain.size.width-1) * hgtPixel.x;
                hgtPixel.y = (hgtPage.terrain.size.height-1) * hgtPixel.y;

                CGPoint p = CGPointMake(hgtPixel.x, hgtPixel.y);
                UIColor * color = [sampler colorByInterpolatingPixels:p];
                if ( color == nil ) NSLog(@"Failed to sample: %f %f", hgtPixel.x, hgtPixel.y);

                
                GLKVector3 normal = GLKVector3Normalize(ecef);
                CGFloat r, g, b, a;
                if ( [color getRed:&r green:&g blue:&b alpha:&a] ) {
                    // extrude by height
                    float height = 0.015f * ( r + g + b ) / 3.0f;
                    ecef = GLKVector3Add( ecef, GLKVector3MultiplyScalar(normal, height) );
                }
            }
            
            // fill vertex data
            vertexData[vertexDataPos+0] = ecef.x;
            vertexData[vertexDataPos+1] = ecef.y;
            vertexData[vertexDataPos+2] = ecef.z;
            
            vertexData[vertexDataPos+6] = tex.x;
            vertexData[vertexDataPos+7] = tex.y;
            
            if ( gx < gridSize-1 && gy < gridSize-1 ) {
                GLushort baseElement = gy*gridSize + gx;
                indexData[indexDataPos+0] = baseElement;
                indexData[indexDataPos+1] = baseElement + 1;
                indexData[indexDataPos+2] = baseElement + gridSize;
                
                indexData[indexDataPos+3] = baseElement + 1;
                indexData[indexDataPos+4] = baseElement + gridSize + 1;
                indexData[indexDataPos+5] = baseElement + gridSize;
                
                indexDataPos += 6;
            }
            
            vertexDataPos += 8;
        }
    }

    NSAssert( vertexDataPos == 8*gridSize*gridSize, @"didn't fill vertex array" );
    NSAssert( indexDataPos == 6*(gridSize-1)*(gridSize-1), @"didn't fill index array" );

    vertexDataPos = 0;
    
    // calculate normals
    for( unsigned int gy = 0; gy < gridSize; gy++ ) {
        for( unsigned int gx = 0; gx < gridSize; gx++ ) {
            GLKVector3 vectorLeft, vectorRight;
            
            GLKVector3 ecef0 = GLKVector3Make( vertexData[vertexDataPos+0], vertexData[vertexDataPos+1], vertexData[vertexDataPos+2] );
            int rowOffset = 8 * gridSize;
            
            if ( gx < gridSize-1 ) {
                GLKVector3 ecef1 = GLKVector3Make( vertexData[vertexDataPos+0+8], vertexData[vertexDataPos+1+8], vertexData[vertexDataPos+2+8] );
                vectorLeft = GLKVector3Subtract(ecef1, ecef0);
            } else {
                GLKVector3 ecef1 = GLKVector3Make( vertexData[vertexDataPos+0-8], vertexData[vertexDataPos+1-8], vertexData[vertexDataPos+2-8] );
                vectorLeft = GLKVector3Subtract(ecef0, ecef1);
            }

            if ( gy < gridSize-1 ) {
                GLKVector3 ecef1 = GLKVector3Make( vertexData[vertexDataPos+0+rowOffset], vertexData[vertexDataPos+1+rowOffset], vertexData[vertexDataPos+2+rowOffset] );
                vectorRight = GLKVector3Subtract(ecef1, ecef0);
            } else {
                GLKVector3 ecef1 = GLKVector3Make( vertexData[vertexDataPos+0-rowOffset], vertexData[vertexDataPos+1-rowOffset], vertexData[vertexDataPos+2-rowOffset] );
                vectorRight = GLKVector3Subtract(ecef0, ecef1);
            }

            GLKVector3 normal = GLKVector3CrossProduct( vectorLeft, vectorRight );
            normal = GLKVector3Normalize(normal);
            
            vertexData[vertexDataPos+3] = normal.x;
            vertexData[vertexDataPos+4] = normal.y;
            vertexData[vertexDataPos+5] = normal.z;
            
            vertexDataPos += 8;
        }
    }
        
    [geom setObjectData:vertexData withSize:vertexDataSize withStride:(8*sizeof(GLfloat))];
    [geom setIndexData:indexData withSize:indexDataSize withStride:sizeof(GLushort)];
    
    free( vertexData );
    free( indexData );
}

- (void)updatePageIfNeeded:(RAPage *)page {
    NSAssert( page != nil, @"the requested page must be valid");

    if ( page.needsUpdate == YES && page.updatePageOp == nil ) {
        RAGeometry * geometry = page.geometry;
        
        // build geometry if needed
        if ( geometry == nil ) {
            geometry = [self createGeometryForTile:page.tile];
        }
        
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
            [self setupGeometry:geometry forPage:page withTextureFromPage:imgAncestor withHeightFromPage:hgtAncestor];
            geometry.texture0 = imgAncestor.imagery;
        } else {
            // show grid if necessary
            [self setupGeometry:geometry forPage:page withTextureFromPage:page withHeightFromPage:hgtAncestor];
            geometry.texture0 = _defaultTexture;
        }
        
        if ( page.geometry == nil )
            page.geometry = geometry;
            
        page.needsUpdate = NO;
    }
}

- (void)requestPage:(RAPage *)page {
    NSAssert( page != nil, @"the requested page must be valid");
    
    // !!! still a memory leak here...
                
    // request the tile image if needed
    if ( page.imagery == nil && page.imageryLoadOp == nil && self.imageryDatabase ) {
        NSURL * url = [self.imageryDatabase urlForTile: page.tile];
        NSURLRequest * request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0];
        
        if ( url && request && _loadQueue.operationCount < 16 ) {
            NSBlockOperation * op = [NSBlockOperation blockOperationWithBlock:^{
                NSURLResponse * response = nil;
                NSError * error = nil;
                NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                
                if ( error ) {
                    NSLog(@"URL Error loading (%@): %@", url, error);
                } else if ( [[response MIMEType] isEqualToString:@"text/html"] ) {
                    NSString * content = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                    NSLog(@"Request Returned: %@", content);
                } else {
                    // without converting the image, I get a "data preprocessing error". I have no idea why
                    UIImage * image = [UIImage imageWithData:data];
                    image = [UIImage imageWithData:UIImageJPEGRepresentation(image, 1.0)];
                    if ( image == nil ) return;
                    
                    @synchronized(self.auxilliaryContext) {
                        [EAGLContext setCurrentContext: self.auxilliaryContext];

                        // create texture
                        GLKTextureInfo * textureInfo = nil;
                        NSError * error = nil;
                        NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
                        textureInfo = [GLKTextureLoader textureWithCGImage:image.CGImage options:options error:&error];
                        if ( error ) {
                            NSLog(@"Error loading texture: %@", error);
                        } else {
                            // generate texture wrapper
                            RATextureWrapper * texture = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
                            page.imagery = texture;
                            page.needsUpdate = YES;
                        }
                        
                        glFlush();
                        [EAGLContext setCurrentContext: nil];
                    }
                }
            }];
            page.imageryLoadOp = op;
            [_loadQueue addOperation:op];
        }
    }
    
    // request the terrain if needed
    if ( page.terrain == nil && page.terrainLoadOp == nil && self.terrainDatabase ) {
        NSURL * url = [self.terrainDatabase urlForTile: page.tile];
        
        if ( url && _loadQueue.operationCount < 16 ) {
            NSBlockOperation * op = [NSBlockOperation blockOperationWithBlock:^{
                NSURLRequest * request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0];
                NSURLResponse * response = nil;
                NSError * error = nil;
                NSData * data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
                
                if ( error ) {
                    NSLog(@"URL Error loading (%@): %@", url, error);
                } else if ( [[response MIMEType] isEqualToString:@"text/html"] ) {
                    NSString * content = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
                    NSLog(@"Request Returned: %@", content);
                } else {
                    // without converting the image, I get a "data preprocessing error". I have no idea why
                    UIImage * image = [UIImage imageWithData:data];
                    
                    page.terrain = image;
                    page.needsUpdate = YES;
                }
            }];
            page.terrainLoadOp = op;
            [_loadQueue addOperation:op];
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

- (void)traversePage:(RAPage *)page {
    NSAssert( page != nil, @"the traversed page must be valid");
    [self requestPage: page];
    [self updatePageIfNeeded: page];
    
    // is the page facing away from the camera?
    //if ( [page calculateTiltWithCamera:self.camera] < -0.5f ) goto pruneChildren;
    
    float texelError = 0.0f;
    if ( page.tile.z <= self.imageryDatabase.maxzoom ) // force display at maximum level
        texelError = [page calculateScreenSpaceErrorWithCamera:self.camera];
    
    // should we choose to display this page?
    if ( texelError < 3.f ) {
        // don't bother traversing if we are offscreen
        if ( ! [page isOnscreenWithCamera:self.camera] ) goto pruneChildren;
        
        //[self requestPage: page];
        //[self updatePageIfNeeded: page];
        goto pruneChildren;
    }

    // traverse children
    [self preparePageForTraversal:page];
    
    [self traversePage: page.child1];
    [self traversePage: page.child2];
    [self traversePage: page.child3];
    [self traversePage: page.child4];
    return;
    
pruneChildren:
    // prune children
    page.child1 = page.child2 = page.child3 = page.child4 = nil;  // !!! replace this with another method
    return;
}

- (void)update {
    // load default texture
    if ( _defaultTexture == nil ) {
        UIImage * image = [UIImage imageNamed:@"grid256"];
        
        NSError * err = nil;
        NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
        GLKTextureInfo * textureInfo = [GLKTextureLoader textureWithCGImage:[image CGImage] options:options error:&err];
        if ( err ) NSLog(@"Error loading default texture: %@", err);
        
        _defaultTexture = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
    }
    
    if ( _traverseOp == nil ) {
        _traverseOp = [NSBlockOperation blockOperationWithBlock:^{
            // traverse pages gathering ones that are active and should be displayed
            [rootPages enumerateObjectsUsingBlock:^(RAPage *page, BOOL *stop) {
                [self traversePage:page];
            }];
        }];
        [_traverseQueue addOperation:_traverseOp];
    }
    
    //NSLog(@"Ops: %d traverse, %d url loading, %d graphics updates", _traverseQueue.operationCount, _loadQueue.operationCount, _graphicsQueue.operationCount);
    //NSLog(@"Total count: Page %d, Geom %d", [RAPage count], [RAGeometry count]);
    
    //[self printPageTree];
}

static NSUInteger sTraverseCount = 0;

- (void)printPage:(RAPage *)page withIndent:(int)indent {
    sTraverseCount++;
    
    NSMutableString * indentString = [NSMutableString string];
    for( int i = 0; i < indent; ++i )
        [indentString appendString:@"  "];
    
    //NSLog(@"%@Tile: %@, Geom: %@", indentString, page.key, page.geometry);
    
    if ( page.child1 ) [self printPage:page.child1 withIndent:indent+1];
    if ( page.child2 ) [self printPage:page.child2 withIndent:indent+1];
    if ( page.child3 ) [self printPage:page.child3 withIndent:indent+1];
    if ( page.child4 ) [self printPage:page.child4 withIndent:indent+1];
}

- (void)printPageTree {
    sTraverseCount = 0;
    //NSLog(@"Page Tree:");
    [rootPages enumerateObjectsUsingBlock:^(RAPage *page, BOOL *stop) {
        [self printPage:page withIndent:1];
    }];
    NSLog(@"Traversed: %d, Total: %d", sTraverseCount, [RAPage count]);
}

@end
