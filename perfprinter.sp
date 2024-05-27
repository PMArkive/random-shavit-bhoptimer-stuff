// stolen from https://github.com/shavitush/bhoptimer/blob/2805cd94c631909946f994aadda4bbaedd5dd2ea/addons/sourcemod/scripting/shavit-core.sp
// see there for gpl3 license & credits

#include <shavit/core>

int gB_OnGround[MAXPLAYERS+1];
int gB_Jumped[MAXPLAYERS+1];
int gI_LandingTick[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_jump", player_jump);
}

public void player_jump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsFakeClient(client) /*&& Shavit_GetTimerStatus(client) == Timer_Running*/)
	{
		gB_Jumped[client] = true;
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if (IsFakeClient(client))
		return Plugin_Continue;
	if (!IsPlayerAlive(client))
		return Plugin_Continue;
	/*if (Shavit_GetTimerStatus(client) != Timer_Running)
		return Plugin_Continue;
	if (Shavit_GetStyleSettingBool(client, "autobhop"))
		return Plugin_Continue;*/

	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	MoveType mtMoveType = GetEntityMoveType(client);
	bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);
	bool bOnGround = (!bInWater && mtMoveType == MOVETYPE_WALK && iGroundEntity != -1);

	if (bOnGround && !gB_OnGround[client])
	{
		gI_LandingTick[client] = tickcount;
	}
	else if (!bOnGround && gB_OnGround[client] && gB_Jumped[client])
	{
		int iDifference = (tickcount - gI_LandingTick[client]);

		if (iDifference < 10)
		{
			PrintToChat(client, "jump tick difference = %d%s", iDifference, iDifference == 1 ? " (perf!)" : "");
		}
	}

	gB_Jumped[client] = false;
	gB_OnGround[client] = bOnGround;

	return Plugin_Continue;
}
