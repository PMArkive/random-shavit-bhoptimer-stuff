/*
 * Mouse Tester
 * by: shavit
 *
 * This file is part of Mouse Tester.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
*/

#include <sourcemod>
#include <sdktools>
#include <emitsoundany>

#undef REQUIRE_PLUGIN
#include <shavit>
#include <sourcebans>

#pragma newdecls required
#pragma semicolon 1

#define MOUSETESTER_VERSION "1.0"

// commented - no bans, pure logging/notifications
#define DEBUG

char gS_BeepSound[PLATFORM_MAX_PATH];

bool gB_SourceBans = false;
bool gB_Shavit = false;

float gF_LastDetection[MAXPLAYERS+1];
int gI_DetectedTicks[MAXPLAYERS+1];
float gF_Angles[MAXPLAYERS+1][2];

char gS_LogBans[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name = "Mouse Tester Anti-Cheat",
	author = "shavit",
	description = "Detects an invulnerability in most injected cheats, and proceeds to ban.",
	version = MOUSETESTER_VERSION,
	url = "https://github.com/shavitush"
}

public void OnPluginStart()
{
	char[] sPath = new char[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, PLATFORM_MAX_PATH, "logs/shmt");

	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}

	BuildPath(Path_SM, gS_LogBans, PLATFORM_MAX_PATH, "logs/shmt_bans.log");

	CreateConVar("mouestester_version", MOUSETESTER_VERSION, "Plugin version.", (FCVAR_NOTIFY | FCVAR_DONTRECORD));

	gB_SourceBans = (LibraryExists("sourcebans") || LibraryExists("sourcebans++"));
	gB_Shavit = LibraryExists("shavit");
}

public void OnMapStart()
{
	// Beep sounds.
	Handle hConfig = LoadGameConfigFile("funcommands.games");

	if(hConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");

		return;
	}
	
	if(GameConfGetKeyValue(hConfig, "SoundBeep", gS_BeepSound, PLATFORM_MAX_PATH) && gS_BeepSound[0])
	{
		PrecacheSoundAny(gS_BeepSound, true);
	}
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "sourcebans") || StrEqual(name, "sourcebans++"))
	{
		gB_SourceBans = true;
	}

	else if(StrEqual(name, "shavit"))
	{
		gB_Shavit = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "sourcebans") || StrEqual(name, "sourcebans++"))
	{
		gB_SourceBans = false;
	}

	else if(StrEqual(name, "shavit"))
	{
		gB_Shavit = false;
	}
}

public void OnClientPutInServer(int client)
{
	gF_LastDetection[client] = -1.0;
	gI_DetectedTicks[client] = 0;

	gF_Angles[client][0] = -1.0;
	gF_Angles[client][1] = -1.0;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(!IsPlayerAlive(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	int ticks = GetGameTickCount();

	if(angles[1] > 180.0 || angles[1] < -180.0 || angles[0] > 90.0 || angles[0] < -90.0)
	{
		gI_DetectedTicks[client]++;

		if(gI_DetectedTicks[client] >= 75)
		{
			TriggerDetection(client, true, false, "Invalid angle (%d | %f | %f)", ticks, angles[0], angles[1]);

			gI_DetectedTicks[client] = 0;
		}

		return Plugin_Handled;
	}

	float delta1 = GetDelta(gF_Angles[client][1], angles[1]);
	float delta2 = GetDelta(gF_Angles[client][0], angles[0]);

	// there's data
	if(delta1 != 0.0 || delta2 != 0.0)
	{
		int dticks = 0;

		if(mouse[0] == 0 && (delta1 > 0.10 || delta1 < -0.10) && (buttons & IN_LEFT) == 0 && (buttons & IN_RIGHT) == 0 && (buttons & IN_ATTACK) > 0)
		{
			dticks++;
		}

		if(mouse[1] == 0 && (delta2 > 0.10 || delta2 < -0.10) && (buttons & IN_ATTACK) > 0)
		{
			dticks++;
		}

		if(dticks > 0)
		{
			gI_DetectedTicks[client]++;
		}

		if(gI_DetectedTicks[client] >= 60)
		{
			TriggerDetection(client, true, false, "Mouse discrepancy (ticks: %d | %d | {%d, %d} | {%f | %f})", gI_DetectedTicks[client], ticks, mouse[0], mouse[1], delta1, delta2);

			gI_DetectedTicks[client] = 0;

			return Plugin_Handled;
		}
	}

	if(ticks % 100 == 0)
	{
		gI_DetectedTicks[client] = 0;
	}

	gF_Angles[client][0] = angles[0];
	gF_Angles[client][1] = angles[1];

	return Plugin_Continue;
}

float GetDelta(float cur, float old)
{
	float delta = cur - old;

	if(delta < -180.0)
	{
		delta += 360.0;
	}

	else if(delta > 180.0)
	{
		delta -= 360.0;
	}

	return delta;
}

void NotifyAdmins(int client, const char[] reason)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i) && CheckCommandAccess(i, "sm_ban", ADMFLAG_BAN))
		{
			#if defined DEBUG
			PrintToClient(i, "(DEBUG) \x04Cheat detection! \x03%N (uid %d) - \"%s\"", client, client, reason);
			#else
			PrintToClient(i, "\x04Cheat detection! \x03%N (uid %d) - \"%s\"", client, client, reason);
			#endif

			EmitSoundToClientAny(i, gS_BeepSound, SOUND_FROM_PLAYER, SNDCHAN_STATIC, SNDLEVEL_NORMAL);
		}
	}
}

void PrintToClient(int client, const char[] text, any ...)
{
	char[] buffer = new char[300];
	VFormat(buffer, 300, text, 3);

	if(gB_Shavit)
	{
		Shavit_PrintToChat(client, "%s", buffer);
	}

	else
	{
		PrintToChat(client, "[SHMT]: %s", buffer);
	}
}

void TriggerDetection(int client, bool ban, bool notify, const char[] reason, any ...)
{
	char[] buffer = new char[300];
	VFormat(buffer, 300, reason, 5);

	if(notify)
	{
		NotifyAdmins(client, buffer);
	}

	if(ban)
	{
		#if !defined DEBUG
		LogToFile(gS_LogBans, "%L | Banned for - %s", client, buffer);

		Format(buffer, 300, "[SHMT auto-ban]: %s", buffer);

		if(gB_SourceBans)
		{
			SBBanPlayer(0, client, 129600, buffer);
		}

		else
		{
			BanClient(client, 0, BANFLAG_AUTO, buffer, buffer);
		}
		#else
		LogToFile(gS_LogBans, "%L | (DEBUG) Detected for - %s", client, buffer);
		#endif
	}
}
