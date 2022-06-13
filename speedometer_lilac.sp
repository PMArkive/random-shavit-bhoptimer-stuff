#include <sourcemod>
#include <sdktools>
#include <clientprefs>

#include <shavit>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1337"

#define CHOICE1 "#choice1"
#define CHOICE2 "#choice2"
#define CHOICE3 "#choice3"

int g_iClientTickCount[MAXPLAYERS + 1];

float g_fLastVelocity[MAXPLAYERS + 1];
float g_fVelocity[MAXPLAYERS + 1];
float g_vecAbsVelocity[MAXPLAYERS + 1][3];

Handle g_hSpeedometerEnabled;
Handle g_hSpeedometerRate;
Handle g_hSpeedometerPosition;

public Plugin myinfo = 
{
	name = "speedometer", 
	author = "may", 
	description = "i love kaworu", 
	version = PLUGIN_VERSION, 
	url = "https://github.com/lilac1337"
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
	RegConsoleCmd("sm_speedometerposition", Menu_SpeedometerPosition);
	
	g_hSpeedometerEnabled = RegClientCookie("speedometer_enabled", "Speedometer Enabled", CookieAccess_Protected);
	g_hSpeedometerRate = RegClientCookie("speedometer_rate", "Speedometer Rate", CookieAccess_Protected);
	g_hSpeedometerPosition = RegClientCookie("speedometerPosition", "Speedometer Position", CookieAccess_Protected);
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

public int MenuHandler1(Menu menu, MenuAction action, int param1, int param2)
{
	char sCookieValue[12];
	
	if (action == MenuAction_Select)
	{
		switch (param2)
		{
			case 0:
			{
				FloatToString(0.4, sCookieValue, sizeof(sCookieValue));
				
				SetClientCookie(param1, g_hSpeedometerPosition, sCookieValue);
			}
			case 1:
			{
				FloatToString(-1.0, sCookieValue, sizeof(sCookieValue));
				
				SetClientCookie(param1, g_hSpeedometerPosition, sCookieValue);
			}
			case 2:
			{
				FloatToString(-0.4, sCookieValue, sizeof(sCookieValue));
				
				SetClientCookie(param1, g_hSpeedometerPosition, sCookieValue);
			}
		}
	}
	
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public Action Menu_SpeedometerPosition(int client, int args)
{
	Menu menu = new Menu(MenuHandler1, MENU_ACTIONS_ALL);
	menu.SetTitle("Speedometer Position");
	menu.AddItem(CHOICE1, "Top");
	menu.AddItem(CHOICE2, "Middle");
	menu.AddItem(CHOICE3, "Bottom");
	menu.ExitButton = true;
	menu.Display(client, 20);
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	char sCookieValue[12], sCookieValue2[12], sCookieValue3[12];
	GetClientCookie(client, g_hSpeedometerEnabled, sCookieValue, sizeof(sCookieValue));
	GetClientCookie(client, g_hSpeedometerRate, sCookieValue2, sizeof(sCookieValue2));
	GetClientCookie(client, g_hSpeedometerPosition, sCookieValue3, sizeof(sCookieValue3));
	int cookieValue = StringToInt(sCookieValue);
	int cookieValue2 = StringToInt(sCookieValue2);
	float cookieValue3 = StringToFloat(sCookieValue3);
	
	if (!cookieValue2)
	{
		cookieValue2 = 3;
	}
	
	if (!cookieValue3)
	{
		cookieValue3 = 0.4;
	}
	
	if (cookieValue && g_iClientTickCount[client] >= cookieValue2)
	{
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", g_vecAbsVelocity[client]);
		g_fVelocity[client] = SquareRoot(g_vecAbsVelocity[client][0] * g_vecAbsVelocity[client][0] + g_vecAbsVelocity[client][1] * g_vecAbsVelocity[client][1]);
		
		if (g_fLastVelocity[client] > g_fVelocity[client])
		{
			SetHudTextParams(-1.0, cookieValue3, cookieValue2 / 100.0, 220, 20, 60, 255, 0, 0.0, 0.0);
		}
		else if (g_fLastVelocity[client] < g_fVelocity[client])
		{
			SetHudTextParams(-1.0, cookieValue3, cookieValue2 / 100.0, 0, 191, 255, 255, 0, 0.0, 0.0);
		}
		else //if (g_fLastVelocity[client] == g_fVelocity[client])
		{
			SetHudTextParams(-1.0, cookieValue3, cookieValue2 / 100.0, 255, 255, 255, 255, 0, 0.0, 0.0);
		}
		
		ShowHudText(client, 5, "%0.f", g_fVelocity[client]);
		
		g_fLastVelocity[client] = g_fVelocity[client];
		
		g_iClientTickCount[client] = 0;
		
	}
	else if (g_iClientTickCount[client] < cookieValue2)
	{
		g_iClientTickCount[client]++;
	}
} 
