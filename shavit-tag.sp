#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <shavit>

#define MAX_TEAMS 12
#define MAX_TEAM_MEMBERS 10

char g_cMapName[PLATFORM_MAX_PATH];

ConVar g_cvMaxPasses;
ConVar g_cvMaxUndos;

// invite system
int g_iInviteStyle[MAXPLAYERS + 1];
bool g_bCreatingTeam[MAXPLAYERS + 1];
ArrayList g_aInvitedPlayers[MAXPLAYERS + 1];
bool g_bInvitedPlayer[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_nDeclinedPlayers[MAXPLAYERS + 1];
ArrayList g_aAcceptedPlayers[MAXPLAYERS + 1];

// teams system
bool g_bAllowReset[MAXPLAYERS + 1];
bool g_bAllowStyleChange[MAXPLAYERS + 1];

int g_nUndoCount[MAX_TEAMS];
bool g_bDidUndo[MAX_TEAMS];

enum struct cp_cache
{
	float fPosition[3];
	float fAngles[3];
	float fVelocity[3];
	float fBaseVelocity[3];
	MoveType iMoveType;
	float fGravity;
	float fSpeed;
	float fStamina;
	bool bDucked;
	bool bDucking;
	float fDucktime; // m_flDuckAmount in csgo
	float fDuckSpeed; // m_flDuckSpeed in csgo; doesn't exist in css
	int iFlags;
	timer_snapshot_t aSnapshot;
	int iTargetname;
	int iClassname;
	ArrayList aFrames;
	bool bSegmented;
	int iSerial;
	bool bPractice;
	int iGroundEntity;
}

char g_cTeamName[MAX_TEAMS][MAX_NAME_LENGTH];
int g_nPassCount[MAX_TEAMS];
int g_nRelayCount[MAX_TEAMS];
int g_iCurrentPlayer[MAX_TEAMS];
bool g_bTeamTaken[MAX_TEAMS];
int g_nTeamPlayerCount[MAX_TEAMS];
stylesettings_t aSettings;

int g_iTeamIndex[MAXPLAYERS + 1] = { -1, ... };
int g_iNextTeamMember[MAXPLAYERS + 1];
char g_cPlayerTeamName[MAXPLAYERS + 1][MAX_NAME_LENGTH];

// records system
ArrayList g_aCurrentSegmentStartTicks[MAX_TEAMS];
ArrayList g_aCurrentSegmentPlayers[MAX_TEAMS];

public Plugin myinfo = 
{
	name = "Slidy's Timer - Tagteam relay",
	author = "SlidyBat",
	description = "Plugin that manages the tagteam relay style",
	version = "0.1",
	url = ""
}

public APLRes AskPluginLoad2( Handle myself, bool late, char[] error, int err_max )
{
	RegPluginLibrary( "timer-tagteam" );
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	g_cvMaxPasses = CreateConVar( "sm_timer_tagteam_maxpasses", "-1", "Maximum number of passes a team can make or -1 for unlimited passes", _, true, -1.0, false );
	g_cvMaxUndos = CreateConVar( "sm_timer_tagteam_maxundos", "3", "Maximum number of undos a team can make or -1 for unlimited undos", _, true, -1.0, false );
	AutoExecConfig( true, "tagteam", "SlidyTimer" );
	
	RegConsoleCmd( "sm_teamname", Command_TeamName );
	RegConsoleCmd( "sm_exitteam", Command_ExitTeam );
	RegConsoleCmd( "sm_pass", Command_Pass );
	RegConsoleCmd( "sm_undo", Command_Undo );
	
	GetCurrentMap( g_cMapName, sizeof(g_cMapName) );
}

public void OnMapStart()
{
	GetCurrentMap( g_cMapName, sizeof(g_cMapName) );
}

public void OnClientPutInServer( int client )
{
	Format( g_cPlayerTeamName[client], sizeof(g_cPlayerTeamName[]), "Team %N", client );
}

public void OnClientDisconnect( int client )
{
	if( !IsFakeClient( client ) && g_iTeamIndex[client] != -1 )
	{
		ExitTeam( client );
	}
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	char sSpecial[stylestrings_t::sSpecialString];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sSpecial, stylestrings_t::sSpecialString);
    
	Shavit_GetStyleSettings(newstyle, aSettings);   
	if(StrContains(sSpecial, "tagteam", false) != -1)
	{
		if( g_iTeamIndex[client] == -1 )
		{
			OpenInviteSelectMenu( client, 0, true, newstyle );
			PrintToChat( client, "Created %s! Use !teamname to set your team name.", g_cPlayerTeamName[client] );
		}
	}

	else
    {
		if( g_iTeamIndex[client] != -1 && !g_bAllowStyleChange[client] )
		{
			PrintToChat( client, "You cannot change style until you leave the team! Type !exitteam to leave your team" );
		}
		if( g_bAllowStyleChange[client] )
		{
			g_bAllowStyleChange[client] = false;
		}
	}
}

