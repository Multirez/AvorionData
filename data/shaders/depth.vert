#include "version.inl"

uniform mat4 mWorldViewProjection;

void main(void)
{
	gl_Position = mWorldViewProjection * vec4(vPosition, 1.0);
}

