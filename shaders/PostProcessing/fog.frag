#include "../version.inl"

uniform sampler2D source;
uniform sampler2D normals;
uniform sampler2D positions;
uniform samplerCube fogTexture;

uniform vec3 eye;
uniform float fogStrength;
uniform float maxFoggyness;

uniform vec2 resolution = vec2(1920, 1080) * 2;

in vec2 texCoord;


void main()
{
    outFragColor.a = 1;
    outFragColor.rgb = texture(source, texCoord).rgb;

    vec4 texPosition = texture(positions, texCoord);
    vec4 texNormal = texture(normals, texCoord);

    // add fog
    vec3 eyedir = texPosition.xyz - eye;
    float distanceToEye = texPosition.a;

    vec3 fogColor = texture(fogTexture, eyedir).rgb;
    float fogAmount = min(maxFoggyness, 1.0 - exp(-distanceToEye * fogStrength)) * dot(texNormal.xyz, texNormal.xyz);
    outFragColor.rgb = mix(outFragColor.rgb, fogColor.rgb, fogAmount);

    //outFragColor.rgb = vec3(1, 1, 0);

}

