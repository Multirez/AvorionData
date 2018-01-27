#include "version.inl"

uniform vec3 lightDir;
uniform vec3 lightColor;
uniform float haloIntensity;
uniform sampler2D permTexture;

in vec3 position;

void main()
{
    float halo = max(0, dot(normalize(position), normalize(-lightDir)));
    float color = pow(halo, 15) * 0.7;

    color += pow(halo, 2) * 0.1;

    color += pow(halo, 1600) * 0.3;

    // permTexture resolution is 256, dither up to 2 values down
    vec3 dither = vec3(texture(permTexture, gl_FragCoord.xy / 256.0).a / 256.0);
    outFragColor = vec4(lightColor * color * haloIntensity - dither, 1.0);
}
