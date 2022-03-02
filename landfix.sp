#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#pragma semicolon 1

public Plugin myinfo = {
	name = "LandFix",
	author = "Haze, edited by Blank",
	description = "",
	version = "1.0",
	url = ""
}

ConVar gCV_Units = null;
Handle gH_CookieEnabled = null;
Handle gH_LandfixType = null;

int gI_TicksOnGround[MAXPLAYERS + 1];
int gI_Jump[MAXPLAYERS + 1];

bool gB_LandfixType[MAXPLAYERS + 1] = {false, ...};
bool gB_Enabled[MAXPLAYERS+1] = {false, ...};

public void OnPluginStart() {
	gCV_Units = CreateConVar("landfix_units", "1.5", "", 0, true, 0.0, true, 2.0);
	
	RegConsoleCmd("sm_landfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_lfix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_land", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64fix", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_64", Command_LandFix, "Landfix");
	RegConsoleCmd("sm_landfixtype", Command_LandFixType, "Landfix Type");
	RegConsoleCmd("sm_lfixtype", Command_LandFixType, "Landfix Type");
	
	gH_CookieEnabled = RegClientCookie("landfix_enabled", "landfix_enabled", CookieAccess_Protected);
	gH_LandfixType = RegClientCookie("landfix_type", "landfix_type", CookieAccess_Protected);
	
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
			OnClientPutInServer(i);
		}
	}
	AutoExecConfig();
}

public void OnClientCookiesCached(int client) {
	char strCookie[8];
	GetClientCookie(client, gH_CookieEnabled, strCookie, sizeof(strCookie));
	gB_Enabled[client] = view_as<bool>(StringToInt(strCookie));
	GetClientCookie(client, gH_LandfixType, strCookie, sizeof(strCookie));
	gB_LandfixType[client] = view_as<bool>(StringToInt(strCookie));
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_GroundEntChangedPost, OnGroundChange);
	
	gI_Jump[client] = 0;
}

public Action OnPlayerRunCmd(int client, int &buttons) {
	if(IsFakeClient(client)) return Plugin_Continue;
	if(gB_Enabled[client]) {
		if(GetEntityFlags(client) & FL_ONGROUND) {
			if(gI_TicksOnGround[client] > 15) {
				gI_Jump[client] = 0;
			}
			gI_TicksOnGround[client]++;
			if(buttons & IN_JUMP && gI_TicksOnGround[client] == 1) {
				gI_TicksOnGround[client] = 0;
			}
		} else {
			gI_TicksOnGround[client] = 0;
		}
	}
	return Plugin_Continue;
}

public E_PlayerJump(Handle event, const char[] name, bool dontBroadcast) {
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	if(!gB_LandfixType[client]) {
		if(IsFakeClient(client)) return;
		if(gB_Enabled[client]) {
			gI_Jump[client]++;
			if(gI_Jump[client]>1) {
				CreateTimer(0.1, TimerFix);
			}
		}
	}
}

public void OnGroundChange(int client) {
	if(!gB_Enabled[client])
		return;
	if(gB_LandfixType[client]) {
		RequestFrame(DoLandFix, client);
	}
}

public Action Command_LandFixType(int client, int args) {
	if(client == 0) return Plugin_Handled;

	gB_LandfixType[client] = !gB_LandfixType[client];
	SetClientCookie(client, gH_LandfixType, gB_LandfixType[client] ? "1" : "0");
	PrintToChat(client, "Land Fix Type: %s.", gB_LandfixType[client] ? "Haze" : "Cherry");
	return Plugin_Handled;
}

public Action Command_LandFix(int client, int args) {
	if(client == 0) return Plugin_Handled;

	gB_Enabled[client] = !gB_Enabled[client];
	SetClientCookie(client, gH_CookieEnabled, gB_Enabled[client] ? "1" : "0");
	PrintToChat(client, "Land Fix: %s.", gB_Enabled[client] ? "On" : "Off");
	return Plugin_Handled;
}

//Thanks MARU for the idea/http://steamcommunity.com/profiles/76561197970936804
float GetGroundUnits(int client) {
	if (!IsPlayerAlive(client)) return 0.0;
	if (GetEntityMoveType(client) != MOVETYPE_WALK) return 0.0;
	if (GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1) return 0.0;

	float origin[3], originBelow[3], landingMins[3], landingMaxs[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	GetEntPropVector(client, Prop_Data, "m_vecMins", landingMins);
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", landingMaxs);
	
	originBelow[0] = origin[0];
	originBelow[1] = origin[1];
	originBelow[2] = origin[2] - 2.0;

	TR_TraceHullFilter(origin, originBelow, landingMins, landingMaxs, MASK_PLAYERSOLID, PlayerFilter, client);
	
	if(TR_DidHit()) {
		TR_GetEndPosition(originBelow, null);
		float defaultheight = originBelow[2] - RoundToFloor(originBelow[2]);
		if(defaultheight > 0.03125) defaultheight = 0.03125;
		float heightbug = origin[2] - originBelow[2] + defaultheight;
		return heightbug;
	} else {
		return 0.0;
	}
}

void DoLandFix(int client) {
	if(GetEntPropEnt(client, Prop_Data, "m_hGroundEntity") != -1) {
		float difference = (gCV_Units.FloatValue - GetGroundUnits(client)), origin[3];
		// float difference = (1.50 - GetGroundUnits(client)), origin[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
		origin[2] += difference;
		SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", origin);
	}
}

public Action TimerFix(Handle timer, any data)
{
	for(int client = 1; client <= MaxClients; client++) {
		float cll[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", cll);
		cll[2] += 1.0;
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cll);
		CreateTimer(0.05, TimerFix2);
	}
}

public Action TimerFix2(Handle timer, any data)
{
	for(int client = 1; client <= MaxClients; client++) {
		if(!(GetEntityFlags(client) & FL_ONGROUND)) {
			float cll[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", cll);
			cll[2] -= 1.5;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, cll);
		}
	}
}

public bool PlayerFilter(int entity, int mask) {
	return !(1 <= entity <= MaxClients);
}