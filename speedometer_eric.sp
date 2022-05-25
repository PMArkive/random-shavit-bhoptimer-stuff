#include <sourcemod>
#include <clientprefs>

#pragma newdecls required
#pragma semicolon 1

bool gB_Speedometer[MAXPLAYERS + 1];
Handle gH_SpeedometerCookie;

bool gB_Late;

public Plugin myinfo =
{
	name = "Speedometer",
	author = "Eric",
	description = "",
	version = "1.0.0",
	url = "http://steamcommunity.com/id/-eric"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_Late = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	RegConsoleCmd("sm_speedometer", Command_Speedometer, "");

	gH_SpeedometerCookie = RegClientCookie("speedometer_enabled", "Speedometer enabled", CookieAccess_Protected);

	if (gB_Late)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
			{
				continue;
			}

			if (!AreClientCookiesCached(i))
			{
				continue;
			}

			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	if (!GetClientCookieBool(client, gH_SpeedometerCookie, gB_Speedometer[client]))
	{
		gB_Speedometer[client] = false;
		SetClientCookieBool(client, gH_SpeedometerCookie, false);
	}
}

public Action Command_Speedometer(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	gB_Speedometer[client] = !gB_Speedometer[client];
	SetClientCookieBool(client, gH_SpeedometerCookie, gB_Speedometer[client]);
	PrintToChat(client, "[SM] Speedometer %s.", gB_Speedometer[client] ? "enabled" : "disabled");

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	if (!gB_Speedometer[client])
	{
		return Plugin_Continue;
	}

	if (cmdnum % 10 != 0)
	{
		return Plugin_Continue;
	}

	int target = GetClientObserverTarget(client);
	int speed = RoundToFloor(GetClientSpeed(target));

	int colour[4];
	GetSpeedColour(target, speed, colour);

	static Handle hudSynchronizer;
	if (hudSynchronizer == null)
	{
		hudSynchronizer = CreateHudSynchronizer();
	}

	SetHudTextParams(-1.0, -0.625, 0.2, colour[0], colour[1], colour[2], colour[3], _, _, 0.0, 0.0);
	ShowSyncHudText(client, hudSynchronizer, "%d", speed);

	return Plugin_Continue;
}

void GetSpeedColour(int client, int speed, int colour[4])
{
	static int lastSpeed[MAXPLAYERS + 1];

	if (speed > lastSpeed[client])
	{
		colour = {0, 255, 255, 255};
	}
	else if (speed < lastSpeed[client])
	{
		colour = {255, 0, 0, 255};
	}
	else
	{
		colour = {255, 255, 255, 255};
	}

	lastSpeed[client] = speed;
}

stock bool IsValidClient(int client)
{
	return (0 < client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client));
}

stock void SetClientCookieBool(int client, Handle cookie, bool value)
{
	SetClientCookie(client, cookie, value ? "1" : "0");
}

stock bool GetClientCookieBool(int client, Handle cookie, bool& value)
{
	char buffer[8];
	GetClientCookie(client, cookie, buffer, sizeof(buffer));

	if (buffer[0] == '\0')
	{
		return false;
	}

	value = StringToInt(buffer) != 0;
	return true;
}

stock int GetClientObserverMode(int client)
{
	return GetEntProp(client, Prop_Send, "m_iObserverMode");
}

stock int GetClientObserverTarget(int client)
{
	if (IsClientObserver(client))
	{
		int observerMode = GetClientObserverMode(client);

		if (observerMode >= 3 && observerMode <= 5)
		{
			return GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		}
	}

	return client;
}

stock float GetClientSpeed(int client)
{
	float x = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	float y = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");

	return SquareRoot(Pow(x, 2.0) + Pow(y, 2.0));
}