public void Shavit_OnRestart(int client, int track)
{
	if( g_iTeamIndex[client] != -1 && !g_bAllowReset[client] && !(g_nRelayCount[g_iTeamIndex[client]] == 0 && g_iCurrentPlayer[g_iTeamIndex[client]] == client) )
	{
		Shavit_PrintToChat( client, "You cannot reset or teleport until you leave the team! Type !exitteam to leave your team" );
	}
	if( g_bAllowReset[client] )
	{
		g_bAllowReset[client] = false;
	}
}

void OpenInviteSelectMenu( int client, int firstItem, bool reset = false, int style = 0 )
{
	if( reset )
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			g_bInvitedPlayer[client][i] = false;
		}
		
		g_bCreatingTeam[client] = true;
		g_iInviteStyle[client] = style;
		g_nDeclinedPlayers[client] = 0;
		
		delete g_aAcceptedPlayers[client];
		g_aAcceptedPlayers[client] = new ArrayList();
		
		delete g_aInvitedPlayers[client];
		g_aInvitedPlayers[client] = new ArrayList();
	}

	Menu menu = new Menu( InviteSelectMenu_Handler );
	menu.SetTitle( "Select players to invite:\n \n" );
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( i == client || !IsClientInGame( i ) || IsFakeClient( i ) || g_iTeamIndex[i] != -1 )
		{
			continue;
		}
	
		char name[MAX_NAME_LENGTH + 32];
		Format( name, sizeof(name), "[%s] %N", g_bInvitedPlayer[client][i] ? "X" : " ", i );
	
		char userid[8];
		IntToString( GetClientUserId( i ), userid, sizeof(userid) );
		
		menu.AddItem( userid, name );
	}
	
	menu.AddItem( "send", "Send Invites!", g_aInvitedPlayers[client].Length == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT );
	
	menu.DisplayAt( client, firstItem, MENU_TIME_FOREVER );
}

public int InviteSelectMenu_Handler( Menu menu, MenuAction action, int param1, int param2 )
{
	if( action == MenuAction_Select )
	{
		char info[8];
		menu.GetItem( param2, info, sizeof(info) );
		
		if( StrEqual( info, "send" ) ) // send the invites!
		{
			int length = g_aInvitedPlayers[param1].Length;
			for( int i = 0; i < length; i++ )
			{
				SendInvite( param1, GetClientOfUserId( g_aInvitedPlayers[param1].Get( i ) ) );
			}
			
			Shavit_PrintToChat( param1, "Invites sent!" );
			
			OpenLobbyMenu( param1 );
		}
		else
		{
			int userid = StringToInt( info );
			int target = GetClientOfUserId( userid );
			if( 0 < target <= MaxClients )
			{
				g_bInvitedPlayer[param1][target] = !g_bInvitedPlayer[param1][target];
				if( g_bInvitedPlayer[param1][target] )
				{
					g_aInvitedPlayers[param1].Push( userid );
				}
				else
				{
					int idx = g_aInvitedPlayers[param1].FindValue( userid );
					if( idx != -1 )
					{
						g_aInvitedPlayers[param1].Erase( idx );
					}
				}
			}
			
			OpenInviteSelectMenu( param1, (param2 / 6) * 6 );
		}
	}
	else if( action == MenuAction_End )
	{
		delete menu;
	}
}

