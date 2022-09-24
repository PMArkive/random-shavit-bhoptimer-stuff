#include <sourcemod>
#include <sdktools>
#include <shavit/core>
#include <shavit/hud>
#include <shavit/replay-playback>

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	if (!(IsFakeClient(client)))
	{
		SetClientName(client, "xd");
	}

	return true;
}

public void Shavit_OnReplayStart(int ent, int type, bool delay_elapsed)
{
	Shavit_SetReplayCacheName(ent, "xd");
}

public Action Shavit_OnTopLeftHUD(int client, int target, char[] topleft, int topleftlength, int track, int style)
{
	ReplaceString(topleft, topleftlength, "XXXX", "xd", false);
	return Plugin_Changed;
}
