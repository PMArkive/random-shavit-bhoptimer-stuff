#include <sdktools_stringtables>

#define SOUNDFILE "something.mp3"
#define DELAY_UNTIL_SOUNDFILE 1.0

public void OnMapStart()
{
	AddFileToDownloadsTable("sound/"...SOUNDFILE);
	PrecacheSound(SOUNDFILE)
}

Action Timer_MapChangeSound(Handle timer, any data)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
		{
			ClientCommand(i, "play "...SOUNDFILE);
		}
	}
	return Plugin_Stop;
}

// called when 5s remain
forward void Shavit_OnCountdownStart();
public void Shavit_OnCountdownStart()
{
	CreateTimer(DELAY_UNTIL_SOUNDFILE, Timer_MapChangeSound, 0, TIMER_FLAG_NO_MAPCHANGE);
}
