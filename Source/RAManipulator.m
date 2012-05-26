//
//  RAManipulator.m
//  RASceneGraphTest
//
//  Created by Ross Anderson on 3/4/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAManipulator.h"

#import "TPPropertyAnimation.h"

static const RAPolarCoordinate kFreshPondCoord = { 42.384733, -71.149392, 1e7 };
static const RAPolarCoordinate kPolarNone = { -1, -1, -1 };
static const RAPolarCoordinate kPolarZero = { 0, 0, 0 };
static const RAPolarCoordinate kDefaultVelocity = { 0, -10, 0 };

static const CGFloat kAnimationDuration = 1.0f;
static const CGFloat kMinimumAnimatedAngle = 2.0f;


typedef struct {
    double  latitude;      // all angles in degrees
    double  longitude;
    double  azimuth;
    double  elevation;
    double  distance;
} CameraState;

typedef enum {
    GestureNone = 0,
    GestureGeoDrag,
    GestureAxisSpin,
    GestureRotate,
    GestureTilt
} GestureAction;


@implementation RAManipulator {
    CameraState     _state;
    
    BOOL            _needsDisplay;
}

@synthesize camera;

- (id)init
{
    self = [super init];
    if (self) {
        _needsDisplay = YES;
    }
    return self;
}

- (void)addGesturesToView:(UIView *)view {
    self.latitude = kFreshPondCoord.latitude;
    self.longitude = kFreshPondCoord.longitude;
    self.distance = kFreshPondCoord.height;
    self.azimuth = 0;
    self.elevation = 90;
    
    // add gestures
    UIPinchGestureRecognizer * pinchRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(scale:)];
	[pinchRecognizer setDelegate:self];
	[view addGestureRecognizer:pinchRecognizer];
    
	UIPanGestureRecognizer * panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(move:)];
	[panRecognizer setDelegate:self];
	[view addGestureRecognizer:panRecognizer];
    
	UITapGestureRecognizer * zoomRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(zoomToLocation:)];
	[zoomRecognizer setNumberOfTapsRequired:2];
	[zoomRecognizer setDelegate:self];
	[view addGestureRecognizer:zoomRecognizer];
        
	UITapGestureRecognizer * stopRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(stop:)];
	[stopRecognizer setNumberOfTapsRequired:1];
	[stopRecognizer setDelegate:self];
	[view addGestureRecognizer:stopRecognizer];

    _needsDisplay = YES;
}

- (double)latitude {
    return _state.latitude;
}

- (void)setLatitude:(double)latitude {
    NSAssert( !isnan(latitude), @"angle cannot be NAN" );
    
    _state.latitude = NormalizeLatitude(latitude);
    _needsDisplay = YES;
}

- (double)longitude {
    return _state.longitude;
}

- (void)setLongitude:(double)longitude {
    NSAssert( !isnan(longitude), @"angle cannot be NAN" );
    
    _state.longitude = NormalizeLongitude(longitude);
    _needsDisplay = YES;
}

- (double)azimuth {
    return _state.azimuth;
}

- (void)setAzimuth:(double)azimuth {
    NSAssert( !isnan(azimuth), @"angle cannot be NAN" );

    _state.azimuth = NormalizeLongitude(azimuth);
    _needsDisplay = YES;
}

- (double)elevation {
    return _state.elevation;
}

- (void)setElevation:(double)elevation {
    NSAssert( !isnan(elevation), @"angle cannot be NAN" );
    if ( elevation <  0. ) elevation =  0.;
    if ( elevation > 90. ) elevation = 90.;
    
    _state.elevation = elevation;
    _needsDisplay = YES;
}

- (double)distance {
    return _state.distance;
}

- (void)setDistance:(double)distance {
    NSAssert( !isnan(distance), @"distance cannot be NAN" );
    if ( distance < 200. ) distance = 200.;
    if ( distance > 1.e7 ) distance = 1.e7;
    
    _state.distance = distance;
    _needsDisplay = YES;
}

- (BOOL)needsDisplay {
    BOOL flag = _needsDisplay;
    _needsDisplay = NO;
    return flag;
}

/*
- (NSString *)stringFromMatrix:(GLKMatrix4)m {
    return [NSString stringWithFormat:@"%f %f %f %f,\n%f %f %f %f,\n%f %f %f %f,\n%f %f %f %f",
            m.m00, m.m01, m.m02, m.m03,
            m.m10, m.m11, m.m12, m.m13,
            m.m20, m.m21, m.m22, m.m23,
            m.m30, m.m31, m.m32, m.m33];
}
*/

