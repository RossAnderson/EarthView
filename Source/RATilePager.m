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

//#define ENABLE_GRID_OVERLAY

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
#ifdef ENABLE_GRID_OVERLAY
    RATextureWrapper *      _overlayTexture;
#endif
    
    NSOperationQueue *      _loadQueue;
    __weak NSOperation *    _traverseOp;
    
    NSMutableSet *          _activePages;
    NSMutableSet *          _insertPages;
    NSMutableSet *          _removePages;
}

@synthesize database = _database, loadingContext, nodes, rootPages, camera;

- (id)init
{
    self = [super init];
    if (self) {
        nodes = [[RAGroup alloc] init];
        
        // enlarge shared cache
        NSURLCache * cache = [NSURLCache sharedURLCache];
        [cache setMemoryCapacity: 5*1000*1000];
        [cache setDiskCapacity: 250*1000*1000];
        
        _loadQueue = [[NSOperationQueue alloc] init];
        [_loadQueue setName:@"URL Loading Queue"];
        [_loadQueue setMaxConcurrentOperationCount: 1];
    }
    return self;
}

- (void)dealloc {
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
    // create geometry node
    RAGeometry * geom = [RAGeometry new];
    geom.positionOffset = (0*sizeof(GLfloat));
    geom.normalOffset = (3*sizeof(GLfloat));
    geom.textureOffset = (6*sizeof(GLfloat));
    
    static GLKEffectPropertyMaterial * sPageMaterial = nil;
    if ( sPageMaterial == nil ) {
        sPageMaterial = [GLKEffectPropertyMaterial new];
        sPageMaterial.ambientColor = (GLKVector4){ 0.8f, 0.8f, 0.8f, 1.0};
        sPageMaterial.diffuseColor = (GLKVector4){ 1.0f, 1.0f, 1.0f, 1.0};
        sPageMaterial.specularColor = (GLKVector4){ 0.0f, 0.0f, 0.0f, 1.0};
        sPageMaterial.shininess = 0.0f;
    }
    geom.material = sPageMaterial;
    
    return geom;
}

- (void)setupPageGeometry:(RAGeometry *)geom forTile:(TileID)tile withTexForTile:(TileID)texTile {
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
            GLKVector2 tex = [self.database textureCoordsForLatLon:gpos inTile:texTile];
            
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
    
    [geom setObjectData:vertexData withSize:vertexDataSize withStride:(8*sizeof(GLfloat))];
    [geom setIndexData:indexData withSize:indexDataSize withStride:sizeof(GLushort)];
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
    // page.lastRequestTime = [NSDate timeIntervalSinceReferenceDate]; // not currently used

    if ( page.geometry == nil ) {
        // generate the geometry
        page.geometry = [self createGeometryForTile:page.tile];
        
        // find a ancestor tile with a valid texture (currently limited to parent)
        if ( page.parent.geometry.texture0 ) {
            [self setupPageGeometry:page.geometry forTile:page.tile withTexForTile:page.parent.tile];
            page.geometry.texture0 = page.parent.geometry.texture0;
        } else {
            [self setupPageGeometry:page.geometry forTile:page.tile withTexForTile:page.tile];
            page.geometry.texture0 = _defaultTexture;
        }
#ifdef ENABLE_GRID_OVERLAY
        page.geometry.texture1 = _overlayTexture;
#endif

        // request the tile image
#if 1   /* set this to 0 to skip page loading and display a grid instead */
        NSURL * url = [self.database urlForTile: page.tile];
        if ( url ) {
            NSURLRequest * request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0];
            
            [NSURLConnection sendAsynchronousRequest:request queue:_loadQueue completionHandler:^(NSURLResponse* response, NSData* data, NSError* error) {
                if ( error ) {
                    NSLog(@"URL Error loading (%@): %@", url, error);
                } else {
                    [EAGLContext setCurrentContext: self.loadingContext];
                    
                    // without converting the image, I get a "data preprocessing error". I have no idea why
                    UIImage * image = [UIImage imageWithData:data];
                    image = [UIImage imageWithData:UIImageJPEGRepresentation(image, 1.0)];
                    
                    // create texture
                    GLKTextureInfo * textureInfo = nil;
                    NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
                    textureInfo = [GLKTextureLoader textureWithCGImage:[image CGImage] options:options error:&error];
                    if ( error ) {
                        NSLog(@"Error loading texture: %@", error);
                    } else {
                        [self setupPageGeometry:page.geometry forTile:page.tile withTexForTile:page.tile];
                        page.geometry.texture0 = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
                    }
                    
                    glFlush();
                    [EAGLContext setCurrentContext: nil];
                }
            }];
        }
#endif
    }
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
    double distance = GLKVector3Length(center);
    //double distance = -center.z;  // seem like this should be more accurate, but the math clearing isn't quite right, as it favors pages near the equator
    
    // !!! this should be based upon the Camera parameters
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

