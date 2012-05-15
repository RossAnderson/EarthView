//
//  RASceneGraphController.m
//  RASceneGraphTest
//
//  Created by Ross Anderson on 2/19/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RASceneGraphController.h"

#import <GLKit/GLKit.h>
#import <QuartzCore/QuartzCore.h>

#import "RABoundingSphere.h"
#import "RANodeVisitor.h"
#import "RARenderVisitor.h"
#import "RAGeographicUtils.h"

#import "RAManipulator.h"
#import "RATileDatabase.h"
#import "RATilePager.h"
#import "RAWorldTour.h"


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
    RARenderVisitor *   _renderVisitor;
    RAManipulator *     _manipulator;
    RAWorldTour *       _tourController;
    
    EAGLContext *       _context;
    GLKSkyboxEffect *   _skybox;
    CADisplayLink *     _displayLink;
    
    BOOL                _needsDisplay;
}

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation RASceneGraphController

@synthesize sceneRoot = _sceneRoot;
@synthesize camera = _camera;
@synthesize pager = _pager;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // !!! why does this cause gestures to fail?
        //self.preferredFramesPerSecond = 60;
        
        _camera = [RACamera new];
        _camera.projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), 1, 1, 100);
        _camera.modelViewMatrix = GLKMatrix4Identity;
        
        _manipulator = [RAManipulator new];
        _manipulator.camera = self.camera;

        _renderVisitor = [RARenderVisitor new];
        _renderVisitor.camera = self.camera;

        RATileDatabase * database = [RATileDatabase new];
        database.bounds = CGRectMake( -180,-90,360,180 );
        database.googleTileConvention = YES;
        
        // OpenStreetMap default tiles
        database.baseUrlStrings = [NSArray arrayWithObject: @"http://a.tile.openstreetmap.org/{z}/{x}/{y}.png"];
        database.minzoom = 2;
        database.maxzoom = 18;
        
        // setup the database pager
        _pager = [RATilePager new];
        _pager.imageryDatabase = database;
        _pager.camera = self.camera;
        
        _needsDisplay = YES;
}
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
        
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = _context;
    view.delegate = self;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.drawableMultisample = GLKViewDrawableMultisample4X;
    
    _manipulator.view = self.view;
    
    // setup display link to update the view
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    // create another context for threaded operations
    self.pager.auxilliaryContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:[_context sharegroup]];
    
    // add world tour
    _tourController = [RAWorldTour new];
    _tourController.manipulator = _manipulator;

    UITapGestureRecognizer * recognizer = [[UITapGestureRecognizer alloc] initWithTarget:_tourController action:@selector(startOrStop:)];
	[recognizer setNumberOfTapsRequired:4];
	[self.view addGestureRecognizer:recognizer];
    //[tourController start: self];

    [self.pager setup];
    [self setupGL];
}

- (void)viewDidUnload
{    
    [super viewDidUnload];
    
    [self tearDownGL];
    [_displayLink invalidate];
    
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
	_context = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
    [RATextureWrapper cleanupAll: YES];
    [RAGeometry cleanupAll: YES];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    _needsDisplay = YES;
}

