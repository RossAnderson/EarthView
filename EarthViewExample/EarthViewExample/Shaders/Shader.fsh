//
//  Shader.fsh
//  EarthViewExample
//
//  Created by Ross Anderson on 4/14/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

varying lowp vec4 colorVarying;

void main()
{
    gl_FragColor = colorVarying;
}
