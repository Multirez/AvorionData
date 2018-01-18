#include "../version.inl"

uniform samplerCube portalTexture;
uniform samplerCube fogTexture;
uniform float maxFoggyness;
uniform float fogStrength;
uniform sampler2D displacementTexture;

uniform vec3 eye;
uniform vec2 offset;

in vec4 color;
in vec3 position;
in vec3 normal;
in vec2 texWorld;
in vec2 texCoord;

void main()
{
    vec3 distortion = texture(displacementTexture, texWorld * 0.1 + offset * 0.025).xyz * 2.0 - 1.0;

    vec3 eyedir = normalize(position - eye);
    vec4 texColor = texture(portalTexture, eyedir + distortion * 0.15);

    texColor.rgb = texColor.rgb + pow(texColor.rgb, vec3(5));

    outFragColor.rgb = texColor.rgb;

    vec3 distortion2 = texture(displacementTexture, texWorld * 0.05 + offset * 0.0125).xyz * 2.0 - 1.0;
    float d = clamp(length(texCoord + distortion2.xy) * 1.8 - 1.2, 0, 1.0);

    //d = d * step(distortion2.y * 4.0, length(texCoord) * 0.15);

    outFragColor.rgb = mix(outFragColor.rgb, vec3(0), d);
    outFragColor.a = 1;

#if defined(DEFERRED)
    outNormalColor = vec4(normal, 0);
    outPositionColor = vec4(position, gl_FragCoord.z / gl_FragCoord.w);
#else
    // fog
    vec3 fogColor = texture(fogTexture, eyedir).rgb;
    float fogDistance = gl_FragCoord.z / gl_FragCoord.w;
    float fogAmount = min(maxFoggyness, 1.0 - exp(-fogDistance * fogStrength));
    outFragColor.rgb = mix(outFragColor.rgb, fogColor.rgb, fogAmount);
#endif

}


