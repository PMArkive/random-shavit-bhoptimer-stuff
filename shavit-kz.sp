#include <sourcemod>
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

enum
{
	TimerAction_None,
	TimerAction_OnStart,
	TimerAction_OnTeleport
}

public Plugin myinfo =
{
	name = "[shavit] KZ Pro <-> TP",
	author = "shavit",
	description = "Changes styles between Pro and TP.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public Action Shavit_OnStart(int client, int track)
{
	int iStyle = Shavit_GetBhopStyle(client);
	int iTargetStyle = iStyle;

	if(GetTimerAction(iStyle, iTargetStyle) == TimerAction_OnStart)
	{
		Shavit_ChangeClientStyle(client, iTargetStyle, true, false, false);
	}

	return Plugin_Continue;
}

public Action Shavit_OnTeleport(int client)
{
	int iStyle = Shavit_GetBhopStyle(client);
	int iTargetStyle = iStyle;

	if(GetTimerAction(iStyle, iTargetStyle) == TimerAction_OnTeleport)
	{
		Shavit_ChangeClientStyle(client, iTargetStyle, true, false, false);
	}

	return Plugin_Continue;
}

int GetTimerAction(int style, int &arg)
{
	char sSpecial[128];
	Shavit_GetStyleStrings(style, sSpecialString, sSpecial, sizeof(stylestrings_t::sSpecialString));

	char sExploded[6][32];
	int iSettings = ExplodeString(sSpecial, ";", sExploded, 6, 32, false);

	for(int i = 0; i < iSettings; i++)
	{
		char sExplodedStyle[2][16];
		int iExploded = ExplodeString(sExploded[i], "=", sExplodedStyle, 2, 16, false);

		if(iExploded != 2)
		{
			continue;
		}

		arg = StringToInt(sExplodedStyle[1]);

		if(StrContains(sExploded[i], "onstart") != -1)
		{
			return TimerAction_OnStart;
		}

		if(StrContains(sExploded[i], "onteleport") != -1)
		{
			return TimerAction_OnTeleport;
		}
	}


	return TimerAction_None;
}