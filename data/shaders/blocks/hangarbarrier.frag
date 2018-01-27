#include "../version.inl"

uniform vec3 outerColor;
uniform vec3 innerColor;

uniform vec2 noiseOffset;
uniform sampler2D noiseTexture;

in vec4 util0;
in vec3 position;
in vec3 normal;

void main()
{
    vec2 quad = 1.0 - (abs(util0.xy * 1.2) - vec2(0.95, 0.95)) / 0.25;
    quad = min(vec2(1.0f), max(vec2(0.0f), quad));
    float inner = quad.x * quad.y;

    float noise = texture(noiseTexture, vec2(0, util0.y) + noiseOffset).r * 0.5 + 0.5;
    vec3 shieldColor = innerColor * noise;

    outFragColor.rgb = mix(outerColor, shieldColor, inner);
    outFragColor.a = 1;

#if defined(DEFERRED)
    outNormalColor = vec4(normal.xyz, 0);
    outPositionColor = vec4(position.xyz, gl_FragCoord.z / gl_FragCoord.w);
#endif

}

