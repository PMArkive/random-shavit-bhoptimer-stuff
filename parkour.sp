#include <sourcemod>
#include <sdktools>
#include <shavit>

public Plugin myinfo = 
{
	name = "Parkour Style",
	author = "Hunny Bop, olivia",
	description = "Original Parkour style. Ported to bhoptimer by olivia 9 Aug 2025",
	version = "1.0",
	url = "http://steamcommunity.com/profiles/76561198156395464/"
}

float g_LastSideMove[MAXPLAYERS+1][2];
int g_LastButtons[MAXPLAYERS+1];
int g_WallJumpCount[MAXPLAYERS+1];
bool g_bWaitingForGround[MAXPLAYERS+1];
int g_LandingTick[MAXPLAYERS+1];
int g_LastTapKey[MAXPLAYERS+1];
int g_LastTapTick[MAXPLAYERS+1];
int g_LastDodgeTick[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_Spawn, EventHookMode_Post);
}

public void Event_Spawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(IsValidClient(client))
		SetEntProp(client, Prop_Data, "m_ArmorValue", 100);
}

public void OnMapStart()
{
	CreateTimer(1.0, Timer_Regen, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	g_LastSideMove[client][0] = 0.0;
	g_LastSideMove[client][1] = 0.0;
	g_LastButtons[client] = 0;
	g_WallJumpCount[client] = 0;
	g_bWaitingForGround[client] = false;
	g_LandingTick[client] = 0;
	g_LastTapKey[client] = 0;
	g_LastTapTick[client] = 0;
	g_LastDodgeTick[client] = 0;
}

public Action Shavit_OnStart(int client, int track)
{
	OnClientPutInServer(client);
}

public Action Shavit_OnUserCmdPre(int client, int &buttons, int &impulse, float vel[3], float angles[3], TimerStatus status, int track, int style)
{
	if(!IsPlayerAlive(client) || IsFakeClient(client))
		return Plugin_Continue;

	char sSpecial[32];
	Shavit_GetStyleStrings(style, sSpecialString, sSpecial, sizeof(sSpecial));
	if(StrContains(sSpecial, "parkour", false) == -1)
		return Plugin_Continue;

	CheckForKeyTap(client, buttons);
	int energy = GetEntProp(client, Prop_Data, "m_ArmorValue")

	if(buttons & IN_ATTACK2 && energy == 100)
		WallRun(client);

	g_LastButtons[client] = buttons;
	return Plugin_Continue;
}

public Action Timer_Regen(Handle timer, any data)
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsValidClient(client, true))
		{
			char sSpecial[32];
			Shavit_GetStyleStrings(Shavit_GetBhopStyle(client), sSpecialString, sSpecial, sizeof(sSpecial));
			if(StrContains(sSpecial, "parkour", false) != -1)
			{
				int energy = GetEntProp(client, Prop_Data, "m_ArmorValue");

				if((energy + 20) > 100)
					energy = 100;
				else
					energy += 20;

				SetEntProp(client, Prop_Data, "m_ArmorValue", energy);
			}
		}
	}
	return Plugin_Handled;
}
 
public void WallRun(int client)
{
	bool bCanWallRun;

	float vAng[3];
	GetClientEyeAngles(client, vAng);
	vAng[0] = 0.0;

	float vDodgeDir[3];

	if(GetEntityFlags(client) & FL_ONGROUND)
		bCanWallRun = false;
	else
	{
		float vPos[3];
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos);

		GetAngleVectors(vAng, NULL_VECTOR, vDodgeDir, NULL_VECTOR); //Trace If Wall To Player's Left

		float vTraceAngle[3];
		vTraceAngle[0] = vDodgeDir[0];
		vTraceAngle[1] = vDodgeDir[1];
		vTraceAngle[2] = vDodgeDir[2];

		NegateVector(vTraceAngle);
		GetVectorAngles(vTraceAngle, vTraceAngle);

		TR_TraceRayFilter(vPos, vTraceAngle, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);

		if(TR_DidHit())
		{
			float vHitPos[3];
			TR_GetEndPosition(vHitPos);
		   
			if(GetVectorDistance(vPos, vHitPos) < 30)
				bCanWallRun = true;
			else
			{
				NegateVector(vDodgeDir); //Didn't Find Wall, Trace To Player's Right
			   
				vTraceAngle[0] = vDodgeDir[0];
				vTraceAngle[1] = vDodgeDir[1];
				vTraceAngle[2] = vDodgeDir[2];

				NegateVector(vTraceAngle);
				GetVectorAngles(vTraceAngle, vTraceAngle);
			   
				TR_TraceRayFilter(vPos, vTraceAngle, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
			   
				if(TR_DidHit())
				{
					float vHitPosi[3];
					TR_GetEndPosition(vHitPosi);
		   
					if(GetVectorDistance(vPos, vHitPosi) < 30)
						bCanWallRun = true;
				}
			}
		}
	}

	if(bCanWallRun == true)
	{
		GetAngleVectors(vAng, vDodgeDir, NULL_VECTOR, NULL_VECTOR)
		vDodgeDir[0] *= 500.0;
		vDodgeDir[1] *= 500.0;
		vDodgeDir[2] *= 10.0;
	
		float vVel[3];
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
			
		float vResult[3];
		AddVectors(vVel, vDodgeDir, vResult);
	   
		SetEntityGravity(client, Pow(Pow(100.0, 3.0), -1.0));
	   
		TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vResult);
	   
		SetEntityGravity(client, 0.9);
	   
		SetEntProp(client, Prop_Data, "m_ArmorValue", 0);
	}
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data && !(0 < entity <= MaxClients);
}
 
