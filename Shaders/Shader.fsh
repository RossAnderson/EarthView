//
//  Shader.fsh
//  EarthViewExample
//
//  Created by Ross Anderson on 4/26/12.
//  Copyright (c) 2012 Ross Anderson. All rights reserved.
//

uniform sampler2D texture0;

varying mediump vec2 fragmentTextureCoordinates;
varying lowp vec4 fragmentColor;

void main()
{
    gl_FragColor = texture2D(texture0, fragmentTextureCoordinates) * fragmentColor;
}
