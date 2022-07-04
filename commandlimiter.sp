#include <sourcemod>
#include <console>

public void OnPluginStart()
{
	AddCommandListener(CommandLimiter, "");
}

public Action CommandLimiter(int client, const char[] command, int argc)
{
	if (!client || client == -1 || IsFakeClient(client))
		return Plugin_Continue;

	static int lasttick = 0;
	static int commandcounter[MAXPLAYERS+1];

	if (lasttick != GetGameTickCount()) {
		int empty[MAXPLAYERS+1];
		commandcounter = empty;
		lasttick = GetGameTickCount();
	}
	
	if (++commandcounter[client] > 10)
		return Plugin_Stop;
	return Plugin_Continue;
}