void SendInvite( int client, int target )
{
	Menu menu = new Menu( InviteMenu_Handler );
	
	char buffer[256];
	Format( buffer, sizeof(buffer), "%N has invited you to play tagteam!\nAccept?\n \n", client );
	menu.SetTitle( buffer );
	
	char userid[8];
	IntToString( GetClientUserId( client ), userid, sizeof(userid) );
	
	menu.AddItem( userid, "Yes" );
	menu.AddItem( userid, "No" );
	
	menu.Display( target, 20 );
}

public int InviteMenu_Handler( Menu menu, MenuAction action, int param1, int param2 )
{
	if( action == MenuAction_Select )
	{
		char info[8];
		menu.GetItem( param2, info, sizeof(info) );
		
		int client = GetClientOfUserId( StringToInt( info ) );
		if( !( 0 < client <= MaxClients ) )
		{
			return 0;
		}
	
		if( param2 == 0 ) // yes
		{
			if( !g_bCreatingTeam[client] )
			{
				Shavit_PrintToChat( param1, "The team has been cancelled or has already started the run" );
			}
			if( g_aAcceptedPlayers[client].Length >= MAX_TEAM_MEMBERS )
			{
				Shavit_PrintToChat( param1, "The team is now full, cannot join" );
			}
			else
			{
				g_aAcceptedPlayers[client].Push( GetClientUserId( param1 ) );
				OpenLobbyMenu( client );
			}
		}
		else // no
		{
			g_nDeclinedPlayers[client]++;
			Shavit_PrintToChat( client, "%N has declined your invite", param1 );
		}
		
		if( g_aAcceptedPlayers[client].Length + g_nDeclinedPlayers[client] == g_aInvitedPlayers[client].Length ) // everyone responded
		{
			FinishInvite( client );
		}
	}
	else if( action == MenuAction_End )
	{
		delete menu;
	}
	
	return 0;
}

