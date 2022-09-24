#include <shavit/steamid-stocks>

#include <sourcemod>
#include <string>
#include <sdkhooks>

#if 0
public void OnGameFrame()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			PrintHintText(i, "%d %.2f", GetGameTickCount(), GetGameTime());
			//PrintToServer("%d %f", GetEntProp(i, Prop_Data, "m_bHasWalkMovedSinceLastJump", 1), GetEntPropFloat(i, Prop_Data, "m_ignoreLadderJumpTime"));
			int x = SteamIDToAccountID("[U:1:2147483649]");
			PrintToServer("%d %u", x, x);
			break;
		}
	}
}
#endif

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "info_player_counterterrorist") || StrEqual(classname, "info_player_terrorist"))
	{
		PrintToServer("found %d %s", entity, classname);
		SDKHook(entity, SDKHook_StartTouchPost, SpawnPoint_StartTouchPost);
	}
}

public void SpawnPoint_StartTouchPost(int entity, int other)
{
	if (1 <= other <= MaxClients)
		PrintToChat(other, "Touched entity -> %d", entity);
}