public CheckForKeyTap(client, buttons)
{
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		g_WallJumpCount[client] = 0;
		if(g_bWaitingForGround[client] == true)
		{
			g_bWaitingForGround[client] = false;
			g_LandingTick[client] = GetGameTickCount();
		}
	}

	if((GetGameTickCount() - g_LandingTick[client]) < 30)
		return;

	if(!(g_LastButtons[client] & IN_MOVERIGHT) && (buttons & IN_MOVERIGHT))
		OnClientTappedKey(client, IN_MOVERIGHT);

	if(!(g_LastButtons[client] & IN_MOVELEFT) && buttons & IN_MOVELEFT)
		OnClientTappedKey(client, IN_MOVELEFT);

	if(!(g_LastButtons[client] & IN_FORWARD) && buttons & IN_FORWARD)
		OnClientTappedKey(client, IN_FORWARD);

	if(!(g_LastButtons[client] & IN_BACK) && buttons & IN_BACK)
		OnClientTappedKey(client, IN_BACK);
		
	/*if(g_LastSideMove[client][1] <= 0 && vel[1] > 0)
		OnClientTappedKey(client, IN_MOVERIGHT);

	else if(g_LastSideMove[client][1] >= 0 && vel[1] < 0)
		OnClientTappedKey(client, IN_MOVELEFT);
	else if(g_LastSideMove[client][0] <= 0 && vel[0] > 0)
		OnClientTappedKey(client, IN_FORWARD);
	else if(g_LastSideMove[client][0] >= 0 && vel[0] < 0)
		OnClientTappedKey(client, IN_BACK);*/
	
}
 
public void OnClientTappedKey(int client, int Key)
{
	if(g_LastTapKey[client] == Key && (GetGameTickCount() - g_LastTapTick[client] < 20))
	   OnClientDoubleTappedKey(client, Key);

	g_LastTapKey[client]  = Key;
	g_LastTapTick[client] = GetGameTickCount();
}
 
public void OnClientDoubleTappedKey(int client, int Key)
{
	float vAng[3];
	GetClientEyeAngles(client, vAng);
	vAng[0] = 0.0; // Ensures consistent jumps if player is considered to be facing straight outwards

	// Get direction player wants to walljump (not the direction the wall is)
	float vDodgeDir[3];

	if(Key == IN_MOVERIGHT)
		GetAngleVectors(vAng, NULL_VECTOR, vDodgeDir, NULL_VECTOR);

	else if(Key == IN_MOVELEFT)
	{
		GetAngleVectors(vAng, NULL_VECTOR, vDodgeDir, NULL_VECTOR);
		NegateVector(vDodgeDir);
	}

	else if(Key == IN_FORWARD)
		GetAngleVectors(vAng, vDodgeDir, NULL_VECTOR, NULL_VECTOR);

	else if(Key == IN_BACK)
	{
		GetAngleVectors(vAng, vDodgeDir, NULL_VECTOR, NULL_VECTOR);
		NegateVector(vDodgeDir);
	}
   
	// Checks if a client is allowed to walljump (Not On Ground, Next To Wall)
	bool bCanDodge;
	if(GetEntityFlags(client) & FL_ONGROUND)
		bCanDodge = false;
	else
	{
		float vPos[3];
		GetEntPropVector(client, Prop_Data, "m_vecOrigin", vPos);
	   
		float vTraceAngle[3];
		vTraceAngle[0] = vDodgeDir[0];
		vTraceAngle[1] = vDodgeDir[1];
		vTraceAngle[2] = vDodgeDir[2];
		NegateVector(vTraceAngle);
		GetVectorAngles(vTraceAngle, vTraceAngle);
	   
		TR_TraceRayFilter(vPos, vTraceAngle, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, TraceRayDontHitSelf, client);
	   
		if(TR_DidHit())
		{
			float vHitPos[3];
			TR_GetEndPosition(vHitPos);

			if(GetVectorDistance(vPos, vHitPos) < 30)
				bCanDodge = true;
		}
	}

	// Start walljump
	if(bCanDodge == true)
	{
		if(g_WallJumpCount[client] < 3)
		{
			vDodgeDir[0] *= 300.0;
			vDodgeDir[1] *= 300.0;
		   
			float vVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
		   
			float vResult[3];
			AddVectors(vVel, vDodgeDir, vResult);
			vResult[2] = 225.0;
		   
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vResult);
		   
			g_LastDodgeTick[client] = GetGameTickCount();
		   
			float vPos[3];
			GetClientEyePosition(client, vPos);
		   
			g_WallJumpCount[client]++;
		   
			g_bWaitingForGround[client] = true;
		}
	}
}
