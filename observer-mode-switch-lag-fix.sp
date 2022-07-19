
#include <sourcemod>

public Plugin myinfo =
{
	name = "observer-mode-switch-lag-fix",
	author = "rtldg",
	description = "Switches between 3rd person and back on spec_next/spec_prev to try and prevent a laggy view when watching certain people.",
	version = "1.0",
	url = "https://github.com/PMArkive/random-shavit-bhoptimer-stuff"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// up here so it hopefully hooks before shavit-misc...
	AddCommandListener(CommandListener_SpecNextPrev, "spec_next");
	AddCommandListener(CommandListener_SpecNextPrev, "spec_prev");
	AddCommandListener(CommandListener_RandomSpecCommands, "spectate");
	AddCommandListener(CommandListener_RandomSpecCommands, "sm_spec");
	return APLRes_Success;
}

public Action Timer_ChangeObserverMode(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientFromSerial(pack.ReadCell());
	int mode = pack.ReadCell();
	//delete pack;

	if (client > 0 && !IsPlayerAlive(client))
		SetEntProp(client, Prop_Send, "m_iObserverMode", mode);

	return Plugin_Stop;
}

public Action CommandListener_SpecNextPrev(int client, const char[] command, int args)
{
	//PrintToConsole(client, "_SpecNextPrev = %s", command);
	int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

	if (iObserverMode != 4 /* OBS_MODE_IN_EYE */)
	{
		return Plugin_Continue;
	}

	SetEntProp(client, Prop_Send, "m_iObserverMode", 5 /* OBS_MODE_CHASE */);

	DataPack pack;
	CreateDataTimer(0.03, Timer_ChangeObserverMode, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(iObserverMode);

	return Plugin_Continue;
}

public Action Timer_RandomSpecCommands(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientFromSerial(pack.ReadCell());
	int prevTarget = pack.ReadCell();
	bool alive = pack.ReadCell();
	//delete pack;
	int curTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

	if (client > 0 && !IsPlayerAlive(client) && (alive || prevTarget != curTarget))
	{
		SetEntProp(client, Prop_Send, "m_iObserverMode", 4 /* OBS_MODE_IN_EYE */);
		CommandListener_SpecNextPrev(client, "Timer_RandomSpecCommands", 0);
		//PrintToServer("HERE");
	}

	return Plugin_Stop;
}

public Action CommandListener_RandomSpecCommands(int client, const char[] command, int args)
{
	//PrintToServer("CommandListener_RandomSpecCommands = %s", command);
	DataPack pack;
	CreateDataTimer(0.0, Timer_RandomSpecCommands, pack, TIMER_FLAG_NO_MAPCHANGE);
	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(GetEntPropEnt(client, Prop_Send, "m_hObserverTarget"));
	pack.WriteCell(IsPlayerAlive(client));
	return Plugin_Continue;
}
