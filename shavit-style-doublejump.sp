#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <shavit>

// Server variables.
ConVar g_hSpecialString;
ConVar g_hMaxDoubleJumps;
ConVar g_hDoubleJumpForce;

char g_sSpecialString[stylestrings_t::sSpecialString];
int g_iMaxDoubleJumps;
float g_fDoubleJumpForce;

// Player variables.
bool g_bCanDoubleJump[MAXPLAYERS + 1];
int g_iDoubleJumps[MAXPLAYERS + 1] = {1, ...};

// Enums.
enum VelocityOverride
{
	VO_None = 0,
	VO_Velocity,
	VO_OnlyWhenNegative,
	VO_InvertReuseVelocity
};

public Plugin myinfo = {
	name = "[shavit-style] Double Jump",
	author = "Adam & Chanz",
	description = "Adds a custom double jump style to shavit's bhoptimer.",
	version = "1.1",
	url = "https://github.com/strafe/shavit-style-doublejump"
}

/*
 * Forwards.
 */
public void OnPluginStart()
{
	g_hSpecialString = CreateConVar("ss_doublejump_specialstring", "doublejump", "Special string value to use in shavit-styles.cfg");
	g_hSpecialString.AddChangeHook(ConVar_OnSpecialStringChanged);
	g_hSpecialString.GetString(g_sSpecialString, sizeof(g_sSpecialString));

	g_hMaxDoubleJumps = CreateConVar("ss_doublejump_max_double_jumps", "1", "The maximum amount of times a player can jump in the air after their initial jump.", _, true, 0.0);
	g_hMaxDoubleJumps.AddChangeHook(ConVar_OnMaxDoubleJumpsChanged);
	g_iMaxDoubleJumps = g_hMaxDoubleJumps.IntValue;

	g_hDoubleJumpForce = CreateConVar("ss_doublejump_force", "290.0", "The amount of vertical boost to apply to a player when double jumping.", _, true, 0.0);
	g_hDoubleJumpForce.AddChangeHook(ConVar_OnDoubleJumpForceChanged);
	g_fDoubleJumpForce = g_hDoubleJumpForce.FloatValue;

	AutoExecConfig();
}

public void OnClientDisconnect(int client)
{
	g_bCanDoubleJump[client] = false;
	g_iDoubleJumps[client] = 1;
}

public Action Shavit_OnUserCmdPre(int client, int &buttons)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client) || !g_bCanDoubleJump[client])
		return Plugin_Continue;

	return HandleJumpingClient(client, buttons);
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	char sStyleSpecial[sizeof(stylestrings_t::sSpecialString)];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sStyleSpecial, sizeof(sStyleSpecial));

	g_bCanDoubleJump[client] = (StrContains(sStyleSpecial, g_sSpecialString) != -1);
}

/**
 * ConVar changed callbacks.
 */
public void ConVar_OnSpecialStringChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.GetString(g_sSpecialString, sizeof(g_sSpecialString));
}

public void ConVar_OnMaxDoubleJumpsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iMaxDoubleJumps = convar.IntValue;
}

public void ConVar_OnDoubleJumpForceChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_fDoubleJumpForce = convar.FloatValue;
}

/**
 * Helpers from Infinite-Jumping by Chanz unless otherwise noted.
 * https://github.com/chanz/infinite-jumping
 */
Action HandleJumpingClient(int client, int &buttons)
{
	static int s_iLastButtons[MAXPLAYERS + 1] = {0, ...};
	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");


	if (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2)
		return Plugin_Continue;
	
	if (GetEntityMoveType(client) == MOVETYPE_LADDER)
		return Plugin_Continue;

	if (iGroundEntity != -1)
		g_iDoubleJumps[client] = 1;
	
	if ((buttons & IN_JUMP) == IN_JUMP && iGroundEntity == -1)
	{
		// Originally this block was described as "perfect double jump".
		float fVelocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVelocity);
					
		if (fVelocity[2] < 0.0)
			DoubleJump(client);
	}

	s_iLastButtons[client] = buttons;
	return Plugin_Continue;
}

void DoubleJump(int client)
{
	if (1 <= g_iDoubleJumps[client] <= g_iMaxDoubleJumps)
	{
		g_iDoubleJumps[client]++;

		float fAngles[3] = {-90.0, 0.0, 0.0};
		VelocityOverride hVelocityOverride[3] = {VO_None, VO_None, VO_Velocity};
		PushClient(client, fAngles, g_fDoubleJumpForce, hVelocityOverride);
	}
}

void PushClient(int client, float angles[3], float power, VelocityOverride override[3]=VO_None)
{
	// Thank you DarthNinja & javalia for this.
	float fNewVelocity[3];
	float fForwardVector[3];
	
	GetAngleVectors(angles, fForwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(fForwardVector, fForwardVector);
	ScaleVector(fForwardVector, power);

	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fNewVelocity);
	
	for (int i = 0; i < 3; i++)
	{
		switch (override[i])
		{
			case VO_Velocity:
			{
				fNewVelocity[i] = 0.0;
			}
			case VO_OnlyWhenNegative:
			{				
				if (fNewVelocity[i] < 0.0)
					fNewVelocity[i] = 0.0;
			}
			case VO_InvertReuseVelocity:
			{				
				if(fNewVelocity[i] < 0.0)
					fNewVelocity[i] *= -1.0;
			}
		}
		
		fNewVelocity[i] += fForwardVector[i];
	}
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fNewVelocity);
}