void OpenLobbyMenu( int client )
{
	Menu menu = new Menu( LobbyMenu_Handler );
	
	char buffer[512];
	Format( buffer, sizeof(buffer), "%s\n \nMembers:\n%N\n", g_cPlayerTeamName[client], client );
	
	int length = g_aAcceptedPlayers[client].Length;
	if( length == 0 )
	{
		Format( buffer, sizeof(buffer), "%s \n", buffer );
	}
	
	for( int i = 0; i < length; i++ )
	{
		Format( buffer, sizeof(buffer), "%s%N\n", buffer, GetClientOfUserId( g_aAcceptedPlayers[client].Get( i ) ) );
		
		if( i == length - 1 )
		{
			Format( buffer, sizeof(buffer), "%s \n", buffer );
		}
	}
	
	menu.SetTitle( buffer );
	
	menu.AddItem( "start", "Start", (length > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED );
	menu.AddItem( "cancel", "Cancel" );
	
	menu.ExitButton = false;
	menu.Display( client, MENU_TIME_FOREVER );
}

public int LobbyMenu_Handler( Menu menu, MenuAction action, int param1, int param2 )
{
	if( action == MenuAction_Select )
	{
		if( param1 == 0 ) // start
		{
			FinishInvite( param1 );
		}
		else if( param1 == 1 ) // cancel
		{
			CancelInvite( param1 );
		}
	}
	else if( action == MenuAction_End )
	{
		delete menu;
	}
}

void FinishInvite( int client )
{
	g_bCreatingTeam[client] = false;

	int length = g_aAcceptedPlayers[client].Length;
	
	if( length < 1 )
	{
		Shavit_PrintToChat( client, "Not enough players to create a team" );
		return;
	}
	
	int[] members = new int[length + 1];
	
	members[0] = client;
	for( int i = 0; i < length; i++ )
	{
		members[i + 1] = GetClientOfUserId( g_aAcceptedPlayers[client].Get( i ) );
	}
	
	CreateTeam( members, length + 1, g_iInviteStyle[client] );
	
	int letters;
	char buffer[512];
	for( int i = 0; i <= length; i++ )
	{
		letters += Format( buffer, sizeof(buffer), "%s%N, ", buffer, members[i] );
	}
	buffer[letters - 3] = '\0';
	
	PrintToTeam( g_iTeamIndex[client], "%s has been assembled! Members: %s", g_cTeamName[g_iTeamIndex[client]], buffer );
}

void CancelInvite( int client )
{
	g_bCreatingTeam[client] = false;
}

void CreateTeam( int[] members, int memberCount, int style )
{
	int teamindex = -1;
	for( int i = 0; i < MAX_TEAMS; i++ )
	{
		if( !g_bTeamTaken[i] )
		{
			teamindex = i;
			break;
		}
	}
	
	if( teamindex == -1 )
	{
		LogError( "Not enough teams" );
		return;
	}
	
	g_nUndoCount[teamindex] = 0;
	g_nPassCount[teamindex] = 0;
	g_nRelayCount[teamindex] = 0;
	g_bTeamTaken[teamindex] = true;
	g_nTeamPlayerCount[teamindex] = memberCount;
	strcopy( g_cTeamName[teamindex], sizeof(g_cTeamName[]), g_cPlayerTeamName[members[0]] );
	
	delete g_aCurrentSegmentStartTicks[teamindex];
	g_aCurrentSegmentStartTicks[teamindex] = new ArrayList();
	delete g_aCurrentSegmentPlayers[teamindex];
	g_aCurrentSegmentPlayers[teamindex] = new ArrayList();
	
	g_aCurrentSegmentStartTicks[teamindex].Push( 2 ); // not zero so that it doesnt spam print during first tick freeze time
	
	int next = members[0];
	for( int i = memberCount - 1; i >= 0; i-- )
	{	
		g_iNextTeamMember[members[i]] = next;
		next = members[i];
		
		g_iTeamIndex[members[i]] = teamindex;
		
		g_bAllowStyleChange[members[i]] = true;
		Shavit_ClearCheckpoints( members[i] );
		Shavit_ChangeClientStyle( members[i], style );
	}
	
	Shavit_RestartTimer(members[0], Track_Main);
	Shavit_OpenCheckpointMenu( members[0] );
	g_iCurrentPlayer[teamindex] = members[0];
	
	for( int i = 1; i < memberCount; i++ )
	{	
		ChangeClientTeam( members[i], CS_TEAM_SPECTATOR );
		SetEntPropEnt( members[i], Prop_Send, "m_hObserverTarget", members[0] );
		SetEntProp( members[i], Prop_Send, "m_iObserverMode", 4 );
	}
}

bool ExitTeam( int client )
{
	if( g_iTeamIndex[client] == -1 )
	{
		Shavit_ChangeClientStyle( client, 0 );
		Shavit_RestartTimer(client, Track_Main);
		return false;
	}
	
	int teamidx = g_iTeamIndex[client];
	g_iTeamIndex[client] = -1;
	
	g_nTeamPlayerCount[teamidx]--;
	if( g_nTeamPlayerCount[teamidx] <= 1 )
	{
		g_bTeamTaken[teamidx] = false;
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( i != client && g_iTeamIndex[i] == teamidx )
			{
				Shavit_PrintToChat( i, "All your team members have left, your team has been disbanded!" );
				ExitTeam( i );
				break;
			}
		}
	}
	else
	{
		for( int i = 1; i <= MaxClients; i++ )
		{
			if( g_iNextTeamMember[i] == client )
			{
				g_iNextTeamMember[i] = g_iNextTeamMember[client];
			}
		}
	}
	
	g_iNextTeamMember[client] = -1;
	
	Shavit_ChangeClientStyle( client, 0 );
	Shavit_RestartTimer(client, Track_Main);
	
	return true;
}

