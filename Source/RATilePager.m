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
    RATileDatabase *        _database;
    RATextureWrapper *      _defaultTexture;
    
    NSOperationQueue *      _buildQueue;
    NSOperationQueue *      _loadQueue;
    __weak NSOperation *    _traverseOp;
    
    NSMutableSet *          _activePages;
    NSMutableSet *          _insertPages;
    NSMutableSet *          _removePages;
}

@synthesize database = _database, nodes, rootPages, camera;

- (id)init
{
    self = [super init];
    if (self) {
        nodes = [[RAGroup alloc] init];
        
        _buildQueue = [[NSOperationQueue alloc] init];
        [_buildQueue setName:@"Build Queue"];
        [_buildQueue setMaxConcurrentOperationCount: 1];

        _loadQueue = [[NSOperationQueue alloc] init];
        [_loadQueue setName:@"URL Loading Queue"];
        [_loadQueue setMaxConcurrentOperationCount: 1];
    }
    return self;
}

- (void)dealloc {
    [_buildQueue cancelAllOperations];
    [_buildQueue waitUntilAllOperationsAreFinished];

    [_loadQueue cancelAllOperations];
    [_loadQueue waitUntilAllOperationsAreFinished];
}

- (RATileDatabase *)database {
    return _database;
}

- (void)setDatabase:(RATileDatabase *)database {
    _database = database;
    
    // build root pages
    NSMutableSet * pages = [NSMutableSet set];
    
    int basezoom = self.database.minzoom;
    if ( basezoom < 2 ) basezoom = 2;
    int tilecount = 1 << basezoom;  // fast way to calc 2 ^ basezoom
    
    TileID t;
    t.z = basezoom;
    for( t.y = 0; t.y < tilecount; t.y++ ) {
        for( t.x = 0; t.x < tilecount; t.x++ ) {
            [pages addObject:[self makeLeafPageForTile:t withParent:nil]];
        }
    }
    
    rootPages = [NSSet setWithSet:pages];
}

- (RAGeometry *)createGeometryForTile:(TileID)tile
{
    int gridSize = 8;
            
    RAPolarCoordinate lowerLeft = [self.database tileLatLonOrigin:tile];
    RAPolarCoordinate upperRight = [self.database tileLatLonOrigin:TileOppositeCorner(tile)];
    
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
    
    // specify mesh vertices and indices
    size_t vertexDataPos = 0;
    size_t indexDataPos = 0;
    for( unsigned int gy = 0; gy < gridSize; gy++ ) {
        for( unsigned int gx = 0; gx < gridSize; gx++ ) {
            RAPolarCoordinate gpos;
            gpos.latitude = lowerLeft.latitude + gy*latInterval;
            gpos.longitude = lowerLeft.longitude + gx*lonInterval;
            gpos.height = lowerLeft.height;
            
            GLKVector3 ecef = ConvertPolarToEcef(gpos);
            GLKVector3 normal = GLKVector3Normalize(ecef);
            GLKVector2 tex = [self.database textureCoordsForLatLon:gpos inTile:tile];
            
            // fill vertex data
            vertexData[vertexDataPos++] = ecef.x;
            vertexData[vertexDataPos++] = ecef.y;
            vertexData[vertexDataPos++] = ecef.z;
            
            vertexData[vertexDataPos++] = normal.x;
            vertexData[vertexDataPos++] = normal.y;
            vertexData[vertexDataPos++] = normal.z;
            
            vertexData[vertexDataPos++] = tex.x;
            vertexData[vertexDataPos++] = tex.y;
            
            if ( gx < gridSize-1 && gy < gridSize-1 ) {
                GLushort baseElement = gy*gridSize + gx;
                indexData[indexDataPos++] = baseElement;
                indexData[indexDataPos++] = baseElement + 1;
                indexData[indexDataPos++] = baseElement + gridSize;
                
                indexData[indexDataPos++] = baseElement + 1;
                indexData[indexDataPos++] = baseElement + gridSize + 1;
                indexData[indexDataPos++] = baseElement + gridSize;
            }
        }
    }
    NSAssert( vertexDataPos == 8*gridSize*gridSize, @"didn't fill vertex array" );
    NSAssert( indexDataPos == 6*(gridSize-1)*(gridSize-1), @"didn't fill index array" );
            
    // create geometry node
    RAGeometry * geom = [RAGeometry new];
    [geom setObjectData:vertexData withSize:vertexDataSize withStride:(8*sizeof(GLfloat))];
    geom.positionOffset = (0*sizeof(GLfloat));
    geom.normalOffset = (3*sizeof(GLfloat));
    geom.textureOffset = (6*sizeof(GLfloat));
    [geom setIndexData:indexData withSize:indexDataSize withStride:sizeof(GLushort)];
    
    // set material
    geom.material = [GLKEffectPropertyMaterial new];
    //geom.material.ambientColor = (GLKVector4){ 0.8, 0.8, 0.8, 1.0};
    geom.material.diffuseColor = (GLKVector4){ 0.8, 0.8, 0.8, 1.0};
    geom.material.specularColor = (GLKVector4){ 1.0, 1.0, 1.0, 1.0};
    geom.material.shininess = 10.0f;
    
    return geom;
}

