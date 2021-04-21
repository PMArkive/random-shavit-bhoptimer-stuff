#include <sourcemod>
#include <shavit>

#define TRACK_PREFIX "{var}[{track}] {text}"
#define UNRANKED_PHRASE "You have finished ({stylecolor}{style}{text}) in {var2}{time}{text} with {jumps} jumps {var}({perfs}){text}, {strafes} strafes @ {var}{sync}{text}."
#define WORSE_PHRASE "You have finished ({stylecolor}{style}{text}) in {var2}{time}{text} with {jumps} jumps {var}({perfs}) {var2}(+{delta}){text}, {strafes} strafes @ {var}{sync}{text}."
#define FIRST_PHRASE "{var}{name}{text} finished ({stylecolor}{style}{text}) in {var2}{time} {var}(#{rank}) {text}with {jumps} jumps {var}({perfs}){text}, {strafes} strafes @ {var}{sync}{text}."
#define IMPROVE_PHRASE "{var}{name}{text} finished ({stylecolor}{style}{text}) in {var2}{time} {var}(#{rank}) {text}with {jumps} jumps {var}({perfs}){text}, {strafes} strafes @ {var}{sync} {warning}(-{delta}){text}."

chatstrings_t gS_ChatStrings;

public Plugin myinfo =
{
	name = "[shavit] Scroll finish message",
	author = "shavit",
	description = "Implements a separate finish message for scroll styles.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public void OnPluginStart()
{
	LoadTranslations("shavit-common.phrases");
}

public void Shavit_OnChatConfigLoaded()
{
	Shavit_GetChatStrings(sMessageVariable, gS_ChatStrings.sVariable, chatstrings_t::sVariable);
	Shavit_GetChatStrings(sMessageVariable2, gS_ChatStrings.sVariable2, chatstrings_t::sVariable2);
	Shavit_GetChatStrings(sMessageStyle, gS_ChatStrings.sStyle, chatstrings_t::sStyle);
	Shavit_GetChatStrings(sMessageWarning, gS_ChatStrings.sWarning, chatstrings_t::sWarning);
	Shavit_GetChatStrings(sMessageText, gS_ChatStrings.sText, chatstrings_t::sText);
}

void FormatVariables(int client, char[] buffer, int maxlen, timer_snapshot_t snapshot, int rank)
{
	ReplaceString(buffer, maxlen, "{var}", gS_ChatStrings.sVariable);
	ReplaceString(buffer, maxlen, "{var2}", gS_ChatStrings.sVariable2);
	ReplaceString(buffer, maxlen, "{stylecolor}", gS_ChatStrings.sStyle);
	ReplaceString(buffer, maxlen, "{text}", gS_ChatStrings.sText);
	ReplaceString(buffer, maxlen, "{warning}", gS_ChatStrings.sWarning);
	
	char sTrack[32];
	GetTrackName(LANG_SERVER, snapshot.iTimerTrack, sTrack, 32);
	ReplaceString(buffer, maxlen, "{track}", sTrack);

	char sStyle[32];
	Shavit_GetStyleStrings(snapshot.bsStyle, sStyleName, sStyle, 32);
	ReplaceString(buffer, maxlen, "{style}", sStyle);

	char sTime[16];
	FormatSeconds(snapshot.fCurrentTime, sTime, 16);
	ReplaceString(buffer, maxlen, "{time}", sTime);

	char sJumps[8];
	IntToString(snapshot.iJumps, sJumps, 8);
	ReplaceString(buffer, maxlen, "{jumps}", sJumps);
	
	char sStrafes[8];
	IntToString(snapshot.iStrafes, sStrafes, 8);
	ReplaceString(buffer, maxlen, "{strafes}", sStrafes);
	
	char fSync[8];
	FormatEx(fSync, 8, "%.2f%%", (snapshot.iGoodGains == 0)? 0.0:(snapshot.iGoodGains / float(snapshot.iTotalMeasures) * 100.0));
	ReplaceString(buffer, maxlen, "{sync}", fSync);

	char sPerfs[8];
	FormatEx(sPerfs, 8, "%.1f%%", (snapshot.iMeasuredJumps == 0)? 100.0:(snapshot.iPerfectJumps / float(snapshot.iMeasuredJumps) * 100.0));
	ReplaceString(buffer, maxlen, "{perfs}", sPerfs);

	char sRank[8];
	IntToString(rank, sRank, 8);
	ReplaceString(buffer, maxlen, "{rank}", sRank);

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, MAX_NAME_LENGTH);
	ReplaceString(buffer, maxlen, "{name}", sName);

	float fDelta = (Shavit_GetClientPB(client, snapshot.bsStyle, snapshot.iTimerTrack) - snapshot.fCurrentTime);

	if(fDelta < 0.0)
	{
		fDelta = -fDelta;
	}

	char sDelta[16];
	FormatSeconds(fDelta, sDelta, 16, true);
	ReplaceString(buffer, maxlen, "{delta}", sDelta);
}

public Action Shavit_OnFinishMessage(int client, bool &everyone, timer_snapshot_t snapshot, int overwrite, int rank, char[] message, int maxlen)
{
	stylesettings_t aSettings;
	Shavit_GetStyleSettings(snapshot.bsStyle, aSettings);

	if(aSettings.bAutobhop)
	{
		return Plugin_Continue;
	}
	
	if(aSettings.bUnranked)
	{
		strcopy(message, maxlen, UNRANKED_PHRASE);
	}

	else
	{
		switch(overwrite)
		{
			case 0: strcopy(message, maxlen, WORSE_PHRASE);
			case 1: strcopy(message, maxlen, FIRST_PHRASE);
			case 2: strcopy(message, maxlen, IMPROVE_PHRASE);
		}
	}

	FormatVariables(client, message, maxlen, snapshot, rank);

	return Plugin_Changed;
}

void GetTrackName(int client, int track, char[] output, int size)
{
	if(track < 0 || track >= TRACKS_SIZE)
	{
		FormatEx(output, size, "%T", "Track_Unknown", client);

		return;
	}

	static char sTrack[16];
	FormatEx(sTrack, 16, "Track_%d", track);
	FormatEx(output, size, "%T", sTrack, client);
}