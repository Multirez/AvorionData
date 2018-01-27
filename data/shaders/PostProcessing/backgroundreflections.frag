
#include "../version.inl"

uniform sampler2D source;
uniform sampler2D normals;
uniform sampler2D positions;
uniform samplerCube skyTexture;
uniform samplerCube fogTexture;

uniform vec3 eye;
uniform float fogStrength;
uniform float maxFoggyness;

in vec2 texCoord;

void main()
{
    outFragColor.a = 1;
    outFragColor.rgb = texture(source, texCoord).rgb;

    vec4 texPosition = texture(positions, texCoord);
    vec4 texNormal = texture(normals, texCoord);

    // TODO: replace with stencil check
    float reflectivity = texNormal.a;
    if (reflectivity > 0)
    {
        vec3 eyeReflected = reflect(texPosition.xyz - eye, texNormal.xyz);
        vec3 reflection = texture(skyTexture, eyeReflected).rgb;

        outFragColor.rgb += reflection * reflectivity;
    }

    // now add fog
    vec3 eyedir = texPosition.xyz - eye;
    float distanceToEye = texPosition.a;

    vec3 fogColor = texture(fogTexture, eyedir).rgb;
    float fogAmount = min(maxFoggyness, 1.0 - exp(-distanceToEye * fogStrength)) * dot(texNormal.xyz, texNormal.xyz);
    outFragColor.rgb = mix(outFragColor.rgb, fogColor.rgb, fogAmount);

}

