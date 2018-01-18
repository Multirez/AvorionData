#include "version.inl"

uniform sampler2D diffuseTexture;
uniform float invert;
uniform float highlight;

in vec4 color;
in vec2 texCoord;



void main()
{
    vec2 coords;
    if (invert == 0.0)
    {
        coords = vec2(texCoord.x, 1.0f - texCoord.y);
    }
    else
    {
        coords = vec2(texCoord.x, texCoord.y);
    }

    vec4 texColor = texture(diffuseTexture, coords);

    float shadow = 0.0;

    float delta = 0.015;
    shadow += texture(diffuseTexture, coords + vec2(delta, 0)).r;
    shadow += texture(diffuseTexture, coords + vec2(-delta, 0)).r;
    shadow += texture(diffuseTexture, coords + vec2(0, delta)).r;
    shadow += texture(diffuseTexture, coords + vec2(0, -delta)).r;

    shadow += texture(diffuseTexture, coords + vec2(delta, delta)).r;
    shadow += texture(diffuseTexture, coords + vec2(delta, -delta)).r;
    shadow += texture(diffuseTexture, coords + vec2(-delta, delta)).r;
    shadow += texture(diffuseTexture, coords + vec2(-delta, -delta)).r;

    if (shadow > 1.0) shadow = 1.0;
    if (shadow < 0.01) shadow = 0.0;

    vec4 shadowColor = vec4(0, 0, 0, shadow);
    vec4 iconColor = vec4(1, 1, 1, texColor.r);

    vec4 finalColor = mix(shadowColor, iconColor, iconColor.a);

    float d = min(1.0, max(0.0, 1.0 - distance(texCoord, vec2(texCoord.x)) / 0.45));
    vec4 shaded = mix(color, color + vec4(vec3(highlight), 0.0), d);

    outFragColor = finalColor * shaded;

}

