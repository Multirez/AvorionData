
#include "version.inl"

uniform samplerCube skyTexture;

in vec3 position;

void main()
{
	vec4 texColor = texture(skyTexture, position);

	outFragColor = vec4(texColor.rgb, 1.0f);
}
