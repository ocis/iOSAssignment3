//
//  Copyright © Borna Noureddin. All rights reserved.
//

#version 300 es
precision highp float;

in vec3 eyeNormal;
in vec4 eyePos;
in vec2 texCoordOut;
out vec4 fragColor;

uniform sampler2D texSampler;

// ### Set up lighting parameters as uniforms
uniform vec3 flashlightPosition;
uniform vec3 diffuseLightPosition;
uniform vec4 diffuseComponent;
uniform float shininess;
uniform vec4 specularComponent;
uniform vec4 ambientComponent;

void main()
{
    // ### Calculate phong model using lighting parameters and interpolated values from vertex shader
    vec4 ambient = ambientComponent;

    vec3 N = normalize(eyeNormal);
    float nDotVP = max(0.0, dot(N, normalize(diffuseLightPosition)));
    vec4 diffuse = diffuseComponent * nDotVP;

    vec3 E = normalize(-eyePos.xyz);
    vec3 L = normalize(flashlightPosition - eyePos.xyz);
    vec3 H = normalize(L+E);
    float Ks = pow(max(dot(N, H), 0.0), shininess);
    vec4 specular = Ks*specularComponent;
    if( dot(L, N) < 0.0 ) {
        specular = vec4(0.0, 0.0, 0.0, 1.0);
    }


    // ### Modify this next line to modulate texture with calculated phong shader values
    fragColor = texture(texSampler, texCoordOut);
    fragColor.a = 0.5;

}
