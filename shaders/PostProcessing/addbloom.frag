
#include "../version.inl"

uniform sampler2D permTexture;
uniform sampler2D baseTexture;
uniform sampler2D bloomTexture1;
uniform sampler2D bloomTexture2;
uniform sampler2D bloomTexture3;
uniform sampler2D bloomTexture4;
uniform float amplification1;
uniform float amplification2;
uniform float amplification3;
uniform float amplification4;
uniform float gamma;

in vec2 texCoord;

void main()
{
	vec4 texColor = texture(baseTexture, texCoord);
	vec4 bloom = vec4(0);

	bloom += texture(bloomTexture1, texCoord) * amplification1;
    bloom += texture(bloomTexture2, texCoord) * amplification2;
    bloom += texture(bloomTexture3, texCoord) * amplification3;
    bloom += texture(bloomTexture4, texCoord) * amplification4;

    vec4 dither = vec4(texture(permTexture, gl_FragCoord.xy / 256.0).a / 256.0);

//    texColor.rgb = vec3(0);

	outFragColor = texColor + max(vec4(0.0), bloom * 0.9 - dither);

	outFragColor.rgb = pow(outFragColor.rgb, vec3(1.0 / gamma));
}
