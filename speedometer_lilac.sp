#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <shavit>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1337"

int g_iClientTickCount[MAXPLAYERS + 1];

float g_fLastVelocity[MAXPLAYERS + 1];
float g_fVelocity[MAXPLAYERS + 1];
float g_vecAbsVelocity[MAXPLAYERS + 1][3];

Handle g_hSpeedometerEnabled;
Handle g_hSpeedometerRate;

public Plugin myinfo =
{
	name = "speedometer",
	author = "kaworu from neon genesis evangelion",
	description = "i'm so gay'",
	version = PLUGIN_VERSION,
	url = "google.com"
};

public void OnPluginStart()
{
	/**
	 * @note For the love of god, please stop using FCVAR_PLUGIN.
	 * Console.inc even explains this above the entry for the FCVAR_PLUGIN define.
	 * "No logic using this flag ever existed in a released game. It only ever appeared in the first hl2sdk."
	 */
	CreateConVar("sm_speedometer_version", PLUGIN_VERSION, "Standard plugin version ConVar. Please don't change me!", FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_DONTRECORD);

	RegConsoleCmd("sm_speedometer", Command_Speedometer, "i'm gay");
	RegConsoleCmd("sm_speedometerrate", Command_SpeedometerRate, "i'm gay");

	g_hSpeedometerEnabled = RegClientCookie("speedometer_enabled", "Speedometer Enabled", CookieAccess_Protected);
	g_hSpeedometerRate = RegClientCookie("speedometer_rate", "Speedometer Rate", CookieAccess_Protected);
}

public Action Command_Speedometer(int client, int args)
{
	if (AreClientCookiesCached(client))
	{
		char sCookieValue[12];
		GetClientCookie(client, g_hSpeedometerEnabled, sCookieValue, sizeof(sCookieValue));
		int cookieValue = StringToInt(sCookieValue);
		switch (cookieValue)
		{
			case 0:
			{
				cookieValue++;

				Shavit_PrintToChat(client, "Speedometer has been enabled.");
			}
			case 1:
			{
				cookieValue--;

				Shavit_PrintToChat(client, "Speedometer has been disabled.");
			}
		}

		IntToString(cookieValue, sCookieValue, sizeof(sCookieValue));

		SetClientCookie(client, g_hSpeedometerEnabled, sCookieValue);
	}

	return Plugin_Handled;
}

public Action Command_SpeedometerRate(int client, int args)
{
	if (AreClientCookiesCached(client))
	{
		char sCookieValue[12], sArg[256];
		GetClientCookie(client, g_hSpeedometerRate, sCookieValue, sizeof(sCookieValue));
		GetCmdArg(1, sArg, sizeof(sArg));
		int cookieValue = StringToInt(sCookieValue);
		int arg = StringToInt(sArg);

		if (arg <= 0 || arg >= 100)
		{
			cookieValue = 10;

			Shavit_PrintToChat(client, "Speedometer update rate cannot be less than 1 or greater than 100.");
		}
		else
		{
			cookieValue = arg;

			Shavit_PrintToChat(client, "Speedometer update rate has been set to: %i.", cookieValue);
			IntToString(cookieValue, sCookieValue, sizeof(sCookieValue));

			SetClientCookie(client, g_hSpeedometerRate, sCookieValue);
		}
	}

	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	char sCookieValue[12], sCookieValue2[12];
	GetClientCookie(client, g_hSpeedometerEnabled, sCookieValue, sizeof(sCookieValue));
	GetClientCookie(client, g_hSpeedometerRate, sCookieValue2, sizeof(sCookieValue2));
	int cookieValue = StringToInt(sCookieValue);
	int cookieValue2 = StringToInt(sCookieValue2);

	if (!cookieValue2)
	{
		cookieValue2 = 10;
	}

	if (cookieValue && g_iClientTickCount[client] >= cookieValue2)
	{
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", g_vecAbsVelocity[client]);
		g_fVelocity[client] = SquareRoot(g_vecAbsVelocity[client][0] * g_vecAbsVelocity[client][0] + g_vecAbsVelocity[client][1] * g_vecAbsVelocity[client][1]);

		if (g_fLastVelocity[client] > g_fVelocity[client])
		{
			SetHudTextParams(-1.0, 0.4, cookieValue2 / 100.0, 220, 20, 60, 255, 0, 0.0, 0.0);
		}
		else if (g_fLastVelocity[client] < g_fVelocity[client])
		{
			SetHudTextParams(-1.0, 0.4, cookieValue2 / 100.0, 0, 191, 255, 255, 0, 0.0, 0.0);
		}
		else //if (g_fLastVelocity[client] == g_fVelocity[client])
		{
			SetHudTextParams(-1.0, 0.4, cookieValue2 / 100.0, 255, 255, 255, 255, 0, 0.0, 0.0);
		}

		ShowHudText(client, 3, "%0.f", g_fVelocity[client]);

		g_fLastVelocity[client] = g_fVelocity[client];

		g_iClientTickCount[client] = 0;

	}
	else if (g_iClientTickCount[client] < cookieValue2)
	{
		g_iClientTickCount[client]++;
	}
}