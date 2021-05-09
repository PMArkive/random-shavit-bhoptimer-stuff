#include "sourcemod"
#include "sdktools"

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsFakeClient(client))
		return Plugin_Continue;
	
	static float prevheight[MAXPLAYERS], ground[MAXPLAYERS];
	static float orig[3];
	
	GetClientAbsOrigin(client, orig);
	
	if(GetEntityFlags(client) & FL_ONGROUND)
	{
		prevheight[client] = -99999999.0;
		ground[client] = orig[2];
		return Plugin_Continue;
	}
	
	float height = orig[2] - ground[client];
	
	if(height >= prevheight[client])
		prevheight[client] = height;
	else if(prevheight[client] != -99999999.0)
	{
		PeakReached(client, prevheight[client]);
	}
	
	return Plugin_Continue;
}

void PeakReached(int client, float height)
{
	static Handle sync;
	if(!sync)
		sync = CreateHudSynchronizer();
	
	SetHudTextParams(-1.0, 0.2, 2.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, sync, "Peak height: %.2f", height);
}

