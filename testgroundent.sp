
#include <sdkhooks>

public void OnPluginStart()
{
	HookEvent("player_jump", player_jump);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPutInServer(i);
	}
}

public void player_jump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	//PrintToChat(client, "jump");
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
    	SDKHook(client, SDKHook_GroundEntChangedPost, Hook_GroundEntChanged);
}

void Hook_GroundEntChanged(int client)
{
	int ground = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	PrintToChat(client, "gec %d %d", GetGameTickCount(), ground);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	// autohop
	int oldbuttons = GetEntProp(client, Prop_Data, "m_nOldButtons");
	SetEntProp(client, Prop_Data, "m_nOldButtons", (oldbuttons & ~IN_JUMP));

	int ground = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
	//if (ground == 0) PrintToChat(client, "%d", tickcount);

	return Plugin_Changed;
}
