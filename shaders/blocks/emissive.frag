#include "../version.inl"

in vec4 color;
in vec3 normal;
in vec3 position;

void main()
{
	outFragColor.rgb = color.rgb * 2.0f;
	outFragColor.a = 1;

#if defined(DEFERRED)
    outNormalColor = vec4(normal, 0);
    outPositionColor = vec4(position, gl_FragCoord.z / gl_FragCoord.w);
#endif

}

