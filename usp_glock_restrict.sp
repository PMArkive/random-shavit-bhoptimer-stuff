#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "USP and Glock Restrictor",
	author = "normalamron",
	description = "Prevents USP silencer removal and Glock burst mode switching.",
	version = "",
	url = ""
};

bool g_bUSPRestrict[MAXPLAYERS + 1];
bool g_bGlockRestrict[MAXPLAYERS + 1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_usp_silencer", Command_ToggleUSP, "Toggle USP silencer removal prevention for yourself.");
	RegConsoleCmd("sm_glock_burst", Command_ToggleGlock, "Toggle Glock burst mode prevention for yourself.");
}

public void OnClientPutInServer(int client)
{
	g_bUSPRestrict[client] = false;
	g_bGlockRestrict[client] = false;
}

public Action Command_ToggleUSP(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}

	g_bUSPRestrict[client] = !g_bUSPRestrict[client];
	
	ReplyToCommand(client, "[SM] USP silencer removal prevention is now %s.", g_bUSPRestrict[client] ? "ENABLED" : "DISABLED");
	return Plugin_Handled;
}

public Action Command_ToggleGlock(int client, int args)
{
	if (client == 0)
	{
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}

	g_bGlockRestrict[client] = !g_bGlockRestrict[client];
	
	ReplyToCommand(client, "[SM] Glock burst mode switching prevention is now %s.", g_bGlockRestrict[client] ? "ENABLED" : "DISABLED");
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Continue;
	}

	int iActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if (iActiveWeapon <= 0)
	{
		return Plugin_Continue;
	}

	char sClassname[64];
	GetEntityClassname(iActiveWeapon, sClassname, sizeof(sClassname));

	bool bUsp = (StrEqual(sClassname, "weapon_usp_silencer") || StrEqual(sClassname, "weapon_usp"));
	bool bGlock = StrEqual(sClassname, "weapon_glock");

	// If restriction is on for the current weapon, block it aggressively
	if ((g_bUSPRestrict[client] && bUsp) || (g_bGlockRestrict[client] && bGlock))
	{
		// Constantly push the next attack time to the future.
		// This tells the CLIENT prediction "you can't do this yet",
		// which prevents the "pulling weapon again" animation glitch.
		SetEntPropFloat(iActiveWeapon, Prop_Send, "m_flNextSecondaryAttack", GetGameTime() + 1.0);

		if (buttons & IN_ATTACK2)
		{
			buttons &= ~IN_ATTACK2;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}