- (void)displayLinkUpdate:(CADisplayLink *)sender {
    GLKView *view = (GLKView *)self.view;
    
    BOOL manipulatorMoved = [_manipulator needsDisplay];
    
    _needsDisplay |= manipulatorMoved;
    _needsDisplay |= [_pager needsDisplay];

    if ( _needsDisplay ) {
        [self update];
        [view display];
    }
    
    if ( manipulatorMoved ) {
        [_pager updateIfNeeded];
    }

    _needsDisplay = NO;
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
    [root addChild: self.pager.rootNode];
        
    return root;
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:_context];
        
    glEnable(GL_DEPTH_TEST);
    
    glEnable(GL_BLEND);
    glBlendFunc( GL_ONE, GL_ONE_MINUS_SRC_ALPHA );
    
    // setup skybox
    NSString * starPath = [[NSBundle mainBundle] pathForResource:@"star1" ofType:@"png"];
    NSArray * starPaths = [NSArray arrayWithObjects: starPath, starPath, starPath, starPath, starPath, starPath, nil];
    NSError * error = nil;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
     [NSNumber numberWithBool:YES], GLKTextureLoaderOriginBottomLeft,
     [NSNumber numberWithBool:YES], GLKTextureLoaderGenerateMipmaps,
     nil];
    GLKTextureInfo * starTexture = [GLKTextureLoader cubeMapWithContentsOfFiles:starPaths options:options error:&error];

    _skybox = [[GLKSkyboxEffect alloc] init];
    _skybox.label = @"Stars";
    _skybox.xSize = _skybox.ySize = _skybox.zSize = 40;
    _skybox.textureCubeMap.name = starTexture.name;
    
    // set as scene
    _sceneRoot = [self createBlueMarble];
    
    [self update];
    [_renderVisitor setupGL];
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:_context];
    
    ReleaseGeometryVisitor * releaseVisitor = [[ReleaseGeometryVisitor alloc] init];
    [self.sceneRoot accept: releaseVisitor];
    
    [_renderVisitor tearDownGL];
}

- (void)update
{
    self.camera.modelViewMatrix = [_manipulator modelViewMatrix];
    
    // position light directly above the globe
    RAPolarCoordinate lightPolar = {
        _manipulator.latitude, _manipulator.longitude, 1e7
    };
    GLKVector3 lightEcef = ConvertPolarToEcef( lightPolar );
    _renderVisitor.lightPosition = lightEcef;
    
    // !!! the scene view bound is incorrect
    
    // calculate min/max scene distance
    GLKVector3 center = GLKMatrix4MultiplyAndProjectVector3(self.camera.modelViewMatrix, self.sceneRoot.bound.center);
    float minDistance = -center.z - self.sceneRoot.bound.radius;
    float maxDistance = -center.z + self.sceneRoot.bound.radius;
    //NSLog(@"Z Buffer: %f - %f, Scene Radius: %f", minDistance, maxDistance, self.sceneRoot.bound.radius);
    if ( minDistance < 0.001f ) minDistance = 0.001f;
    if ( maxDistance < 60.0f ) maxDistance = 60.0f; // room for skybox
    
    // update projection
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, minDistance, maxDistance);
    
    self.camera.projectionMatrix = projectionMatrix;
    self.camera.viewport = self.view.bounds;
    
    _skybox.transform.projectionMatrix = projectionMatrix;
    _skybox.transform.modelviewMatrix = self.camera.modelViewMatrix;
}

#pragma mark - GLKView delegate methods

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glClearColor(0.0f, 0.2f, 0.0f, 1.0f);
    
    // render the skybox
    [_skybox prepareToDraw];
    [_skybox draw];
    
    // run the render visitor
    [_renderVisitor clear];
    [self.sceneRoot accept: _renderVisitor];
    [_renderVisitor render];
    
    // check for errors
    GLenum err = glGetError();
    switch( err ) {
        case GL_NO_ERROR:                                                       break;
        case GL_INVALID_ENUM:       NSLog(@"glGetError: invalid enum");         break;
        case GL_INVALID_VALUE:      NSLog(@"glGetError: invalid value");        break;
        case GL_INVALID_OPERATION:  NSLog(@"glGetError: invalid operation");    break;
        case GL_STACK_OVERFLOW:     NSLog(@"glGetError: stack overflow");       break;
        case GL_STACK_UNDERFLOW:    NSLog(@"glGetError: stack underflow");      break;
        case GL_OUT_OF_MEMORY:      NSLog(@"glGetError: out of memory");        break;
        default:        NSLog(@"glGetError: unknown error = 0x%04X", err);      break;
    }
    
    [RATextureWrapper cleanupAll:NO];
    [RAGeometry cleanupAll:NO];
}

@end
