#include <sourcemod>
#include <sdktools>
#pragma newdecls required
#pragma semicolon 1

float gF_LastSpeed[MAXPLAYERS + 1];
float g_flOldYawAngle[MAXPLAYERS + 1];
bool gB_TouchingTrigger[MAXPLAYERS + 1];

public void OnPluginStart()
{
	HookEvent("round_start", OnRoundStart);
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	HookEntityOutput("trigger_push", "OnStartTouch", StartTouchTrigger);
	HookEntityOutput("trigger_push", "OnEndTouch", EndTouchTrigger);
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	float oldyaw = g_flOldYawAngle[client];
	float delta = AngleNormalize(angles[1] - oldyaw);
    
	g_flOldYawAngle[client] = angles[1];
	
	float fAbsVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fAbsVelocity);
	
	float fCurrentSpeed = SquareRoot(Pow(fAbsVelocity[0], 2.0) + Pow(fAbsVelocity[1], 2.0));
	float fGain = GetVelocityGain(client, fCurrentSpeed);
	float fAngleDiff = GetAngleDifference(client, angles);
	bool bPlayerStrafing = ((vel[0] != 0.0 || vel[1] != 0.0) && fAngleDiff != 0.0);
	
	if(!bPlayerStrafing || gB_TouchingTrigger[client] || (GetEntityFlags(client) & FL_ONGROUND) || GetEntityMoveType(client) != MOVETYPE_WALK)
	{
		return Plugin_Continue;
	}
	
	if((buttons & IN_FORWARD && buttons & IN_MOVELEFT) || (buttons & IN_FORWARD && buttons & IN_MOVERIGHT) || (buttons & IN_BACK && buttons & IN_MOVELEFT) || (buttons & IN_BACK && buttons & IN_MOVERIGHT))
	{
		return Plugin_Continue;
	}
	
	if((buttons & IN_FORWARD) && delta < 0.0)
	{
		return Plugin_Continue;
	}
	
	if((buttons & IN_BACK) && delta > 0.0)
	{
		return Plugin_Continue;
	}
		
	if((buttons & IN_MOVELEFT) && delta < 0.0)
	{
		return Plugin_Continue;
	}

	if((buttons & IN_MOVERIGHT) && delta > 0.0)
	{
		return Plugin_Continue;
	}
	
	float fTickrate = 1.0 / GetTickInterval();
	float fTickDiff = 100.0 / fTickrate;
	
	float fStrafingAngle = GetStrafingAngle(fAngleDiff, fTickDiff);
	
	SimulateStrafingTickrate(client, fAbsVelocity, fCurrentSpeed, fGain, fStrafingAngle, fTickrate, fTickDiff);
	
	return Plugin_Continue;
}

void SimulateStrafingTickrate(int client, float fAbsVelocity[3], float fCurrentSpeed, float fGain, float fStrafingAngle, float fTickrate, float fTickDiff)
{
	float fMultiplier = 128.0 / 100.0;
	float fNewGain = fCurrentSpeed / (fCurrentSpeed + (fMultiplier * (fStrafingAngle * 0.1) * fTickDiff));
	fAbsVelocity[0] /= fNewGain;
	fAbsVelocity[1] /= fNewGain;
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fAbsVelocity);
}

float GetVelocityGain(int client, float fCurrentSpeed)
{
	float fGain = fCurrentSpeed - gF_LastSpeed[client];
	gF_LastSpeed[client] = fCurrentSpeed;
	
	return fGain;
}

float GetAngleDifference(int client, float angles[3])
{
	float fTempAngle = angles[1];
	
	float fAngles[3];
	GetClientEyeAngles(client, fAngles);
	float fAngleDiff = (fTempAngle - fAngles[1]);
	
	if(fAngleDiff < 0.0)
	{
		fAngleDiff = -fAngleDiff;
	}
	
	return fAngleDiff;
}

float GetStrafingAngle(float fAngleDiff, float fTickDiff)
{
	if(fAngleDiff > (fTickDiff * 10.0))
	{
		fAngleDiff = ((fTickDiff * 10.0) * 2.0) - fAngleDiff;
		
		if(fAngleDiff < 0.0)
		{
			fAngleDiff = 0.0;
		}
	}
	
	return fAngleDiff;
}

float AngleNormalize(float flAngle)
{
	if (flAngle > 180.0)
		flAngle -= 360.0;
	else if (flAngle < -180.0)
		flAngle += 360.0;

	return flAngle;
}

public int StartTouchTrigger(const char[] output, int entity, int client, float delay)
{
	if(client < 1 || client > MaxClients)
	{
		return;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	RequestFrame(StopPlugin, GetClientSerial(client));
}

void StopPlugin(int data)
{
	int client = GetClientFromSerial(data);
	gB_TouchingTrigger[client] = true;
}

public int EndTouchTrigger(const char[] output, int entity, int client, float delay)
{
	if(client < 1 || client > MaxClients)
	{
		return;
	}
	
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return;
	}
	
	RequestFrame(ResumePlugin, GetClientSerial(client));
}

void ResumePlugin(int data)
{
	int client = GetClientFromSerial(data);
	gB_TouchingTrigger[client] = false;
}