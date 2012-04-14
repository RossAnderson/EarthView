//
//  RAGeographicUtils.c
//  RASceneGraphTest
//
//  Created by Ross Anderson on 2/26/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include "RAGeographicUtils.h"

#include <stdio.h>
#include <math.h>

// implementation based on OpenSceneGraph: CoordinateSystemNode

const double ECEF_SCALE = 1e-6;
const double WGS_84_RADIUS_EQUATOR = 6378137.0 * ECEF_SCALE;
const double WGS_84_RADIUS_POLAR = 6356752.3142 * ECEF_SCALE;

const double WGS_84_FLATTENING = (WGS_84_RADIUS_EQUATOR-WGS_84_RADIUS_POLAR)/WGS_84_RADIUS_EQUATOR;
const double WGS_84_ECCENTRICITY_SQUARED = 2*WGS_84_FLATTENING - WGS_84_FLATTENING*WGS_84_FLATTENING;

// create a matrix to transform a unit sphere
const GLKMatrix4 UNIT_SPHERE_TO_WGS_84 = {
    WGS_84_RADIUS_EQUATOR, 0, 0, 0, 
    0, WGS_84_RADIUS_EQUATOR, 0, 0, 
    0, 0, WGS_84_RADIUS_POLAR, 0, 
    0, 0, 0, 1 };
const GLKMatrix4 WGS_84_TO_UNIT_SPHERE = {
    1./WGS_84_RADIUS_EQUATOR, 0, 0, 0, 
    0, 1./WGS_84_RADIUS_EQUATOR, 0, 0, 
    0, 0, 1./WGS_84_RADIUS_POLAR, 0, 
    0, 0, 0, 1 };

const double DEG_TO_RAD = M_PI / 180.;
const double RAD_TO_DEG = 180. / M_PI;

double ConvertHeightToEcef( double height ) {
    return height * ECEF_SCALE;
}

double ConvertHeightAboveGroundToEcef( double height ) {
    return (height + WGS_84_RADIUS_POLAR) * ECEF_SCALE;
}

double ConvertEcefToHeight( double length ) {
    return length / ECEF_SCALE;
}

GLKVector3 ConvertPolarToEcef( RAPolarCoordinate polar )
{
    // convert to radians
    polar.latitude *= DEG_TO_RAD;
    polar.longitude *= DEG_TO_RAD;
    polar.height *= ECEF_SCALE;
    
    // for details on maths see http://www.colorado.edu/geography/gcraft/notes/datum/gif/llhxyz.gif
    double sin_latitude = sin(polar.latitude);
    double cos_latitude = cos(polar.latitude);
    double N = WGS_84_RADIUS_EQUATOR / sqrt( 1.0 - WGS_84_ECCENTRICITY_SQUARED*sin_latitude*sin_latitude);
    
    GLKVector3 ecef;
    ecef.x = (N+polar.height)*cos_latitude*cos(polar.longitude);
    ecef.y = (N+polar.height)*cos_latitude*sin(polar.longitude);
    ecef.z = (N*(1-WGS_84_ECCENTRICITY_SQUARED)+polar.height)*sin_latitude;
    
    return ecef;
}

RAPolarCoordinate ConvertEcefToPolar( GLKVector3 ecef )
{
    // http://www.colorado.edu/geography/gcraft/notes/datum/gif/xyzllh.gif
    double p = sqrt(ecef.x*ecef.x + ecef.y*ecef.y);
    double theta = atan2(ecef.z*WGS_84_RADIUS_EQUATOR , (p*WGS_84_RADIUS_POLAR));
    double eDashSquared = (WGS_84_RADIUS_EQUATOR*WGS_84_RADIUS_EQUATOR - WGS_84_RADIUS_POLAR*WGS_84_RADIUS_POLAR)/
    (WGS_84_RADIUS_POLAR*WGS_84_RADIUS_POLAR);
    
    double sin_theta = sin(theta);
    double cos_theta = cos(theta);
    
    RAPolarCoordinate polar;
    polar.latitude = atan( (ecef.z + eDashSquared*WGS_84_RADIUS_POLAR*sin_theta*sin_theta*sin_theta) /
                    (p - WGS_84_ECCENTRICITY_SQUARED*WGS_84_RADIUS_EQUATOR*cos_theta*cos_theta*cos_theta) );
    polar.longitude = atan2(ecef.y,ecef.x);
    
    double sin_latitude = sin(polar.latitude);
    double N = WGS_84_RADIUS_EQUATOR / sqrt( 1.0 - WGS_84_ECCENTRICITY_SQUARED*sin_latitude*sin_latitude);
    
    polar.height = p/cos(polar.latitude) - N;
    
    // convert to degrees
    polar.latitude *= RAD_TO_DEG;
    polar.longitude *= RAD_TO_DEG;
    polar.height *= 1./ECEF_SCALE;
    
    return polar;
}

