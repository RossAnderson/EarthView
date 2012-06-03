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
    lowp vec4 color = fragmentColor;
    
    lowp vec4 texel;
    
    texel = texture2D(texture0, fragmentTextureCoordinates);
    color *= texel;
    
    // add border
    //if ( fragmentTextureCoordinates.x < 0.01 || fragmentTextureCoordinates.y < 0.01 ) color = vec4(0,0,0,1);

    gl_FragColor = color;
}
