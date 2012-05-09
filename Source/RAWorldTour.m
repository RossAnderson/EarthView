//
//  RAWorldTour.m
//  EarthViewExample
//
//  Created by Ross Anderson on 5/6/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#import "RAWorldTour.h"
#import "TPPropertyAnimation.h"


@implementation RAWorldTour {
    NSTimer * timer;
}

@synthesize manipulator;

- (void)start:(id)sender {
    timer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(next:) userInfo:nil repeats:YES];
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
    double duration = 5;
    double lat = -90 + ((double)rand() / RAND_MAX * 180.);
    double lon = -180 + ((double)rand() / RAND_MAX * 360.);
    
    TPPropertyAnimation *anim1 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"latitude"];
    anim1.duration = duration;
    anim1.fromValue = [NSNumber numberWithDouble:manipulator.latitude];
    anim1.toValue = [NSNumber numberWithDouble:lat];
    anim1.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim1 beginWithTarget:self.manipulator];
    
    TPPropertyAnimation *anim2 = [TPPropertyAnimation propertyAnimationWithKeyPath:@"longitude"];
    anim2.duration = duration;
    anim2.fromValue = [NSNumber numberWithDouble:manipulator.longitude];
    anim2.toValue = [NSNumber numberWithDouble:lon];
    anim2.timing = TPPropertyAnimationTimingEaseInEaseOut;
    [anim2 beginWithTarget:self.manipulator];
}

@end
