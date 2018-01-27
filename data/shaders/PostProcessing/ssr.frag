
#include "../version.inl"

uniform sampler2D permutation;
uniform sampler2D source;
uniform sampler2D colors;
uniform sampler2D normals;
uniform sampler2D positions;
uniform samplerCube skyTexture;
uniform samplerCube fogTexture;

uniform mat4 mView;
uniform mat4 mProjection;
uniform vec2 resolution = vec2(1920, 1080);
uniform vec3 eye;

uniform float fogStrength;
uniform float maxFoggyness;

#ifndef MAX_ITERATIONS
#define MAX_ITERATIONS 100
#endif // MAX_ITERATIONS

#ifndef STRIDE
#define STRIDE 15.0f
#endif // STRIDE

in vec2 texCoord;

bool justReturn = false;

float dotFadeLower = 0.0;
float dotFadeUpper = 0.1;
float thickness = 0.55;

void swap(inout float a, inout float b)
{
    float c = b;
    b = a;
    a = c;
}

bool intersectDepthBuffer(float sampledDepth, float minZ, float maxZ)
{
    // depth buffer is negative -> lower value means further away
    if (minZ < maxZ) swap(minZ, maxZ);

    float testDepth = sampledDepth - 0.6;

    return maxZ < testDepth
            && minZ > testDepth - thickness
            && sampledDepth < 0 // this is specific to avorion, since lots of pixels can have value 0 (background)
            ;
}

float test(inout vec2 result, vec3 normal_ws, vec3 position_ws)
{
    vec3 dir_ws = position_ws - eye;
    vec3 reflected_ws = reflect((dir_ws), (normal_ws));

    vec3 origin_cs = (mView * vec4(position_ws, 1)).xyz;
    vec3 to_cs = (mView * vec4(position_ws + reflected_ws, 1)).xyz;
    vec3 dir = normalize(to_cs - origin_cs);

    // don't trace reflections that go towards the camera
    float eyeDot = dot(dir, vec3(0, 0, 1));
    if (eyeDot > dotFadeUpper) return 0.0f;

    vec3 end_cs = origin_cs + dir * 100.0;

    // the coordinates in screen space
    vec4 p0 = mProjection * vec4(origin_cs, 1.0);
    vec4 p1 = mProjection * vec4(end_cs, 1.0);

    float k0 = 1.0 / p0.w;
    float k1 = 1.0 / p1.w;

    p0.xy *= k0;
    p1.xy *= k1;

    p0.xy = (p0.xy * 0.5 + 0.5) * resolution;
    p1.xy = (p1.xy * 0.5 + 0.5) * resolution;


    float hz0 = origin_cs.z * k0;
    float hz1 = end_cs.z * k1;

    vec4 start = vec4(p0.xy, hz0, k0);
    vec4 step = vec4(p1.xy - p0.xy, hz1 - hz0, k1 - k0) / length(p1.xy - p0.xy);

    // add stride
    vec4 singleStep = step * STRIDE;

    // add jitter
    float jitter = texture(permutation, texCoord / resolution.y * vec2(256 * 32.0)).r * 2.1;
    vec4 p = start + singleStep * jitter;

    // start iteration
    float previousDepth = p.z;

    singleStep *= 0.125;
    p += singleStep * 2;

    // do a first step
    int i = 0;
    ivec2 currentPixels = ivec2(p.xy);
    float depth = p.z / p.w;
    float sampledDepth = -texelFetch(positions, currentPixels, 0).a;

    for (;
         i < MAX_ITERATIONS
         && p.x > 0
         && p.y > 0
         && p.x < resolution.x
         && p.y < resolution.y
         && !intersectDepthBuffer(sampledDepth, previousDepth, depth)
         ;
         ++i)
    {
        previousDepth = depth;

        p += singleStep;
        singleStep = i < 3 ? singleStep * 2.0 : singleStep;

        currentPixels = ivec2(p.xy);
        depth = p.z / p.w;
        sampledDepth = -texelFetch(positions, currentPixels, 0).a;
    }

    // if there was no result, just return
    if (i == MAX_ITERATIONS) return 0.0;
    if (p.x < 0) return 0.0;
    if (p.y < 0) return 0.0;
    if (p.x > resolution.x) return 0.0;
    if (p.y > resolution.y) return 0.0;


    // otherwise refine result with a binary search
    singleStep *= 0.5;
    float searchDirection = -1.0; // the last result was a hit, meaning we go backwards now

    for (int i = 0;
         i < 5 && abs(depth - sampledDepth) > 0.05 // exit after 5 steps or if the result is close to the sampled buffer
         ; ++i)
    {
        p += singleStep * searchDirection;

        currentPixels = ivec2(p.xy);
        depth = p.z / p.w;
        sampledDepth = -texelFetch(positions, currentPixels, 0).a;

        searchDirection = intersectDepthBuffer(sampledDepth, previousDepth, depth)
                ? -1.0 // a hit means we go backwards
                : 1.0; // miss means we go forward

        singleStep *= 0.5;
        previousDepth = depth;
    }

    // return the result
    result = p.xy / resolution;

    // apply various fadeouts
    float fadeOut = 1.0 - clamp((eyeDot - dotFadeLower) / (dotFadeUpper - dotFadeLower), 0.0, 1.0);

    vec3 hitNormal = texelFetch(normals, currentPixels, 0).xyz;
    vec3 hitPosition = texelFetch(positions, currentPixels, 0).xyz;

    fadeOut *= (dot(hitNormal, reflected_ws) > 0) ? 0.0 : 1.0;
    fadeOut *= (dot(hitPosition - position_ws, hitNormal) > 0) ? 0.0 : 1.0;
    fadeOut *= (dot(hitPosition - position_ws, normal_ws) < 0) ? 0.0 : 1.0;

    float borderFactor = min(p.x, min(p.y, min(resolution.x - p.x, resolution.y - p.y)));
    fadeOut *= clamp(borderFactor / 40, 0, 1);

    // add a fresnel factor to highlight reflections that are correct
    float fresnel = clamp(2.0 + dot(normalize(dir_ws), normal_ws), 0, 1);

    return fadeOut * fresnel;
}

void main()
{
    outFragColor.a = 1;
    outFragColor.rgb = texture(source, texCoord).rgb;

    vec4 texNormal = texture(normals, texCoord);

    // after several tests, this proved to be faster than a depth/stencil check
    if (texNormal.rgb == vec3(0, 0, 0)) return;

    vec4 texPosition = texture(positions, texCoord);

    float reflectivity = texNormal.a;
    if (reflectivity > 0)
    {
        vec2 reflectedCoord = vec2(0, 0);

        float factor = test(reflectedCoord, texNormal.xyz, texPosition.xyz);
        vec3 ssr = texture(colors, reflectedCoord).rgb;

        vec3 eyeReflected = reflect(texPosition.xyz - eye, texNormal.xyz);
        vec3 cube = texture(skyTexture, eyeReflected).rgb;

        outFragColor.rgb += mix(cube, ssr, factor) * reflectivity;
    }

    // now add fog
    vec3 eyedir = texPosition.xyz - eye;
    float distanceToEye = texPosition.a;

    vec3 fogColor = texture(fogTexture, eyedir).rgb;
    float fogAmount = min(maxFoggyness, 1.0 - exp(-distanceToEye * fogStrength)) * dot(texNormal.xyz, texNormal.xyz);
    outFragColor.rgb = mix(outFragColor.rgb, fogColor.rgb, fogAmount);

}

