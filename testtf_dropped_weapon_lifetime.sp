public void OnPluginStart()
{
	ConVar tf_dropped_weapon_lifetime = FindConVar("tf_dropped_weapon_lifetime");
	tf_dropped_weapon_lifetime.IntValue = 0;
}