GLKMatrix4 CoordinateFrameForPolar( RAPolarCoordinate polar )
{
    // convert to radians
    polar.latitude *= DEG_TO_RAD;
    polar.longitude *= DEG_TO_RAD;
    
    // Compute up vector
    GLKVector3 up = GLKVector3Make( cos(polar.longitude)*cos(polar.latitude), sin(polar.longitude)*cos(polar.latitude), sin(polar.latitude));
    
    // Compute east vector
    GLKVector3 east = GLKVector3Make(-sin(polar.longitude), cos(polar.longitude), 0);
    
    // Compute north vector = outer product up x east
    GLKVector3 north = GLKVector3CrossProduct( up, east );
    

    // set transform basis
    GLKMatrix4 coordinateFrame = GLKMatrix4Identity;

    coordinateFrame.m00 = east.x;
    coordinateFrame.m01 = east.y;
    coordinateFrame.m02 = east.z;
    
    coordinateFrame.m10 = north.x;
    coordinateFrame.m11 = north.y;
    coordinateFrame.m12 = north.z;
    
    coordinateFrame.m20 = up.x;
    coordinateFrame.m21 = up.y;
    coordinateFrame.m22 = up.z;
    
    return coordinateFrame;
}

bool IntersectWithEllipsoid( GLKVector3 start, GLKVector3 end, GLKVector3* hit )
{
    // transform endpoints into unit sphere basis
    start = GLKMatrix4MultiplyAndProjectVector3(WGS_84_TO_UNIT_SPHERE, start);
    end = GLKMatrix4MultiplyAndProjectVector3(WGS_84_TO_UNIT_SPHERE, end);
    
    // use unit sphere
    const double r = 1.;
    
    GLKVector3 diff = GLKVector3Subtract(end, start);
    
    // calculate quadratic components
    double a = GLKVector3DotProduct( diff, diff );
    double b = GLKVector3DotProduct( GLKVector3MultiplyScalar(diff, 2.0), start );
    double c = GLKVector3DotProduct( start, start ) - ( r * r );
        
    // calculate discriminant
    double disc = ( b * b ) - ( 4.0 * a * c );
    
    // consider intersection for positive disc only (discard edge cases)
    if ( disc > 0.0 ) {
        // calculate two solutions
        double t1 = ( -b - sqrt(disc) ) / ( 2.0 * a );
        double t2 = ( -b + sqrt(disc) ) / ( 2.0 * a );
        
        // calculate points of intersection and normals
        if ( t1 > 0.0 && t1 < 1.0 ) {
            if ( hit ) {
                *hit = GLKVector3Add( start, GLKVector3MultiplyScalar(diff, t1));
                *hit = GLKMatrix4MultiplyAndProjectVector3(UNIT_SPHERE_TO_WGS_84, *hit);
            }
            
            return true;
        }
        
        if ( t2 > 0.0 && t2 < 1.0 ) {
            if ( hit ) {
                *hit = GLKVector3Add( start, GLKVector3MultiplyScalar(diff, t2));
                *hit = GLKMatrix4MultiplyAndProjectVector3(UNIT_SPHERE_TO_WGS_84, *hit);
            }
            
            return true;
        }
    }
    
    return false;
}