- (GLKMatrix4)modelViewMatrixForState:(CameraState)aState {
    RAPolarCoordinate   surfaceCoord = { self.latitude, self.longitude, 0 };
    GLKVector3          surfacePos = ConvertPolarToEcef(surfaceCoord);
    
    GLKMatrix4 surfaceTransform = GLKMatrix4MakeLookAt(surfacePos.x, surfacePos.y, surfacePos.z, 0, 0, 0, 0, 0, 1);
    
    GLKMatrix4 perspective = GLKMatrix4Identity;
    perspective = GLKMatrix4Translate(perspective, 0, 0, ConvertHeightToEcef(-self.distance));
    perspective = GLKMatrix4Rotate(perspective,  (90.-self.elevation) * (M_PI/180.), -1, 0, 0);
    perspective = GLKMatrix4Rotate(perspective, self.azimuth * (M_PI/180.), 0, 0, 1);
    
    GLKMatrix4 modelView = GLKMatrix4Multiply(perspective, surfaceTransform);
    //NSLog(@"ModelView: %@", [self stringFromMatrix:renderVisitor.projectionMatrix], [self stringFromMatrix:modelView]);

    return modelView;
}

- (BOOL)intersectPoint:(CGPoint)point atLatitude:(double*)lat atLongitude:(double*)lon withState:(CameraState)aState
{
    GLKVector3 swin = { point.x, point.y, 0 };
    GLKVector3 ewin = { point.x, point.y, 1 };
    int        viewport[4] = { self.camera.viewport.origin.x, self.camera.viewport.origin.y + self.camera.viewport.size.height, self.camera.viewport.size.width, -self.camera.viewport.size.height };
    GLKMatrix4 modelViewMatrix = [self modelViewMatrixForState:aState];
        
    bool startValid, endValid;
    GLKVector3 start = GLKMathUnproject ( swin, modelViewMatrix, self.camera.projectionMatrix, viewport, &startValid );
    GLKVector3 end = GLKMathUnproject ( ewin, modelViewMatrix, self.camera.projectionMatrix, viewport, &endValid );
    
    if ( startValid && endValid ) {
        // find intersection
        GLKVector3 position;
        if ( IntersectWithEllipsoid( start, end, &position ) ) {
            RAPolarCoordinate coord = ConvertEcefToPolar(position);
            if ( lat ) *lat = coord.latitude;
            if ( lon ) *lon = coord.longitude;
            return YES;
        }
    }
    
    return NO;
}

- (GLKMatrix4)modelViewMatrix {
    return [self modelViewMatrixForState:_state];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // allow user to pan and zoom at the same time
    if ( [gestureRecognizer isKindOfClass:[UIPinchGestureRecognizer class]] && [otherGestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] )
        return YES;
    
    return NO;
}

- (void)scale:(id)sender {
    UIPinchGestureRecognizer * pinch = (UIPinchGestureRecognizer*)sender;
    
    static CameraState startState;
    static CGFloat startScale = 1;
    
    switch( [pinch state] ) {
        case UIGestureRecognizerStatePossible:
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            _state = startState;
            _needsDisplay = YES;
            break;
        case UIGestureRecognizerStateBegan:
            [self stop:nil];

            startState = _state;
            startScale = pinch.scale;
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGFloat ds = startScale / pinch.scale;
            self.distance = ds * startState.distance;
            
            //NSLog(@"distance = %f", _state.distance);
            break;
        }
        case UIGestureRecognizerStateEnded:
        {
            /*
            // calculate how much movement
            CGFloat distance = _state.distance / pinch.velocity;
            if ( fabs(distance) < _state.distance / 10. ) break;
            
            TPPropertyAnimation *anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"distance"];
            anim.duration = kAnimationDuration;
            anim.fromValue = [NSNumber numberWithDouble:_state.distance];
            anim.toValue = [NSNumber numberWithDouble:_state.distance - distance];
            anim.timing = TPPropertyAnimationTimingEaseOut;
            [anim beginWithTarget:self];
            */
            break;
        }
    }
}

