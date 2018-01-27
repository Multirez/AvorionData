#include "../version.inl"

uniform sampler2D sourceTexture;
uniform float threshold;

in vec2 texCoord;

void main()
{
    vec4 texColor = texture(sourceTexture, vec2(texCoord.x, texCoord.y));
    outFragColor = max(vec4(0.0), texColor - threshold);
}
