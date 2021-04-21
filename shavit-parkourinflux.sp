#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <shavit>

#pragma newdecls required

#define TRACEDIF 8.0
#define PLYHULL_MINS view_as<float>( { -16.0, -16.0, 0.0 } )
#define PLYHULL_MAXS view_as<float>( { 16.0, 16.0, 72.0 } )

public Plugin myinfo = 
{
	name = "[shavit] Parkour",
	author = "Haze",
	description = "Shavit Parkour Style",
	version = "1.1",
	url = ""
}

// Player variable.
bool gB_ParkourStyle[MAXPLAYERS+1];
char g_sSpecialString[128];
float gF_TickInterval[MAXPLAYERS+1];

// Walls
float g_flNextWallJump[MAXPLAYERS+1];
float g_flNextBoost[MAXPLAYERS+1];

//ConVars
ConVar g_hSpecialString;
ConVar g_hWallJumpBoost;
ConVar g_hBoost;


public void OnPluginStart()
{
	g_hSpecialString    = CreateConVar("shavit_parkour_string", "parkour", "Special string value to use in shavit-styles.cfg");
	g_hWallJumpBoost    = CreateConVar("shavit_parkour_walljumpboost", "500.0", "Changes the wall jump boost on parkour style.", 0, true, 100.0);
	g_hBoost  			= CreateConVar("shavit_parkour_boost", "500.0", "Changes the boost on parkour style.", 0, true, 100.0);
	
	g_hSpecialString.AddChangeHook(ConVar_OnSpecialStringChanged);
	g_hSpecialString.GetString(g_sSpecialString, sizeof(g_sSpecialString));

	AutoExecConfig();
}

/**
 * ConVar changed callbacks.
 */
public void ConVar_OnSpecialStringChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sSpecialString, sizeof(g_sSpecialString));
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle)
{
	char[] sSpecial = new char[128];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sSpecial, 128);

	gB_ParkourStyle[client] = (StrContains(sSpecial, g_sSpecialString) != -1);
}

public void OnClientDisconnect(int client)
{
	gB_ParkourStyle[client] = false;
	gF_TickInterval[client] = 0.0;
	g_flNextWallJump[client] = 0.0;
	g_flNextBoost[client] = 0.0;
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style)
{
	if(!gB_ParkourStyle[client])
	{
		return Plugin_Continue;
	}
		
	if(status == Timer_Paused)
	{
		return Plugin_Continue;
	}
	
	gF_TickInterval[client] += GetTickInterval();
	
	if(buttons & IN_ATTACK && g_flNextBoost[client] < gF_TickInterval[client])
	{
		float vec[3], velocity[3];
		GetClientEyeAngles(client, vec);
		GetAngleVectors(vec, vec, NULL_VECTOR, NULL_VECTOR);
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
		
		for(int i = 0; i < 3; i++)
		{
			velocity[i] += vec[i] * g_hBoost.FloatValue;
		}
		
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
		
		g_flNextBoost[client] = gF_TickInterval[client] + 3.0;
	}

	if(buttons & IN_ATTACK2 && g_flNextWallJump[client] < gF_TickInterval[client])
	{
		float pos[3], normal[3], velocity[3];
		
		GetClientAbsOrigin(client, pos);
		
		if(FindWall(pos, normal))
		{
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
			
			for(int i = 0; i < 3; i++)
			{
				velocity[i] += normal[i] * g_hWallJumpBoost.FloatValue;
			}
			
			if(velocity[2] < g_hWallJumpBoost.FloatValue)
			{
				velocity[2] = g_hWallJumpBoost.FloatValue;
			}
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
			
			g_flNextWallJump[client] = gF_TickInterval[client] + 0.5;
		}
	}

	return Plugin_Continue;
}

stock bool FindWall(const float pos[3], float normal[3])
{
    float end[3];
    
    end = pos; end[0] += TRACEDIF;
    if(GetTraceNormal(pos, end, normal)) return true;
    
    end = pos; end[0] -= TRACEDIF;
    if(GetTraceNormal(pos, end, normal)) return true;
    
    end = pos; end[1] += TRACEDIF;
    if(GetTraceNormal(pos, end, normal)) return true;
    
    end = pos; end[1] -= TRACEDIF;
    if(GetTraceNormal(pos, end, normal)) return true;
    
    end = pos; end[2] += TRACEDIF;
    if(GetTraceNormal(pos, end, normal)) return true;
    
    end = pos; end[2] -= TRACEDIF;
    if(GetTraceNormal(pos, end, normal)) return true;
    
    return false;
}

stock bool GetTraceNormal(const float pos[3], const float end[3], float normal[3])
{
    TR_TraceHullFilter(pos, end, PLYHULL_MINS, PLYHULL_MAXS, MASK_PLAYERSOLID, TrcFltr_AnythingButThoseFilthyScrubs);
    
    if(TR_GetFraction() != 1.0)
    {
        TR_GetPlaneNormal(null, normal);
        return true;
    }
    
    return false;
}

public bool TrcFltr_AnythingButThoseFilthyScrubs(int ent, int mask, any data)
{
    return (ent == 0 || ent > MaxClients);
}