- (void)traversePage:(RAPage *)page collectActivePages:(NSMutableSet *)activeSet {
    NSAssert( page != nil, @"the traversed page must be valid");
        
    // is the page facing away from the camera?
    if ( [self calculatePageTilt:page] < -0.5f ) return;
    
    float texelError = 0.0f;
    if ( page.tile.z <= self.database.maxzoom ) // force display at maximum level
        texelError = [self calculatePageScreenSpaceError:page];
    
    // should we choose to display this page?
    if ( texelError < 3.f ) {
        // don't bother traversing if we are offscreen
        if ( ! [self isPageOnscreen:page] ) return;
        
        [self requestPage: page];
        [activeSet addObject:page];
        
        // prune children
        page.child1 = page.child2 = page.child3 = page.child4 = nil;
    } else {
        // traverse children
        [self preparePageForTraversal:page];

        [self traversePage: page.child1 collectActivePages:activeSet];
        [self traversePage: page.child2 collectActivePages:activeSet];
        [self traversePage: page.child3 collectActivePages:activeSet];
        [self traversePage: page.child4 collectActivePages:activeSet];
    }
}

- (void)updateSceneGraph {
    // this is the only method where the GL context is valid!
    NSAssert( self.database, @"database must be valid" );
    
    // load default texture
    if ( _defaultTexture == nil ) {
        UIImage * image = [UIImage imageNamed:@"grid256"];
        
        NSError * err = nil;
        NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
        GLKTextureInfo * textureInfo = [GLKTextureLoader textureWithCGImage:[image CGImage] options:options error:&err];
        if ( err ) NSLog(@"Error loading texture: %@", err);
        
        _defaultTexture = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
    }
    
#ifdef ENABLE_GRID_OVERLAY
    if ( _overlayTexture == nil ) {
        UIImage * image = [UIImage imageNamed:@"clear256"];
        
        NSError * err = nil;
        NSDictionary * options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:GLKTextureLoaderOriginBottomLeft];
        GLKTextureInfo * textureInfo = [GLKTextureLoader textureWithCGImage:[image CGImage] options:options error:&err];
        if ( err ) NSLog(@"Error loading texture: %@", err);
        
        _overlayTexture = [[RATextureWrapper alloc] initWithTextureInfo:textureInfo];
    }
#endif
    
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
        //NSLog(@"Active: %d, Insert: %d, Remove: %d, Load Ops: %d", _activePages.count, _insertPages.count, _removePages.count, _loadQueue.operationCount);
                        
        // add new pages
        [_insertPages enumerateObjectsUsingBlock:^(RAPage * page, BOOL *stop) {
            [nodes addChild: page.geometry];
        }];
        
        // remove pages from scene graph
        [_removePages enumerateObjectsUsingBlock:^(RAPage *page, BOOL *stop) {
            [nodes removeChild: page.geometry];
            [page.geometry releaseGL];
            
            // delete the page data if not a root page
            if ( ! [rootPages containsObject:page] ) {
                page.geometry = nil;
            }
        }];
        
        _insertPages = nil;
        _removePages = nil;
    }
    
    [RATextureWrapper cleanup];
}

@end
