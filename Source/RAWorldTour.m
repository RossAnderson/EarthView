//
//  RAWorldTour.m
//  EarthViewExample
//
//  Created by Ross Anderson on 5/6/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAWorldTour.h"
#import "TPPropertyAnimation.h"

static const double kAnimationDuration = 5;

@interface RAWorldTour (PrivateMethods)
- (void)next:(id)sender;
@end

@implementation RAWorldTour {
    NSTimer * timer;
}

@synthesize manipulator;

- (void)start:(id)sender {
    timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(next:) userInfo:nil repeats:YES];

    TPPropertyAnimation *anim1 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"distance"];
    anim1.duration = kAnimationDuration;
    anim1.fromValue = [NSNumber numberWithDouble:manipulator.distance];
    anim1.toValue = [NSNumber numberWithDouble:5e5];
    anim1.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim1 beginWithTarget:self.manipulator];

    TPPropertyAnimation *anim2 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"elevation"];
    anim2.duration = kAnimationDuration;
    anim2.fromValue = [NSNumber numberWithDouble:manipulator.elevation];
    anim2.toValue = [NSNumber numberWithDouble:80];
    anim2.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim2 beginWithTarget:self.manipulator];

    [self next:sender];
}

- (void)stop:(id)sender {
    [timer invalidate];
    timer = nil;
}

- (void)startOrStop:(id)sender {
    if ( timer )
        [self stop:sender];
    else
        [self start:sender];
}

- (void)next:(id)sender {
    double lat = -90 + ((double)rand() / RAND_MAX * 180.);
    double lon = -180 + ((double)rand() / RAND_MAX * 360.);
    
    TPPropertyAnimation *anim1 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"latitude"];
    anim1.duration = kAnimationDuration;
    anim1.fromValue = [NSNumber numberWithDouble:manipulator.latitude];
    anim1.toValue = [NSNumber numberWithDouble:lat];
    anim1.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim1 beginWithTarget:self.manipulator];
    
    TPPropertyAnimation *anim2 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"longitude"];
    anim2.duration = kAnimationDuration;
    anim2.fromValue = [NSNumber numberWithDouble:manipulator.longitude];
    anim2.toValue = [NSNumber numberWithDouble:lon];
    anim2.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim2 beginWithTarget:self.manipulator];
}

@end
