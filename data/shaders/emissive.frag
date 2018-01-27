#include "version.inl"

in vec4 color;

void main()
{
	outFragColor.rgb = color.rgb * 2.0f;
	outFragColor.a = 1;
}
