#include <sourcemod>
#include <shavit/core>

float gF_Asdf[MAXPLAYERS+1];

public void Shavit_Bhopstats_OnTouchGround(int client)
{
	PrintToChat(client, "%f", GetGameTime() - gF_Asdf[client]);
}

public void Shavit_Bhopstats_OnLeaveGround(int client, bool jumped, bool ladder)
{
	gF_Asdf[client] = GetGameTime();
}
