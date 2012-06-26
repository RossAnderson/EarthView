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
#import <CoreLocation/CoreLocation.h>

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
}

- (void)setupGL;
- (void)tearDownGL;

@end

@implementation RASceneGraphController

@synthesize context = _context;
@synthesize glView;
@synthesize flyToLocationField;
@synthesize statsLabel, clippingEnable, pagingEnable;
@synthesize sceneRoot = _sceneRoot;
@synthesize camera = _camera;
@synthesize pager = _pager;
@synthesize manipulator = _manipulator;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setupSceneObjects];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{
    [self setupSceneObjects];
}

- (void)setupSceneObjects
{
    // setup scene
    _camera = [RACamera new];
    
    _manipulator = [RAManipulator new];
    _manipulator.camera = self.camera;
    
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
    
    // setup scene
    [_pager setupPages];
    _sceneRoot = [self createSceneGraphForPager:_pager];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [statsLabel setText:nil];
    [_manipulator addGesturesToView: glView];
    
    // setup fly to location field
    UIImage * flyImage = [UIImage imageNamed:@"fly"];
    UIImageView * flyView = [[UIImageView alloc] initWithImage:flyImage];
    [flyToLocationField setLeftView:flyView];
    flyToLocationField.leftViewMode = UITextFieldViewModeAlways;
    
    UITapGestureRecognizer * tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self.flyToLocationField action:@selector(resignFirstResponder)];
    [glView addGestureRecognizer: tapGesture];
    flyToLocationField.userInteractionEnabled = YES;
    glView.userInteractionEnabled = YES;
    
    [self setContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]];
    if ( ! self.context ) {
        NSLog(@"Failed to create ES context");
    }
    
    // these should be set in the xib/storyboard
    //glView.delegate = self;
    //glView.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    //glView.drawableMultisample = GLKViewDrawableMultisample4X;
    
    // setup display link to update the view
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkUpdate:)];
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    // setup auxillary context for threaded texture loading operations
    if ( _pager && ! _pager.auxilliaryContext ) _pager.auxilliaryContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2 sharegroup:[_context sharegroup]];
    
    // register for notifications
    if ( _camera ) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayNotification:) name:RACameraStateChangedNotification object:_camera];
    if ( _pager ) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayNotification:) name:RATilePagerContentChangedNotification object:_pager];
    
    _needsDisplay = YES;
    [self setupGL];
    [_pager requestUpdate];
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
    // do not rotate if on an external display
    if ( [self isViewLoaded] && self.view.window.screen && self.view.window.screen != [UIScreen mainScreen] )
        return (interfaceOrientation == UIInterfaceOrientationPortrait);
    
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
    if ( _needsDisplay ) {
        [self update];
        [glView display];
        
        _needsDisplay = NO;
    }
}

- (void)displayNotification:(NSNotification *)note {
    [_pager requestUpdate];
    _needsDisplay = YES;
}

- (EAGLContext *)context {
    return _context;
}

- (void)setContext:(EAGLContext *)context {
    _context = context;
    glView.context = context;
}

- (IBAction)flyToLocationFrom:(id)sender {
    CLGeocoder * geocoder = [CLGeocoder new];
    UITextField * textField = (UITextField *)sender;
    
    textField.enabled = NO;
    NSString * address = [textField text];
    
    [geocoder geocodeAddressString:address completionHandler:^(NSArray *placemarks, NSError *error) {
        if ( placemarks ) {
            CLPlacemark * place = [placemarks objectAtIndex:0];
            [_manipulator flyToRegion: place.region];
        } else {
            textField.text = nil;
        }
        
        textField.enabled = YES;
        [geocoder cancelGeocode];   // this doesn't do anything, but it ensures that the geocoder is retained for this block
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldClear:(UITextField *)textField {
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self flyToLocationFrom:textField];
    return YES;
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
    [glView bindDrawable];
        
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_BLEND);
    glBlendFunc( GL_ONE, GL_ONE_MINUS_SRC_ALPHA );
    
    // setup skybox
    if ( ! _skybox ) {
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
    }
    
    // setup render visitor
    if ( ! _renderVisitor ) {
        _renderVisitor = [RARenderVisitor new];
        _renderVisitor.camera = self.camera;
        [_renderVisitor setupGL];
    }
    
    [_pager setupGL];
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
    if ( _manipulator ) {
        // position light directly above the globe
        RAPolarCoordinate lightPolar = {
            _manipulator.latitude, _manipulator.longitude, 1e7
        };
        GLKVector3 lightEcef = ConvertPolarToEcef( lightPolar );
        _renderVisitor.lightPosition = lightEcef;
    }
    
    self.camera.viewport = self.glView.bounds;
    [_camera calculateProjectionForBounds: self.sceneRoot.bound];
    
    // update skybox projection
    float aspect = fabsf(self.glView.bounds.size.width / self.glView.bounds.size.height);
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
    if ( clippingEnable == nil || clippingEnable.on ) {
        [_renderVisitor clear];
        [self.sceneRoot accept: _renderVisitor];
    }
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
    
    // show stats
    [statsLabel setText:_renderVisitor.statsString];
}

@end