public Action Shavit_OnSave(int client, int idx)
{
	if( g_iTeamIndex[client] != -1 )
	{
		int teamidx = g_iTeamIndex[client];
		
		cp_cache_t cpcache;
		
		if( !g_bDidUndo[teamidx] )
		{
			delete cpcache.aFrames;
		}
		
		g_nRelayCount[teamidx]++;
		int next = g_iNextTeamMember[client];
	
		Shavit_GetCheckpoint( client, idx, cpcache );
		
		PassToNext( client, next, cpcache );
		
		g_bDidUndo[teamidx] = false;
	}
}

public Action Command_TeamName( int client, int args )
{
	GetCmdArgString( g_cPlayerTeamName[client], sizeof(g_cPlayerTeamName[]) );
	if( g_iTeamIndex[client] != -1 )
	{
		strcopy( g_cTeamName[g_iTeamIndex[client]], sizeof(g_cTeamName[]), g_cPlayerTeamName[client] );
	}
	
	ReplyToCommand( client, "Team name set to: %s", g_cPlayerTeamName[client] );
	
	return Plugin_Handled;
}

public Action Command_ExitTeam( int client, int args )
{
	if( !ExitTeam( client ) )
	{
		ReplyToCommand( client, "You are not currently in a team" );
	}
	
	return Plugin_Handled;
}

public Action Command_Pass( int client, int args )
{
	if( g_iTeamIndex[client] == -1 )
	{
		ReplyToCommand( client, "You are not currently in a team" );
		return Plugin_Handled;
	}
	
	int teamidx = g_iTeamIndex[client];
	int maxPasses = g_cvMaxPasses.IntValue;
	
	if( maxPasses > -1 && g_nPassCount[teamidx] >= maxPasses )
	{
		ReplyToCommand( client, "Your team has used all %i passes", maxPasses );
		return Plugin_Handled;
	}
	
	if( g_iCurrentPlayer[teamidx] != client )
	{
		ReplyToCommand( client, "You cannot pass when it is not your turn" );
		return Plugin_Handled;
	}
	
	g_nPassCount[teamidx]++;
	
	cp_cache_t cpcache;
	bool usecp = Shavit_GetTotalCheckpoints( client ) > 0;
	
	if( usecp )
	{
		Shavit_GetCheckpoint( client, 0, cpcache );
	}
	
	PassToNext( client, g_iNextTeamMember[client], cpcache, usecp );
		
	if( maxPasses > -1 )
	{
		PrintToTeam( teamidx, "%N has passed! It is now %N's turn. %i/%i passes used.", client, g_iNextTeamMember[client], g_nPassCount[teamidx], maxPasses );
	}
	else
	{
		PrintToTeam( teamidx, "%N has passed! It is now %N's turn.", client, g_iNextTeamMember[client] );
	}
	
	return Plugin_Handled;
}

