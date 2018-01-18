#include "version.inl"

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform float ambient;

uniform sampler2D hullTexture;
uniform sampler2D debrisTexture;

in vec4 color;
in vec3 position;
in vec3 normal;
in vec2 texCoord;
in float timeAlive;

void main()
{
    vec4 shatterColor = texture(debrisTexture, texCoord);
    float v = shatterColor.r;

    if (v < 0.4)
        discard;

    vec3 nnormal = normalize(normal);

    // direct lighting
    float lightIntensity = clamp(dot(nnormal, -lightDir), 0.0, 1.0);

    // normalize remaining colors
    v = (v - 0.4) / 0.6;

    // darkening
    float darkGradient = clamp(min(v, 0.4) * 2.5, 0.0, 1.0);
    darkGradient *= darkGradient;

    // emissive
    float emissiveGradient = clamp(1.0 - v * 3.0 - timeAlive, 0.0, 1.0);
    vec3 emissive = vec3(1.8, 0.7, 0.2);

    vec3 hull = vec3(texture(hullTexture, texCoord)) * darkGradient * color.rgb;

    outFragColor.rgb = hull * min(1, lightIntensity + ambient) * lightColor + emissive * emissiveGradient;
    outFragColor.a = min(1.0, 3.0 - timeAlive * 3.0);

#if defined(DEFERRED)
    outNormalColor = vec4(nnormal, 0);
    outPositionColor = vec4(position, gl_FragCoord.z / gl_FragCoord.w);
#endif
}
