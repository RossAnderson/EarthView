//
//  RASceneGraphController.m
//  RASceneGraphTest
//
//  Created by Ross Anderson on 2/19/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RASceneGraphController.h"

#import <GLKit/GLKTextureLoader.h>

#import "RABoundingSphere.h"
#import "RANodeVisitor.h"
#import "RARenderVisitor.h"
#import "RAGeographicUtils.h"

#import "RAManipulator.h"
#import "RATileDatabase.h"
#import "RATilePager.h"


#pragma mark -

@interface SetupGeometryVisitor : RANodeVisitor
@end

@implementation SetupGeometryVisitor
- (void)applyGeometry:(RAGeometry *)node
{
    [node setupGL];
}
@end


#pragma mark -

@interface ReleaseGeometryVisitor : RANodeVisitor
@end

@implementation ReleaseGeometryVisitor
- (void)applyGeometry:(RAGeometry *)node
{
    [node releaseGL];
}
@end

#pragma mark -


@interface RASceneGraphController () {
    RARenderVisitor *   renderVisitor;
    RAManipulator *     manipulator;
    RATileDatabase *    database;
    RATilePager *       pager;
    
    EAGLContext *       context;
    GLKBaseEffect *     effect;
    GLKSkyboxEffect *   skybox;
}

@property (strong, nonatomic) UIPopoverController *masterPopoverController;

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation RASceneGraphController

@synthesize sceneRoot = _sceneRoot;
@synthesize masterPopoverController = _masterPopoverController;
@synthesize database = database;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        manipulator = [RAManipulator new];
        
        renderVisitor = [RARenderVisitor new];
        renderVisitor.camera = manipulator.camera;

        database = [RATileDatabase new];
        database.bounds = CGRectMake( -180,-90,360,180 );
        database.googleTileConvention = YES;
        
        // OpenStreetMap default tiles
        database.baseUrlString = @"http://c.tile.openstreetmap.org/{z}/{x}/{y}.png";
        database.minzoom = 2;
        database.maxzoom = 18;
        
        // setup the database pager
        pager = [RATilePager new];
        pager.database = database;
        pager.camera = manipulator.camera;
}
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    
    manipulator.view = self.view;
    
    [self setupGL];
}

- (void)viewDidUnload
{    
    [super viewDidUnload];
    
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }
	context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc. that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark - Scene Graph


- (RAGeometry *)makeBoxWithHalfWidth:(GLfloat)half
{
    typedef struct {
        GLfloat Position[3];
        GLfloat Normal[3];
    } Vertex;
    
    const Vertex Vertices[] = {
        {{half, -half, -half},  {1.0f, 0.0f, 0.0f} },
        {{half, half, -half},   {1.0f, 0.0f, 0.0f} },
        {{half, -half, half},   {1.0f, 0.0f, 0.0f} },
        {{half, -half, half},   {1.0f, 0.0f, 0.0f} },
        {{half, half, -half},   {1.0f, 0.0f, 0.0f} },
        {{half, half, half},    {1.0f, 0.0f, 0.0f} },
        
        {{half, half, -half},   {0.0f, 1.0f, 0.0f} },
        {{-half, half, -half},  {0.0f, 1.0f, 0.0f} },
        {{half, half, half},    {0.0f, 1.0f, 0.0f} },
        {{half, half, half},    {0.0f, 1.0f, 0.0f} },
        {{-half, half, -half},  {0.0f, 1.0f, 0.0f} },
        {{-half, half, half},   {0.0f, 1.0f, 0.0f} },
        
        {{-half, half, -half},  {-1.0f, 0.0f, 0.0f} },
        {{-half, -half, -half}, {-1.0f, 0.0f, 0.0f} },
        {{-half, half, half},   {-1.0f, 0.0f, 0.0f} },
        {{-half, half, half},   {-1.0f, 0.0f, 0.0f} },
        {{-half, -half, -half}, {-1.0f, 0.0f, 0.0f} },
        {{-half, -half, half},  {-1.0f, 0.0f, 0.0f} },
        
        {{-half, -half, -half}, {0.0f, -1.0f, 0.0f} },
        {{half, -half, -half},  {0.0f, -1.0f, 0.0f} },
        {{-half, -half, half},  {0.0f, -1.0f, 0.0f} },
        {{-half, -half, half},  {0.0f, -1.0f, 0.0f} },
        {{half, -half, -half},  {0.0f, -1.0f, 0.0f} },
        {{half, -half, half},   {0.0f, -1.0f, 0.0f} },
        
        {{half, half, half},    {0.0f, 0.0f, 1.0f} },
        {{-half, half, half},   {0.0f, 0.0f, 1.0f} },
        {{half, -half, half},   {0.0f, 0.0f, 1.0f} },
        {{half, -half, half},   {0.0f, 0.0f, 1.0f} },
        {{-half, half, half},   {0.0f, 0.0f, 1.0f} },
        {{-half, -half, half},  {0.0f, 0.0f, 1.0f} },
        
        {{half, -half, -half},  {0.0f, 0.0f, -1.0f} },
        {{-half, -half, -half}, {0.0f, 0.0f, -1.0f} },
        {{half, half, -half},   {0.0f, 0.0f, -1.0f} },
        {{half, half, -half},   {0.0f, 0.0f, -1.0f} },
        {{-half, -half, -half}, {0.0f, 0.0f, -1.0f} },
        {{-half, half, -half},  {0.0f, 0.0f, -1.0f} }
    };
    
    const GLubyte Indices[] = {
        0, 1, 2,  3, 4, 5,
        6, 7, 8,  9, 10, 11,
        12, 13, 14,  15, 16, 17,
        18, 19, 20,  21, 22, 23,
        24, 25, 26,  27, 28, 29,
        30, 31, 32, 33, 34, 35
    };
    
    RAGeometry * geom = [RAGeometry new];
    [geom setObjectData:Vertices withSize:sizeof(Vertices) withStride:sizeof(Vertex)];
    geom.positionOffset = offsetof(Vertex, Position);
    geom.normalOffset = offsetof(Vertex, Normal);
    [geom setIndexData:Indices withSize:sizeof(Indices) withStride:sizeof(GLubyte)];
    
    return geom;
}

