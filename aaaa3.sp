int gI_InsideZone[MAXPLAYERS+1][9];
bool gB_InsideZone[MAXPLAYERS+1][16][9];

bool InsideZoneI(int client, int type, int track)
{
	int res = 0;

	if(track != -1)
	{
		res = gI_InsideZone[client][track];
	}
	else
	{
		for(int i = 0; i < 9; i++)
		{
			res |= gI_InsideZone[client][i];
		}
	}

	return (res & (1 << type)) != 0;
}

bool InsideZoneB(int client, int type, int track)
{
	int res = 0;

	if(track != -1)
	{
		return gB_InsideZone[client][type][track]
	}
	else
	{
		for(int i = 0; i < 9; i++)
		{
			if (gB_InsideZone[client][type][i])
				return true;
		}
	}

	return false;
}

public void OnPluginStart()
{
	InsideZoneI(2, 5, 3);
	InsideZoneB(2, 5, 3);
}