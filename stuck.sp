#include <sourcemod>
#include <sdktools>

public void OnPluginStart()
{
	RegConsoleCmd("sm_stuck", Command_Stuck, "Unstuck yourself");
}

public Action Command_Stuck(int client, int args)
{
	if (!IsPlayerAlive(client))
		return Plugin_Handled;

	float fEyeAngles[3], fDirection[3], fOrigin[3];
	GetClientEyeAngles(client, fEyeAngles);
	GetAngleVectors(fEyeAngles, fDirection, NULL_VECTOR, NULL_VECTOR);
	GetClientAbsOrigin(client, fOrigin);
	ScaleVector(fDirection, 69.0);
	AddVectors(fOrigin, fDirection, fOrigin);
	TeleportEntity(client, fOrigin, NULL_VECTOR, NULL_VECTOR); 
	return Plugin_Handled;
}