- (RANode *)createBlueMarble
{
    RAGroup * root = [RAGroup new];
    [root addChild: pager.nodes];
        
    return root;
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:context];
        
    glEnable(GL_DEPTH_TEST);
    
    glEnable(GL_BLEND);
    glBlendFunc( GL_ONE, GL_ONE_MINUS_SRC_ALPHA );
    
    effect = [[GLKBaseEffect alloc] init];
    effect.label = @"Base Effect";
    effect.light0.enabled = GL_TRUE;
    
    // setup skybox
    NSString * starPath = [[NSBundle mainBundle] pathForResource:@"star1" ofType:@"jpg"];
    NSArray * starPaths = [NSArray arrayWithObjects: starPath, starPath, starPath, starPath, starPath, starPath, nil];
    NSError * error = nil;
    NSDictionary *options = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] 
                                                        forKey:GLKTextureLoaderOriginBottomLeft];
    GLKTextureInfo * starTexture = [GLKTextureLoader cubeMapWithContentsOfFiles:starPaths options:options error:&error];
    
    skybox = [[GLKSkyboxEffect alloc] init];
    skybox.label = @"Stars";
    skybox.xSize = skybox.ySize = skybox.zSize = 40;
    skybox.textureCubeMap.name = starTexture.name;
    
    NSLog(@"sky = %d, err = %@", starTexture.name, error);
    
    // set as scene
    _sceneRoot = [self createBlueMarble];
    
    //SetupGeometryVisitor * setupVisitor = [[SetupGeometryVisitor alloc] init];
    //[self.sceneRoot accept: setupVisitor];
    
    [self update];
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:context];
    
    ReleaseGeometryVisitor * releaseVisitor = [[ReleaseGeometryVisitor alloc] init];
    [self.sceneRoot accept: releaseVisitor];
    
    effect = nil;
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    [manipulator update];

    // calculate min/max scene distance
    GLKVector3 center = GLKMatrix4MultiplyAndProjectVector3(manipulator.camera.modelViewMatrix, self.sceneRoot.bound.center);
    float minDistance = MAX( -center.z - self.sceneRoot.bound.radius*2, 0.0001f );
    float maxDistance = -center.z + self.sceneRoot.bound.radius*2;
    //NSLog(@"Z Buffer: %f - %f", minDistance, maxDistance);
        
    // update projection
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, minDistance, maxDistance);
    
    manipulator.camera.projectionMatrix = projectionMatrix;
    manipulator.camera.viewport = self.view.bounds;
    
    skybox.transform.projectionMatrix = projectionMatrix;
    skybox.transform.modelviewMatrix = manipulator.camera.modelViewMatrix;
        
    [pager updateSceneGraph];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.0f, 0.0f, 0.1f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // render the skybox
    glDisable(GL_DEPTH_TEST);
    [skybox prepareToDraw];
    [skybox draw];
    glEnable(GL_DEPTH_TEST);
    glClear(GL_DEPTH_BUFFER_BIT);
    
    // run the render visitor
    [renderVisitor clear];
    [self.sceneRoot accept: renderVisitor];
    [renderVisitor renderWithEffect: effect];
    
    // check for errors
    GLenum err = glGetError();
    if ( err != GL_NO_ERROR ) {
        NSLog(@"glGetError = %d", err);
    }
}

@end
