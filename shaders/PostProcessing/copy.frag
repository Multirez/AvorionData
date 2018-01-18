
#include "../version.inl"

uniform sampler2D sourceTexture;

in vec2 texCoord;

void main()
{
	outFragColor = texture(sourceTexture, texCoord);
}
