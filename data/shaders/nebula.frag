
#include "version.inl"

uniform sampler2D diffuseTexture;
uniform float highlightIntensity;

in vec4 color;
in vec2 texCoord;



void main()
{
	vec3 texColor = texture(diffuseTexture, texCoord).rgb;

    vec3 ncolor = texColor * color.rgb;

    vec3 highlight = mix(color.rgb, vec3(1), 0.75) * highlightIntensity;

	ncolor += pow(texColor, vec3(2.0)) * 0.75 * highlight;
	ncolor += pow(texColor, vec3(8.0)) * 0.75 * highlight;
	ncolor += pow(texColor, vec3(16.0)) * 0.5 * highlight;

    outFragColor =  vec4(ncolor.rgb * color.a, 1);
}
