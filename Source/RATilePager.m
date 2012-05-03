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
    
    NSOperationQueue *      _urlLoadingQueue;
    NSOperationQueue *      _graphicsQueue;
    
    /*NSMutableSet *          _activePages;
    NSMutableSet *          _insertPages;
    NSMutableSet *          _removePages;*/
}

@synthesize imageryDatabase, terrainDatabase, auxilliaryContext, rootNode, rootPages, camera;

- (id)init
{
    self = [super init];
    if (self) {
        //rootNode = [[RAGroup alloc] init];
        
        // enlarge shared cache
        NSURLCache * cache = [NSURLCache sharedURLCache];
        [cache setMemoryCapacity: 5*1000*1000];
        [cache setDiskCapacity: 250*1000*1000];
        
        _urlLoadingQueue = [[NSOperationQueue alloc] init];
        [_urlLoadingQueue setName:@"URL Loading Queue"];
        [_urlLoadingQueue setMaxConcurrentOperationCount: 4];
        
        _graphicsQueue = [[NSOperationQueue alloc] init];
        [_graphicsQueue setName:@"OpenGL ES Background Queue"];
        [_graphicsQueue setMaxConcurrentOperationCount: 1];
    }
    return self;
}

- (void)dealloc {
    [_urlLoadingQueue cancelAllOperations];
    [_urlLoadingQueue waitUntilAllOperationsAreFinished];

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
    GLfloat * vertexData = (GLfloat *)alloca(vertexDataSize);
    
    size_t indexDataSize = 6*sizeof(GLushort) * (gridSize-1)*(gridSize-1);
    GLushort * indexData = (GLushort *)alloca(indexDataSize);
    
    // get raw access to image data
    NSUInteger bytesPerPixel = 4;
    NSUInteger bytesPerRow = 0;
    NSUInteger width = 0, height = 0;
    unsigned char * rawData = NULL;
    if ( hgtPage.terrain ) {
        CGImageRef imageRef = [hgtPage.terrain CGImage];
        width = CGImageGetWidth(imageRef);
        height = CGImageGetHeight(imageRef);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        rawData = (unsigned char*)calloc(height * width * 4, sizeof(unsigned char));
        bytesPerRow = bytesPerPixel * width;
        NSUInteger bitsPerComponent = 8;
        CGContextRef context = CGBitmapContextCreate(rawData, width,
            height,bitsPerComponent, bytesPerRow, colorSpace,
            kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGColorSpaceRelease(colorSpace);
        
        CGContextDrawImage(context, CGRectMake(0, 0, width, height), imageRef);
        CGContextRelease(context);
    }
    
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
            GLKVector3 normal = GLKVector3Normalize(ecef);
            GLKVector2 tex = [self.imageryDatabase textureCoordsForLatLon:gpos inTile:texPage.tile];
            
            if ( rawData ) {
                GLKVector2 hgtPixel = [self.imageryDatabase textureCoordsForLatLon:gpos inTile:hgtPage.tile];
                hgtPixel.x = (width-1) * hgtPixel.x;
                hgtPixel.y = (height-1) * (1.0-hgtPixel.y);

                // extrude by height
                unsigned char * pixel = rawData + (bytesPerRow * (int)hgtPixel.y) + (bytesPerPixel * (int)hgtPixel.x);
                CGFloat red   = pixel[0] / 255.0;
                CGFloat green = pixel[1] / 255.0;
                CGFloat blue  = pixel[2] / 255.0;
                
                float height = 0.005 * ( red + green + blue );
                ecef = GLKVector3Add( ecef, GLKVector3MultiplyScalar(normal, height) );
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
    indexDataPos = 0;
    
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
    
    if ( rawData ) free( rawData );
}

- (void)updatePageIfNeeded:(RAPage *)page {
    NSAssert( page != nil, @"the requested page must be valid");

    if ( page.needsUpdate == YES && page.updatePageOp == nil ) {
        __block NSBlockOperation * op = [NSBlockOperation blockOperationWithBlock:^{
            if ( op.isCancelled ) return;
            
            [EAGLContext setCurrentContext: self.auxilliaryContext];
            
            RAGeometry * geometry = page.geometry;
            
            // build geometry if needed
            if ( geometry == nil )
                geometry = [self createGeometryForTile:page.tile];

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
            
            //[geometry setupGL];
            [EAGLContext setCurrentContext: nil];

            if ( page.geometry == nil )
                page.geometry = geometry;
                
            page.needsUpdate = NO;
            page.updatePageOp = nil;
        }];
        page.updatePageOp = op;
        [_graphicsQueue addOperation:op];
    }
}

- (void)requestPage:(RAPage *)page {
    NSAssert( page != nil, @"the requested page must be valid");
    
    // request the tile image if needed
    if ( page.imagery == nil && page.imageryLoadOp == nil && self.imageryDatabase ) {
        NSURL * url = [self.imageryDatabase urlForTile: page.tile];
        NSURLRequest * request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0];
        
        if ( url && request ) {
            __block NSBlockOperation * op = [NSBlockOperation blockOperationWithBlock:^{
                if ( op.isCancelled ) return;
                
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
                    
                    __block NSBlockOperation * op2 = [NSBlockOperation blockOperationWithBlock:^{
                        if ( op2.isCancelled ) return;
                        NSError * error = nil;
                        
                        [EAGLContext setCurrentContext: self.auxilliaryContext];

                        // create texture
                        GLKTextureInfo * textureInfo = nil;
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

                        [EAGLContext setCurrentContext: nil];
                        page.imageryLoadOp = nil;   // !!! necessary?
                    }];
                    page.imageryLoadOp = op2;
                    [_graphicsQueue addOperation:op2];
                }
            }];
            page.imageryLoadOp = op;
            [_urlLoadingQueue addOperation:op];
        }
    }
    
    // request the terrain if needed
    if ( page.terrain == nil && page.terrainLoadOp == nil && self.terrainDatabase ) {
        NSURL * url = [self.terrainDatabase urlForTile: page.tile];
        NSURLRequest * request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0];
        
        // !!! if url is invalid (i.e. if beyond the max zoom level) then we will repeatedly try to load it!
        
        if ( url && request ) {
            __block NSBlockOperation * op = [NSBlockOperation blockOperationWithBlock:^{
                if ( op.isCancelled ) return;
                
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
                
                page.terrainLoadOp = nil;   // !!! necessary?
            }];
            page.terrainLoadOp = op;
            [_urlLoadingQueue addOperation:op];
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

- (void)traversePage:(RAPage *)page collectActivePages:(NSMutableSet *)activeSet {
    NSAssert( page != nil, @"the traversed page must be valid");
        
    // is the page facing away from the camera?
    if ( [page calculateTiltWithCamera:self.camera] < -0.5f ) return;
    
    float texelError = 0.0f;
    if ( page.tile.z <= self.imageryDatabase.maxzoom ) // force display at maximum level
        texelError = [page calculateScreenSpaceErrorWithCamera:self.camera];
    
    // should we choose to display this page?
    if ( texelError < 3.f ) {
        // don't bother traversing if we are offscreen
        if ( ! [page isOnscreenWithCamera:self.camera] ) return;
        
        [self requestPage: page];
        [self updatePageIfNeeded: page];
        [activeSet addObject:page];
        
        // prune children
        // !!! [page.child1.imageryLoadOp cancel]; ...
        page.child1 = page.child2 = page.child3 = page.child4 = nil;
        return;
    }

    // traverse children
    [self preparePageForTraversal:page];

    [self traversePage: page.child1 collectActivePages:activeSet];
    [self traversePage: page.child2 collectActivePages:activeSet];
    [self traversePage: page.child3 collectActivePages:activeSet];
    [self traversePage: page.child4 collectActivePages:activeSet];
}

- (void)update {
    // this is the only method where the GL context is valid!
    
    // load default texture
    if ( _defaultTexture == nil ) {
        UIImage * image = [UIImage imageNamed:@"grid256"];
        
        NSError * err = nil;
        NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
        GLKTextureInfo * textureInfo = [GLKTextureLoader textureWithCGImage:[image CGImage] options:options error:&err];
        if ( err ) NSLog(@"Error loading default texture: %@", err);
        
        _defaultTexture = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
    }
    
    /*
    if ( _overlayTexture == nil ) {
        UIImage * image = [UIImage imageNamed:@"clear256"];
        
        NSError * err = nil;
        NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
        GLKTextureInfo * textureInfo = [GLKTextureLoader textureWithCGImage:[image CGImage] options:options error:&err];
        if ( err ) NSLog(@"Error loading overlay texture: %@", err);
        
        _overlayTexture = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
    }
    */
    
    //NSMutableSet * currentPages = [[NSMutableSet alloc] init];
    
    // traverse pages gathering ones that are active and should be displayed
    [rootPages enumerateObjectsUsingBlock:^(RAPage *page, BOOL *stop) {
        [self traversePage:page collectActivePages:nil];    // !!! currentPages
    }];
    
    //NSLog(@"Ops: %d urls loading, %d graphics updates", _urlLoadingQueue.operationCount, _graphicsQueue.operationCount);
    
    /*
    @synchronized(self) {
        NSMutableSet * insertPages = [currentPages mutableCopy];
        [insertPages minusSet: _activePages];
        
        NSMutableSet * removePages = [_activePages mutableCopy];
        [removePages minusSet: currentPages];
        
        _insertPages = insertPages;
        _removePages = removePages;
        _activePages = currentPages;
    }
    
    @synchronized(self) {
        //NSLog(@"Active: %d, Insert: %d, Remove: %d", _activePages.count, _insertPages.count, _removePages.count);
        
        // add new pages
        [_insertPages enumerateObjectsUsingBlock:^(RAPage * page, BOOL *stop) {
            [rootNode addChild: page.geometry];
        }];
        
        // remove pages from scene graph
        [_removePages enumerateObjectsUsingBlock:^(RAPage *page, BOOL *stop) {
            [rootNode removeChild: page.geometry];
            [page.geometry releaseGL];
            
            // delete the page data if not a root page
            if ( ! [rootPages containsObject:page] ) {
                page.geometry = nil;
                page.needsUpdate = YES;
            }
        }];
        
        _insertPages = nil;
        _removePages = nil;
    }
     */
    
    [RATextureWrapper cleanup];
}

@end
