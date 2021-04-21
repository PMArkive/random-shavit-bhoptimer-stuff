#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <shavit>

// Defs.
#define MAX_DOT -0.8

// Server variables.
ConVar g_hSpecialString;
char g_sSpecialString[stylestrings_t::sSpecialString];

// Player variables.
bool g_bEnforceBackwards[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[shavit-style] Backwards",
	author = "Adam & Mehis",
	description = "Adds a custom backwards style to shavit's bhoptimer.",
	version = "1.0",
	url = "https://github.com/strafe/shavit-style-backwards"
}

/*
 * Forwards.
 */
public void OnPluginStart()
{
	g_hSpecialString = CreateConVar("ss_backwards_specialstring", "backwards", "Special string value to use in shavit-styles.cfg");
	g_hSpecialString.AddChangeHook(ConVar_OnSpecialStringChanged);
	g_hSpecialString.GetString(g_sSpecialString, sizeof(g_sSpecialString));

	AutoExecConfig();
}

public void OnClientDisconnect(int client)
{
	g_bEnforceBackwards[client] = false;
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3])
{
	if (!IsPlayerAlive(client) || IsFakeClient(client) || !g_bEnforceBackwards[client])
		return Plugin_Continue;

	// Honor some key-blocking related behaviour from shavit-core.
	MoveType hMoveType = GetEntityMoveType(client);
	if(hMoveType == MOVETYPE_NOCLIP || hMoveType == MOVETYPE_LADDER || Shavit_InsideZone(client, Zone_Freestyle, -1))
		return Plugin_Continue;

	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	if (iGroundEntity != -1)
		return Plugin_Continue;

	// Backwards enforcement by Mehis (https://github.com/InfluxTimer/sm-timer/blob/master/addons/sourcemod/scripting/influx_style_backwards.sp).
	float eye[3];
	float velocity[3];

	GetClientEyeAngles(client, eye);
	eye[0] = Cosine(DegToRad(eye[1]));
	eye[1] = Sine(DegToRad(eye[1]));
	eye[2] = 0.0;

	GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
	velocity[2] = 0.0;

	float len = SquareRoot(velocity[0] * velocity[0] + velocity[1] * velocity[1]);
	velocity[0] /= len;
	velocity[1] /= len;
	

	float val = GetVectorDotProduct(eye, velocity);
	if (val > MAX_DOT)
	{
		vel[0] = 0.0;
		vel[1] = 0.0;

		buttons &= ~IN_FORWARD;
		buttons &= ~IN_MOVELEFT;
		buttons &= ~IN_MOVERIGHT;
		buttons &= ~IN_BACK;
	}

	return Plugin_Continue;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	char sStyleSpecial[sizeof(stylestrings_t::sSpecialString)];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sStyleSpecial, sizeof(sStyleSpecial));

	g_bEnforceBackwards[client] = (StrContains(sStyleSpecial, g_sSpecialString) != -1);
}

/**
 * ConVar changed callbacks.
 */
public void ConVar_OnSpecialStringChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sSpecialString, sizeof(g_sSpecialString));
}