- (void)move:(id)sender {
    UIPanGestureRecognizer * pan = (UIPanGestureRecognizer*)sender;
    UIView * view = pan.view;
    
    static GestureAction sAction;
    static CGPoint startLocation;
    static CameraState startState;
    static double cursorLatitude, cursorLongitude;
    static int touchCount;
    
    CGPoint pt = [pan locationInView:view];

    switch( [pan state] ) {
        case UIGestureRecognizerStatePossible:
            break;
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            _state = startState;
            _needsDisplay = YES;
            break;
        case UIGestureRecognizerStateBegan:
        {
            [self stop:nil];

            CGFloat yThresh = view.bounds.size.height / 10.;
            CGFloat xThresh = view.bounds.size.width / 10.;

            // pick the right gesture
            if ( pt.y > view.bounds.size.height - yThresh ) 
                sAction = GestureRotate;
            else if ( pt.x > view.bounds.size.width - xThresh )
                sAction = GestureTilt;
            else {
                // get the current touch position on the globe
                if ( [self intersectPoint:pt atLatitude:&cursorLatitude atLongitude:&cursorLongitude withState:_state] )
                    sAction = GestureGeoDrag;
                else
                    sAction = GestureAxisSpin;
            }
                        
            startLocation = pt;
            startState = _state;
            touchCount = [pan numberOfTouches];
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            // ignore change if it's because one of the fingers lifted
            if ( [pan numberOfTouches] != touchCount ) {
                break;
            }
            
            switch (sAction) {
                case GestureRotate:
                {
                    double angle = ( pt.x - startLocation.x ) * 0.1;
                    self.azimuth = startState.azimuth + angle;
                    break;
                }
                case GestureTilt:
                {
                    double angle = ( pt.y - startLocation.y ) * 0.1;
                    self.elevation = startState.elevation + angle;
                    break;
                }
                case GestureGeoDrag:
                {
                    double lat, lon;
                    if ( [self intersectPoint:pt atLatitude:&lat atLongitude:&lon withState:_state] ) {
                        // rotate the globe so cursor is under the touch again
                        self.latitude -= lat - cursorLatitude;
                        self.longitude -= lon - cursorLongitude;
                        
                        //NSLog(@"lat = %f, lon = %f", _state.latitude, _state.longitude);
                    }
                    break;
                }
                case GestureAxisSpin:
                {
                    double angle = -( pt.x - startLocation.x ) * 0.1;
                    self.longitude = startState.longitude + angle;
                    break;
                }
                case GestureNone: break;
            }
            break;
        }
        case UIGestureRecognizerStateEnded:
        {
            CGPoint vel = [pan velocityInView:view];
            
            switch (sAction) {
                case GestureRotate:
                {
                    // calculate how much movement
                    CGFloat angle = vel.x * 0.03;
                    if ( fabs(angle) < kMinimumAnimatedAngle ) break;

                    TPPropertyAnimation *anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"azimuth"];
                    anim.duration = kAnimationDuration;
                    anim.fromValue = [NSNumber numberWithDouble:_state.azimuth];
                    anim.toValue = [NSNumber numberWithDouble:_state.azimuth + angle];
                    anim.timing = TPPropertyAnimationTimingEaseOut;
                    [anim beginWithTarget:self];
                    break;
                }
                case GestureTilt:
                {
                    // calculate how much movement
                    CGFloat angle = vel.y * 0.03;
                    if ( fabs(angle) < kMinimumAnimatedAngle ) break;
                    
                    TPPropertyAnimation *anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"elevation"];
                    anim.duration = kAnimationDuration;
                    anim.fromValue = [NSNumber numberWithDouble:_state.elevation];
                    anim.toValue = [NSNumber numberWithDouble:_state.elevation + angle];
                    anim.timing = TPPropertyAnimationTimingEaseOut;
                    [anim beginWithTarget:self];
                    break;
                }
                case GestureGeoDrag:
                {
                    // continue movement in the same direction
                    CGPoint dir = CGPointMake( _state.longitude - startState.longitude, _state.latitude - startState.latitude );
                    dir.x = NormalizeLongitude(dir.x);

                    CGFloat length = sqrt( dir.x*dir.x + dir.y*dir.y );
                    if ( length < 1 ) break;
                    dir.x /= length;
                    dir.y /= length;
                    
                    // calculate how much movement
                    CGFloat speed = sqrt( vel.x*vel.x + vel.y*vel.y );
                    CGFloat angle = ( _state.distance / 1e7 ) * speed * 0.03;
                    if ( fabs(angle) < kMinimumAnimatedAngle ) break;
                    
                    CGPoint destination = CGPointMake( _state.longitude + dir.x*angle, _state.latitude + dir.y*angle );
                    
                    // zoom to that location
                    TPPropertyAnimation *anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"latitude"];
                    anim.duration = kAnimationDuration;
                    anim.fromValue = [NSNumber numberWithDouble:_state.latitude];
                    anim.toValue = [NSNumber numberWithDouble:destination.y];
                    anim.timing = TPPropertyAnimationTimingEaseOut;
                    [anim beginWithTarget:self];
                    
                    anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"longitude"];
                    anim.duration = kAnimationDuration;
                    anim.fromValue = [NSNumber numberWithDouble:_state.longitude];
                    anim.toValue = [NSNumber numberWithDouble:destination.x];
                    anim.timing = TPPropertyAnimationTimingEaseOut;
                    [anim beginWithTarget:self];
                    
                    break;
                }
                case GestureAxisSpin:
                {
                    // calculate how much movement
                    CGFloat speed = vel.x;
                    CGFloat angle = -( _state.distance / 1e7 ) * speed * 0.1;
                    if ( fabs(angle) < kMinimumAnimatedAngle ) break;
                    
                    float destination = _state.longitude + angle;
                    
                    // spin the globe
                    TPPropertyAnimation *anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"longitude"];
                    anim.duration = kAnimationDuration * 2.0;
                    anim.fromValue = [NSNumber numberWithDouble:_state.longitude];
                    anim.toValue = [NSNumber numberWithDouble:destination];
                    anim.timing = TPPropertyAnimationTimingEaseOut;
                    [anim beginWithTarget:self];
                    
                    break;
                }
                case GestureNone: break;
            }
            
            sAction = GestureNone;
            break;
        }
    }
}