- (RAPage *)makeLeafPageForTile:(TileID)t withParent:(RAPage *)parent{
    RAPage * page = [[RAPage alloc] initWithTileID:t andParent:parent];
    
    // calculate tile center and radius
    GLKVector3 center = ConvertPolarToEcef( [self.database tileLatLonCenter:page.tile] );
    GLKVector3 corner = ConvertPolarToEcef( [self.database tileLatLonOrigin:page.tile] );
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

- (void)requestPage:(RAPage *)page {
    NSAssert( page != nil, @"the requested page must be valid");

    if ( page.geometry == nil && page.buildOp == nil ) {
        // generate the geometry
        NSBlockOperation * buildOp = [NSBlockOperation blockOperationWithBlock:^{
            page.geometry = [self createGeometryForTile:page.tile];
            page.geometry.texture = _defaultTexture;
        }];
        [_buildQueue addOperation: buildOp];
        page.buildOp = buildOp;

        // request the tile image
#if 1   /* set this to 0 to skip page loading and display a grid instead */
        NSURL * url = [self.database urlForTile: page.tile];
        if ( url ) {
            NSURLRequest * request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
            
            [NSURLConnection sendAsynchronousRequest:request queue:_loadQueue completionHandler:^(NSURLResponse* response, NSData* data, NSError* error){
                if ( error ) {
                    NSLog(@"URL Error loading (%@): %@", url, error);
                    page.image = [UIImage imageNamed:@"grid256"];
                } else {
                    page.image = [UIImage imageWithData:data];
                    page.image = [UIImage imageWithData:UIImageJPEGRepresentation(page.image, 1.0)];
                    page.needsUpdate = YES;
                }
            }];
        }
#endif
    }

    page.lastRequestTime = [NSDate timeIntervalSinceReferenceDate];
}

- (float)calculatePageTilt:(RAPage *)page {
    // calculate dot product between page normal and camera vector
    const GLKVector3 unitZ = { 0, 0, -1 };
    GLKVector3 pageNormal = GLKVector3Normalize(page.bound.center);
    GLKVector3 cameraLook = GLKVector3Normalize(GLKMatrix4MultiplyAndProjectVector3( GLKMatrix4Invert(self.camera.modelViewMatrix, NULL), unitZ ));
    return GLKVector3DotProduct(pageNormal, cameraLook);
}

- (float)calculatePageScreenSpaceError:(RAPage *)page {
    // !!! this does not work so well on large, curved pages
    // in this case, should test all four corners of the tile and take min distance
    GLKVector3 center = GLKMatrix4MultiplyAndProjectVector3( self.camera.modelViewMatrix, page.bound.center );
    //double distance = GLKVector3Length(center);
    double distance = -center.z;
    
    /*GLKVector3 eye = GLKMatrix4MultiplyAndProjectVector3( self.camera.modelViewMatrix, GLKVector3Make(0, 0, 0) );
    double distance = GLKVector3Length(eye) - WGS_84_RADIUS_EQUATOR;*/
    
    // !!! this should be based upon the Camera
    double theta = GLKMathDegreesToRadians(65.0f);
    double w = 2. * distance * tan(theta/2.);
    
    // convert object error to screen error
    double x = 1024;    // screen size
    double epsilon = ( 2. * page.bound.radius ) / 256.;    // object error
    return ( epsilon * x ) / w;
}

- (BOOL)isPageOnscreen:(RAPage *)page {
    GLKMatrix4 modelViewProjectionMatrix = GLKMatrix4Multiply( self.camera.projectionMatrix, self.camera.modelViewMatrix );
    
    RABoundingSphere * sb = [page.bound transform:modelViewProjectionMatrix];
    if ( sb.center.x + sb.radius < -1.5 || sb.center.x - sb.radius > 1.5 ) return NO;
    if ( sb.center.y + sb.radius < -1.5 || sb.center.y - sb.radius > 1.5 ) return NO;
    
    return YES;
}

- (BOOL)traversePage:(RAPage *)page collectActivePages:(NSMutableSet *)activeSet {
    NSAssert( page != nil, @"the traversed page must be valid");
    [self preparePageForTraversal:page];
        
    // is the page facing away from the camera?
    if ( [self calculatePageTilt:page] < -0.5f )
        return YES;
    
    // should we choose to display this page?
    float texelError = [self calculatePageScreenSpaceError:page];
    if ( texelError < 3.5f ) {
        // don't bother traversing if we are offscreen
        if ( ! [self isPageOnscreen:page] ) return YES;
        
        [self requestPage: page];

        if ( page.isReady ) {
            [activeSet addObject:page];
            
            // request the parent since it will likely be needed
            if ( page.parent ) [self requestPage:page.parent];
            return YES;
        } else {
            // try to display the immediate children
            BOOL allChildrenReady = page.child1.isReady && page.child2.isReady && page.child3.isReady && page.child4.isReady;
            if ( allChildrenReady ) {
                [activeSet addObject:page.child1];
                [activeSet addObject:page.child2];
                [activeSet addObject:page.child3];
                [activeSet addObject:page.child4];
                return YES;
            }
        }
    } else {
        // render children
        NSMutableSet * activeSubset = [NSMutableSet new];
        
        // traverse children, but stop upon a page fault
        if ( [self traversePage: page.child1 collectActivePages:activeSubset] &&
             [self traversePage: page.child2 collectActivePages:activeSubset] &&
             [self traversePage: page.child3 collectActivePages:activeSubset] &&
             [self traversePage: page.child4 collectActivePages:activeSubset] )
        {
            [activeSet unionSet: activeSubset];
            return YES;
        } else {
            // display this node as an alternate
            if ( page.isReady ) {
                [activeSet addObject:page];
                return YES;
            }
        }
    }
    
    // return value of NO indicates there was a page fault
    return NO;
}

- (void)updateSceneGraph {
    // this is the only method where the GL context is valid!
    NSAssert( self.database, @"database must be valid" );
    
    // load default texture
    if ( _defaultTexture == nil ) {
        UIImage * image = [UIImage imageNamed:@"clear256"];
        
        NSError * err = nil;
        NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
        GLKTextureInfo * textureInfo = [GLKTextureLoader textureWithCGImage:[image CGImage] options:options error:&err];
        if ( err ) NSLog(@"Error loading texture: %@", err);
        
        _defaultTexture = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
    }
    
    BOOL doTraversal = ( _loadQueue.operationCount == 0 );
    
    // begin a traversal if necessary
    if ( _traverseOp == nil && doTraversal ) {
        NSBlockOperation * op = [NSBlockOperation blockOperationWithBlock:^{
            NSMutableSet * currentPages = [[NSMutableSet alloc] init];
            
            // traverse pages looking for changes
            [rootPages enumerateObjectsUsingBlock:^(RAPage *page, BOOL *stop) {
                [self traversePage:page collectActivePages:currentPages];
            }];
            
            @synchronized(self) {
                NSMutableSet * insertPages = [currentPages mutableCopy];
                [insertPages minusSet: _activePages];

                NSMutableSet * removePages = [_activePages mutableCopy];
                [removePages minusSet: currentPages];
                
                //NSLog(@"New Active: %d, Insert: %d, Remove: %d", currentPages.count, insertPages.count, removePages.count);
                _insertPages = insertPages;
                _removePages = removePages;
                _activePages = currentPages;
            }
        }];
        [_loadQueue addOperation:op];
        _traverseOp = op;
    }
        
    @synchronized(self) {
        //NSLog(@"Active: %d, Insert: %d, Remove: %d, Build Ops: %d, Load Ops: %d", _activePages.count, _insertPages.count, _removePages.count, _buildQueue.operationCount, _loadQueue.operationCount);
                        
        // add new pages
        [_insertPages enumerateObjectsUsingBlock:^(RAPage * page, BOOL *stop) {
            [nodes addChild: page.geometry];
            [page setupGL];
        }];
        
        // setup all pages
        [_activePages enumerateObjectsUsingBlock:^(RAPage * page, BOOL *stop) {
            [page setupGL];
        }];
        
        // remove pages from scene graph
        [_removePages enumerateObjectsUsingBlock:^(RAPage *page, BOOL *stop) {
            [nodes removeChild: page.geometry];
            [page releaseGL];
            
            // delete the page data if not a root page
            if ( ! [rootPages containsObject:page] ) {
                page.image = nil;
                page.geometry = nil;
            }
        }];
        
        // this section would replace the page deletion above, but it doesn't quite work well yet
        /*
        [_removePages minusSet: rootPages];
        NSUInteger totalPages = _insertPages.count + _removePages.count + _activePages.count;
        NSUInteger maxPages = 100;

        if ( totalPages > maxPages && _removePages.count > 0 ) {
            // remove pages that are active but no longer needed
            NSMutableArray * removeArray = [NSMutableArray arrayWithArray:[_removePages allObjects]];
            [removeArray sortUsingComparator:(NSComparator)^(RAPage *a, RAPage *b){
                return a.lastRequestTime < b.lastRequestTime;
            }];
            // !!! check that this is the right order
            
            // remove as many as we need
            if ( totalPages - _removePages.count < maxPages )
                [removeArray removeObjectsInRange:NSMakeRange(0, totalPages - maxPages)];
            
            NSLog(@"Removing: %d", removeArray.count);
            [removeArray enumerateObjectsUsingBlock:^(RAPage *page, NSUInteger idx, BOOL *stop) {
                page.image = nil;
                page.geometry = nil;
                
                if ( page.isLeaf ) [page prune];
            }];
        }
        */
        
        _insertPages = nil;
        _removePages = nil;
    }
    
    [RATextureWrapper cleanup];
}

@end
