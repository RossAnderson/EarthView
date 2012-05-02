//
//  Shader.vsh
//  EarthViewExample
//
//  Created by Ross Anderson on 4/26/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

attribute vec4 position;
attribute vec2 textureCoordinate;
attribute vec3 normal;

uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;

uniform vec3 lightDirection;
uniform vec4 lightAmbientColor;
uniform vec4 lightDiffuseColor;

varying mediump vec2 fragmentTextureCoordinates;
varying lowp vec4 fragmentColor;

const float c_zero = 0.0;
const float c_one = 1.0;

void main()
{
    vec4 color = lightAmbientColor;
    float ndotl = max( c_zero, dot( normal, lightDirection ) );
    color += ndotl * ndotl * lightDiffuseColor;
        
    gl_Position = modelViewProjectionMatrix * position;
    fragmentTextureCoordinates = textureCoordinate;
    fragmentColor = color;
}
