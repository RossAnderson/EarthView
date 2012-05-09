//
//  RAGeographicUtils.c
//  RASceneGraphTest
//
//  Created by Ross Anderson on 2/26/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

#include "RAGeographicUtils.h"

#include <stdio.h>
#include <math.h>

// implementation based on OpenSceneGraph: CoordinateSystemNode

// use the WGS84 ellipsoid, shrunk down to improve 32-bit float performance
const double kEcefScale = 1e-6;
const double kRadiusEquator = 6378137.0 * kEcefScale;
const double kRadiusPolar = 6356752.3142 * kEcefScale;

const double kEllipsoidFlattening = (kRadiusEquator-kRadiusPolar)/kRadiusEquator;
const double kEllipsoidEccentricitySquared = 2*kEllipsoidFlattening - kEllipsoidFlattening*kEllipsoidFlattening;
const double kEllipsoidEccentricityPrimeSquared = ( kRadiusEquator*kRadiusEquator - kRadiusPolar*kRadiusPolar ) / ( kRadiusPolar*kRadiusPolar );

// create a matrix to transform a unit sphere
const GLKMatrix4 kUnitSphereToEllipsoid = {
    kRadiusEquator, 0, 0, 0, 
    0, kRadiusEquator, 0, 0, 
    0, 0, kRadiusPolar, 0, 
    0, 0, 0, 1 };
const GLKMatrix4 kEllipsoidToUnitSphere = {
    1./kRadiusEquator, 0, 0, 0, 
    0, 1./kRadiusEquator, 0, 0, 
    0, 0, 1./kRadiusPolar, 0, 
    0, 0, 0, 1 };

const double DEG_TO_RAD = M_PI / 180.;
const double RAD_TO_DEG = 180. / M_PI;

double NormalizeLatitude( double deg )
{
    // latitude is capped to max
    if ( deg < -90. ) deg = -90.;
    if ( deg >  90. ) deg =  90.;
    return deg;
}

double NormalizeLongitude( double deg )
{
    // longitude wraps around
    while( deg < -180. ) deg +=  360.;
    while( deg >  180. ) deg += -360.;
    return deg;
}

double ConvertHeightToEcef( double height ) {
    return height * kEcefScale;
}

double ConvertHeightAboveGroundToEcef( double height ) {
    return (height + kRadiusPolar) * kEcefScale;
}

double ConvertEcefToHeight( double length ) {
    return length / kEcefScale;
}

GLKVector3 ConvertPolarToEcef( RAPolarCoordinate polar )
{
    // convert to radians
    polar.latitude *= DEG_TO_RAD;
    polar.longitude *= DEG_TO_RAD;
    polar.height *= kEcefScale;
    
    // calculate ellipsoid parameters based upon these equations:
    // http://www.colorado.edu/geography/gcraft/notes/datum/gif/llhxyz.gif
    
    double sin_latitude = sin( polar.latitude );
    double cos_latitude = cos( polar.latitude );
    double N = kRadiusEquator / sqrt( 1.0 - kEllipsoidEccentricitySquared * sin_latitude * sin_latitude );
    
    GLKVector3 ecef;
    ecef.x = ( N + polar.height ) * cos_latitude * cos(polar.longitude);
    ecef.y = ( N + polar.height ) * cos_latitude * sin(polar.longitude);
    ecef.z = ( N * ( 1.0 - kEllipsoidEccentricitySquared ) + polar.height ) * sin_latitude;
    
    return ecef;
}

RAPolarCoordinate ConvertEcefToPolar( GLKVector3 ecef )
{
    // calculate ellipsoid parameters based upon these equations:
    // http://www.colorado.edu/geography/gcraft/notes/datum/gif/xyzllh.gif

    double p = sqrt( ecef.x*ecef.x + ecef.y*ecef.y );
    double theta = atan2( ecef.z * kRadiusEquator, p * kRadiusPolar );
    
    double sin_theta = sin( theta );
    double cos_theta = cos( theta );
    
    RAPolarCoordinate polar;
    polar.latitude = atan( (ecef.z + kEllipsoidEccentricityPrimeSquared*kRadiusPolar*sin_theta*sin_theta*sin_theta) /
                    (p - kEllipsoidEccentricitySquared*kRadiusEquator*cos_theta*cos_theta*cos_theta) );
    polar.longitude = atan2(ecef.y, ecef.x);
    
    double sin_latitude = sin(polar.latitude);
    double N = kRadiusEquator / sqrt( 1.0 - kEllipsoidEccentricitySquared*sin_latitude*sin_latitude);
    
    polar.height = p / cos(polar.latitude) - N;
    
    // convert to degrees
    polar.latitude *= RAD_TO_DEG;
    polar.longitude *= RAD_TO_DEG;
    polar.height *= 1./kEcefScale;
    
    // normalize
    //polar.longitude = NormalizeLongitude(polar.longitude);
    
    return polar;
}

GLKMatrix4 CoordinateFrameForPolar( RAPolarCoordinate polar )
{
    // convert to radians
    polar.latitude *= DEG_TO_RAD;
    polar.longitude *= DEG_TO_RAD;
    
    // Compute up vector
    GLKVector3 up = GLKVector3Make( cos(polar.longitude) * cos(polar.latitude), sin(polar.longitude) * cos(polar.latitude), sin(polar.latitude));
    
    // Compute east vector
    GLKVector3 east = GLKVector3Make( -sin(polar.longitude), cos(polar.longitude), 0 );
    
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
    start = GLKMatrix4MultiplyAndProjectVector3(kEllipsoidToUnitSphere, start);
    end = GLKMatrix4MultiplyAndProjectVector3(kEllipsoidToUnitSphere, end);
    
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
                *hit = GLKMatrix4MultiplyAndProjectVector3(kUnitSphereToEllipsoid, *hit);
            }
            
            return true;
        }
        
        if ( t2 > 0.0 && t2 < 1.0 ) {
            if ( hit ) {
                *hit = GLKVector3Add( start, GLKVector3MultiplyScalar(diff, t2));
                *hit = GLKMatrix4MultiplyAndProjectVector3(kUnitSphereToEllipsoid, *hit);
            }
            
            return true;
        }
    }
    
    return false;
}

