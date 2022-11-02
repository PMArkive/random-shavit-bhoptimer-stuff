public Action Command_Jointeam(int client, const char[] command, int args)
{
	if(!IsValidClient(client) || !gCV_JointeamHook.BoolValue)
	{
		return Plugin_Continue;
	}

	char arg1[16];
	GetCmdArg(1, arg1, sizeof(arg1));
	int iTeam;

	if (gEV_Type == Engine_TF2)
	{
		iTeam = 2; // defaults to Red

		if (StrEqual(arg1, "spectate", false) || StrEqual(arg1, "spectatearena", false))
			iTeam = 1;
		else if (StrEqual(arg1, "red", false))
			iTeam = 2;
		else if (StrEqual(arg1, "blue", false))
			iTeam = 3;
		else if (StrEqual(arg1, "auto", false))
			iTeam = GetRandomInt(2, 3); // whatever
		else if (StrEqual(arg1, "unassigned", false))
			return Plugin_Handled;
	
		if (iTeam == GetClientTeam(client))
			return Plugin_Handled;
	}
	else
	{
		iTeam = StringToInt(arg1);
	}

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

	if (gEV_Type == Engine_TF2 && -1 == StrContains(command, "nomenus"))
	{
		BfWrite msg = view_as<BfWrite>(StartMessageOne("VGUIMenu", client));
		msg.WriteString(iTeam == 2 ? "class_red" : "class_blue");
		msg.WriteByte(1);
		msg.WriteByte(0);
		EndMessage();
	}

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
