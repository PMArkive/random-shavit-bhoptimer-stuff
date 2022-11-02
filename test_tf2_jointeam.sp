public Action Command_Jointeam(int client, const char[] command, int args)
{
	if(!IsValidClient(client) || !gCV_JointeamHook.BoolValue)
	{
		return Plugin_Continue;
	}

	char arg1[8];
	GetCmdArg(1, arg1, 8);

	int iTeam = StringToInt(arg1);
	int iHumanTeam = GetHumanTeam();

	if (iHumanTeam != 0 && iTeam != 1)
	{
		iTeam = iHumanTeam;
	}

	if (iTeam < 1 || iTeam > 3)
	{
		iTeam = GetRandomInt(2, 3);
	}

	CleanSwitchTeam(client, iTeam);

	if(gCV_RespawnOnTeam.BoolValue && iTeam != 1)
	{
		if(gEV_Type == Engine_TF2)
		{
			TF2_RespawnPlayer(client);
		}
		else
		{
			RemoveAllWeapons(client); // so weapons are removed and we don't hit the edict limit
			CS_RespawnPlayer(client);
		}

		return Plugin_Stop;
	}

	return Plugin_Continue;
}