- (void)stop:(id)sender {
    // cancel animations in progress
    [[TPPropertyAnimation allPropertyAnimationsForTarget:self] makeObjectsPerformSelector:@selector(cancel)];

    //printf("Stop\n");
}

- (void)zoomToLocation:(id)sender {
    UITapGestureRecognizer * tap = (UITapGestureRecognizer*)sender;
    UIView * view = tap.view;
    
    CGPoint pt = [tap locationInView:view];
    double lat, lon;
    
    // get the current touch position on the globe
    [self intersectPoint:pt atLatitude:&lat atLongitude:&lon withState:_state];
    
    //printf("Zoom from %f %f to: %f %f\n", _state.latitude, _state.longitude, lat, lon);
    
    double duration = 1.0;

    // zoom in to that location
    TPPropertyAnimation *anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"latitude"];
    anim.duration = duration;
    anim.fromValue = [NSNumber numberWithDouble:_state.latitude];
    anim.toValue = [NSNumber numberWithDouble:lat];
    anim.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim beginWithTarget:self];

    anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"longitude"];
    anim.duration = duration;
    anim.fromValue = [NSNumber numberWithDouble:_state.longitude];
    anim.toValue = [NSNumber numberWithDouble:lon];
    anim.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim beginWithTarget:self];

    anim = [TPPropertyAnimation propertyAnimationWithKeyPath:@"distance"];
    anim.duration = duration;
    anim.fromValue = [NSNumber numberWithDouble:_state.distance];
    anim.toValue = [NSNumber numberWithDouble:_state.distance / 2.0];
    anim.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim beginWithTarget:self];
}


- (void)debugZoomInOut:(id)sender {
    double duration = 5.0;
    [self stop: nil];
    
    TPPropertyAnimation *anim1 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"distance"];
    anim1.target = self;
    anim1.duration = duration;
    anim1.fromValue = [NSNumber numberWithDouble:_state.distance];
    anim1.toValue = [NSNumber numberWithDouble:2000];
    anim1.timing = TPPropertyAnimationTimingEaseInEaseOut;

    TPPropertyAnimation *anim2 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"distance"];
    anim2.target = self;
    anim2.duration = duration;
    anim2.fromValue = [NSNumber numberWithDouble:2000];
    anim2.toValue = [NSNumber numberWithDouble:1000];
    anim2.timing = TPPropertyAnimationTimingEaseInEaseOut;
    
    TPPropertyAnimation *anim3 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"distance"];
    anim3.target = self;
    anim3.duration = duration;
    anim3.fromValue = [NSNumber numberWithDouble:1000];
    anim3.toValue = [NSNumber numberWithDouble:_state.distance];
    anim3.timing = TPPropertyAnimationTimingEaseInEaseOut;

    anim1.chainedAnimation = anim2;
    anim2.chainedAnimation = anim3;
    [anim1 beginWithTarget:self];
}

@end
