public Plugin myinfo =
{
	name = "configurable_noclipspeed",
	author = "rtldg",
	description = "use !noclipspeed to edit your things...",
	version = "1.0.0",
	url = "https://github.com/PMArkive/random-shavit-bhoptimer-stuff",
};

#include <clientprefs>

#pragma newdecls required
#pragma semicolon 1

ConVar gC_NoclipSpeed = null;
ConVar gC_SpecSpeed = null;
Cookie gH_Cookie = null;
float gF_Speed[MAXPLAYERS+1] = {5.0, ...};

public void OnPluginStart()
{
	gH_Cookie = new Cookie("configurable_noclipspeed", "", CookieAccess_Protected);

	gC_NoclipSpeed = FindConVar("sv_noclipspeed");
	gC_NoclipSpeed.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);
	gC_SpecSpeed = FindConVar("sv_specspeed");
	gC_SpecSpeed.Flags &= ~(FCVAR_NOTIFY | FCVAR_REPLICATED);

	RegConsoleCmd("sm_noclipspeed", Command_Noclipspeed, "DESCRIPTION");

	for (int client = 1; client <= MaxClients; ++client)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			OnClientPutInServer(client);

			if (AreClientCookiesCached(client))
			{
				OnClientCookiesCached(client);
			}
		}
	}
}

void ReplicateToClient(int client, float speed)
{
	char buf[32];
	FormatEx(buf, sizeof(buf), "%.9f", speed);
	gC_NoclipSpeed.ReplicateToClient(client, buf);
	gC_SpecSpeed.ReplicateToClient(client, buf);
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client)) return;
	if (AreClientCookiesCached(client))
		ReplicateToClient(client, gF_Speed[client]);
	else
		SetSpeed(client, 5.0);
}

void SetSpeed(int client, float val)
{
	if (val <= 0.0) val = 0.1;
	if (val > 50.0) val = 50.0;
	gF_Speed[client] = val;
	if (IsClientInGame(client)) ReplicateToClient(client, gF_Speed[client]);
}

public void OnClientCookiesCached(int client)
{
	if (IsFakeClient(client)) return;
	SetSpeed(client, gH_Cookie.GetFloat(client, 5.0));
}

Action Command_Noclipspeed(int client, int args)
{
	if (client == 0) return Plugin_Handled;
	if (args < 1) return Plugin_Handled;
	float val = GetCmdArgFloat(1);
	SetSpeed(client, val);
	gH_Cookie.SetFloat(client, val);
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client)
{
	gC_NoclipSpeed.FloatValue = gF_Speed[client];
	gC_SpecSpeed.FloatValue = gF_Speed[client];
	return Plugin_Continue;
}
