#include <sourcemod>
#include <shavit>
#include <clientprefs>

public Plugin myinfo = 
{
	name = "[shavit] On Ground Ticks",
	author = "appa",
	description = "",
	version = "1.0",
	url = ""
}

bool gB_GroundTicksEnabled[MAXPLAYERS + 1];
bool gB_PlayerInZone[MAXPLAYERS + 1];
int gI_GroundTicks[MAXPLAYERS + 1];

Handle gH_GroundTicksCookie;

public void OnPluginStart()
{
    RegConsoleCmd("sm_groundticks", Command_GroundTicks, "Toggles Ground Ticks Printing");

    gH_GroundTicksCookie = RegClientCookie("GroundTicks_Enabled", "Ground Ticks Enabled", CookieAccess_Protected);

	HookEvent("player_jump", OnPlayerJump);
}

public void OnClientCookiesCached(int client)
{
    char sCookie[8];

    GetClientCookie(client,gH_GroundTicksCookie, sCookie, sizeof(sCookie));

	gB_GroundTicksEnabled[client] = view_as<bool>(StringToInt(sCookie));
}

public Action Command_GroundTicks(int client, int args)
{
    gB_GroundTicksEnabled[client] = !gB_GroundTicksEnabled[client];

    char sCookie[8];
    IntToString(gB_GroundTicksEnabled[client], sCookie, sizeof(sCookie));
    SetClientCookie(client, gH_GroundTicksCookie, sCookie);

    Shavit_PrintToChat(client, "Ground Ticks %s.", gB_GroundTicksEnabled[client] ? "Enabled" : "Disabled");
}

public void Shavit_OnEnterZone(int client, int type, int track, int id, int entity, int data)
{
    gB_PlayerInZone[client] = true;
    gI_GroundTicks[client] = 0;
}

public void Shavit_OnLeaveZone(int client, int type, int track, int id, int entity, int data)
{
    gB_PlayerInZone[client] = false;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if(gB_GroundTicksEnabled[client] && !gB_PlayerInZone[client] && !(buttons & IN_JUMP) && (GetEntityFlags(client) & FL_ONGROUND))
    {
        gI_GroundTicks[client]++;
    }
}

public Action OnPlayerJump(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    if(IsValidClient(client) && gB_GroundTicksEnabled[client] && Shavit_GetClientJumps(client) > 0 && gI_GroundTicks[client] > 0)
    {
        Shavit_PrintToChat(client, "On Ground For %d Ticks", gI_GroundTicks[client]);
        gI_GroundTicks[client] = 0;
    }
}