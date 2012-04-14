//
//  RAGeographicUtils.h
//  RASceneGraphTest
//
//  Created by Ross Anderson on 2/26/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#ifndef RASceneGraphTest_RAGeographicUtils_h
#define RASceneGraphTest_RAGeographicUtils_h

#include <GLKit/GLKMathTypes.h>
#include <GLKit/GLKVector3.h>
#include <GLKit/GLKMatrix4.h>

extern const double WGS_84_RADIUS_EQUATOR;
extern const double WGS_84_RADIUS_POLAR;

typedef struct {
    double latitude;    // degrees north from equator
    double longitude;   // degrees east from prime meridian
    double height;      // above ellipsoid
} RAPolarCoordinate;

double ConvertHeightToEcef( double height );
double ConvertEcefToHeight( double length );
double ConvertHeightAboveGroundToEcef( double height );

GLKVector3 ConvertPolarToEcef( RAPolarCoordinate polar );
RAPolarCoordinate ConvertEcefToPolar( GLKVector3 ecef );

GLKMatrix4 CoordinateFrameForPolar( RAPolarCoordinate polar );

bool IntersectWithEllipsoid( GLKVector3 start, GLKVector3 end, GLKVector3* hit );

#endif