public Action Command_Undo( int client, int args )
{
	if( g_iTeamIndex[client] == -1 )
	{
		ReplyToCommand( client, "You are not currently in a team" );
		return Plugin_Handled;
	}
	
	int teamidx = g_iTeamIndex[client];
	
	int maxUndos = g_cvMaxUndos.IntValue;
	if( maxUndos == -1 || g_nUndoCount[teamidx] >= maxUndos )
	{
		ReplyToCommand( client, "Your team has already used all %i undos", maxUndos );
		return Plugin_Handled;
	}
	
	if( g_iCurrentPlayer[teamidx] != client )
	{
		ReplyToCommand( client, "You cannot undo when it is not your turn" );
		return Plugin_Handled;
	}
	
	if( g_nRelayCount[teamidx] == 0 )
	{
		ReplyToCommand( client, "Cannot undo when no one has saved!" );
		return Plugin_Handled;
	}
	
	if( g_bDidUndo[teamidx] )
	{
		ReplyToCommand( client, "Your team has already undo-ed this turn" );
		return Plugin_Handled;
	}
	
	int last = -1;
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( g_iNextTeamMember[i] == client )
		{
			last = i;
			break;
		}
	}
	
	if( last == -1 )
	{
		LogError( "Failed to find last player" );
		return Plugin_Handled;
	}
	
	cp_cache_t cpcache;
	PassToNext( client, last, cpcache );
	g_aCurrentSegmentStartTicks[teamidx].Erase( g_aCurrentSegmentStartTicks[teamidx].Length - 1 );
	g_aCurrentSegmentPlayers[teamidx].Erase( g_aCurrentSegmentPlayers[teamidx].Length - 1 );
	g_bDidUndo[teamidx] = true;
	g_nUndoCount[teamidx]++;
	
	if( maxUndos > -1 )
	{
		PrintToTeam( teamidx, "%N used an undo! It is now %N's turn again. %i/%i undos used.", client, last, g_nUndoCount[teamidx], maxUndos );
	}
	else
	{
		PrintToTeam( teamidx, "%N used an undo! It is now %N's turn again.", client, last );
	}
	return Plugin_Handled;
}

void PassToNext( int client, int next, cp_cache_t cpcache, bool usecp = true )
{
	int length;
	
	length = Shavit_GetTotalCheckpoints( client );
	PrintToChatAll("client: %d", length);
	for( int i = 0; i < length; i++ )
	{
		cp_cache_t cp;
		Shavit_GetCheckpoint( client, i, cp );
		
		if(cp.aFrames != cpcache.aFrames)
		{
			delete cp.aFrames;
		}
	}
	
	length = Shavit_GetTotalCheckpoints( next );
	PrintToChatAll("next: %d", length);
	for( int i = 0; i < length; i++ )
	{
		cp_cache_t cp;
		Shavit_GetCheckpoint( next, i, cp );
		
		if( cp.aFrames != cpcache.aFrames )
		{
			delete cp.aFrames;
		}
	}

	Shavit_ClearCheckpoints( client );
	Shavit_ClearCheckpoints( next );
	
	if( usecp )
	{
		Shavit_SetCheckpoint( next, -1, cpcache );
	}
	ChangeClientTeam( next, CS_TEAM_SPECTATOR );
	ChangeClientTeam( next, CS_TEAM_T );
	CS_RespawnPlayer( next );
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( IsClientInGame( i ) && !IsFakeClient( i ) && IsClientObserver( i ) && GetEntPropEnt( client, Prop_Send, "m_hObserverTarget" ) == client )
		{
			SetEntPropEnt( client, Prop_Send, "m_hObserverTarget", next );
			SetEntProp( client, Prop_Send, "m_iObserverMode", 4 );
		}
	}
	
	ChangeClientTeam( client, CS_TEAM_SPECTATOR );
	SetEntPropEnt( client, Prop_Send, "m_hObserverTarget", next );
	SetEntProp( client, Prop_Send, "m_iObserverMode", 4 );
	
	g_iCurrentPlayer[g_iTeamIndex[client]] = next;
	
	if( usecp )
	{
		Shavit_TeleportToCheckpoint( next, 0 );
	}
	Shavit_OpenCheckpointMenu( next );
	Shavit_OpenCheckpointMenu( client );
}

void PrintToTeam( int teamidx, char[] message, any ... )
{
	char buffer[512];
	VFormat( buffer, sizeof(buffer), message, 3 );
	
	for( int i = 1; i <= MaxClients; i++ )
	{
		if( g_iTeamIndex[i] == teamidx )
		{
			Shavit_PrintToChat( i, buffer );
		}
	}
}