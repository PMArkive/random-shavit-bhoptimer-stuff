
public void OnPluginStart()
{
	PrintToServer("Hello, World! %d", NULL_VECTOR);
	float v[3] = {199.0, 333.0, -293.0};
	GetAngleVectors(v, NULL_VECTOR, view_as<float>({0,0,0}), NULL_VECTOR);
	GetAngleVectors(v, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR);
}
