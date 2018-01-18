#include "../version.inl"

uniform sampler2D source;
uniform float gamma;

in vec2 texCoord;

void main()
{
	outFragColor = texture(source, vec2(texCoord.x, texCoord.y));
	outFragColor.rgb = pow(outFragColor.rgb, vec3(1.0 / gamma));
}
