in vec4 shadowCoord;
uniform sampler2DShadow shadowMap;
uniform float sampleSize;
uniform float bias;

#define FADE_OUT 0.05
#define INV_FADE_OUT (1.0 - 0.05)

float factor()
{
    // transform from 0, 1 to -1, 1
    vec2 coord = shadowCoord.xy * 2.0 - 1.0;
    coord = 1.0 - (abs(coord.xy) - vec2(INV_FADE_OUT)) / FADE_OUT;
    coord = min(vec2(1.0), max(vec2(0.0), coord));

    return 1.0 - clamp(coord.x * coord.y, 0.0, 1.0);
}

#ifdef SOFT_SHADOWS
float sampleShadow()
{
    float shadow = 0;
    float size = sampleSize * 1.0;

    for (float x = -2.0; x <= 2.0; x += 1.0)
    {
        for (float y = -2.0; y <= 2.0; y += 1.0)
        {
            shadow += texture(shadowMap, vec3(shadowCoord.xy + vec2(size * x, size * y), (shadowCoord.z - bias) / shadowCoord.w));
        }
    }

    return mix(shadow / 25.0, 1.0, factor());
}
#else
float sampleShadow()
{
    return mix(texture(shadowMap, vec3(shadowCoord.xy, (shadowCoord.z - bias) / shadowCoord.w)), 1.0, factor());
}
#endif
