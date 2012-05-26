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

#import "RATileDatabase.h"
#import "RATilePager.h"


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
    
    EAGLContext *       _context;
    GLKSkyboxEffect *   _skybox;
    CADisplayLink *     _displayLink;
    
    BOOL                _needsDisplay;
    BOOL                _needsUpdate;
}

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation RASceneGraphController

@synthesize context = _context;
@synthesize sceneRoot = _sceneRoot;
@synthesize camera = _camera;
@synthesize pager = _pager;
@synthesize manipulator = _manipulator;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // setup scene
        _camera = [RACamera new];
        
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
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [_manipulator addGesturesToView: self.view];
        
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!_context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = _context;
    view.delegate = self;
    view.enableSetNeedsDisplay = NO;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    //view.drawableMultisample = GLKViewDrawableMultisample4X;
        
    // setup display link to update the view
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    // setup auxillary context for threaded texture loading operations
    if ( ! _pager.auxilliaryContext ) _pager.auxilliaryContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:[_context sharegroup]];
    [_pager setup];
    
    // register for notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayNotification:) name:RAManipulatorStateChangedNotification object:_manipulator];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayNotification:) name:RATilePagerContentChangedNotification object:_pager];
    
    [self setupGL];
    [self update];
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
    if ( self.view.window.screen && self.view.window.screen != [UIScreen mainScreen] )
        return NO;
    
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
    if ( _needsUpdate ) {
        [_pager requestUpdate];
        _needsUpdate = NO;
    }
    
    if ( _needsDisplay ) {
        GLKView *view = (GLKView *)self.view;
        
        [self update];
        [view display];
        
        _needsDisplay = NO;
    }
}

- (void)displayNotification:(NSNotification *)note {
    if ( [[note name] isEqualToString:RAManipulatorStateChangedNotification] )
        _needsUpdate = YES;
    
    _needsDisplay = YES;
}

#pragma mark - Scene Graph

- (RANode *)createSceneGraphForPager:(RATilePager *)pager
{
    RAGroup * root = [RAGroup new];
    
    for( RAPage * page in pager.rootPages ) {
        RAPageNode * node = [RAPageNode new];
        node.page = page;
        [root addChild:node];
    }
        
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
    _sceneRoot = [self createSceneGraphForPager:_pager];
    
    [self update];
    [_renderVisitor setupGL];
    
    _needsUpdate = YES;
    _needsDisplay = YES;
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
        
    self.camera.viewport = self.view.bounds;
    [_camera calculateProjectionForBounds: self.sceneRoot.bound];
    
    // update skybox projection
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(_camera.fieldOfView), aspect, 10, 50);
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
    
    glClear(GL_DEPTH_BUFFER_BIT);

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
