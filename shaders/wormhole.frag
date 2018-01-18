#include "version.inl"

uniform samplerCube portalTexture;
uniform samplerCube fogTexture;
uniform sampler2D displacementTexture;
uniform float maxFoggyness;
uniform float fogStrength;

uniform vec3 eye;
uniform vec2 offset;

in vec4 color;
in vec3 position;
in vec2 texWorld;
in vec2 texCoord;

void main()
{
    vec3 distortion = texture(displacementTexture, texCoord + offset * 0.025).xyz * 2.0 - 1.0;

    vec3 eyedir = normalize(position - eye);
    vec4 texColor = texture(portalTexture, eyedir + distortion * 0.15);

    outFragColor.rgb = texColor.rgb;

    vec3 distortion2 = texture(displacementTexture, texCoord * 0.25 + offset * 0.0125).xyz * 2.0 - 1.0;
    float d = clamp(length(texCoord - vec2(0.5) + distortion2.xy * 0.5) * 25 - 10, 0, 1.0);

    if (d > 0.85) discard;
    if (d > 0.8)
    {
        outFragColor.rgb = (normalize(abs(outFragColor.rgb) + vec3(0.01))) * 6.0;
        outFragColor.a = 1;
        return;
    }

    outFragColor.rgb = mix(outFragColor.rgb, outFragColor.rgb * 5.0, d);

    // fog
    float distanceToEye = gl_FragCoord.z / gl_FragCoord.w;
    vec3 fogColor = texture(fogTexture, eyedir).rgb;
    float fogAmount = min(maxFoggyness, 1.0 - exp(-distanceToEye * fogStrength));
    outFragColor.rgb = mix(outFragColor.rgb, fogColor.rgb, fogAmount);


    outFragColor.a = 1;
}


