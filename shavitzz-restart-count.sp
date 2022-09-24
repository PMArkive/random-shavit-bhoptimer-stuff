#include <sourcemod>
#include <sdktools>
#include <shavit/core>
#include <shavit/hud>

int gI_RestartCounter[MAXPLAYERS+1];


public void OnPluginStart()
{
	RegConsoleCmd("sm_kickme", Command_KickMe, "asdf.");
}

public void OnClientPutInServer(int client)
{
	gI_RestartCounter[client] = -2;
}

public void Shavit_OnRestart(int client, int track)
{
	gI_RestartCounter[client] += 1;
}

public Action Shavit_OnTopLeftHUD(int client, int target, char[] topleft, int topleftlength, int track, int style)
{
	if (1 <= target < MaxClients)
	{
		FormatEx(topleft, topleftlength, "RESTART COUNTER = %d", gI_RestartCounter[target]);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

public Action Command_KickMe(int client, int args)
{
	KickClient(client, "asdf");
	return Plugin_Handled;
}
