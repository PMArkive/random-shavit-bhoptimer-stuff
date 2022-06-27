#include <sourcemod>
#include <sdktools>

#pragma semicolon 1

#define PLUGIN_VERSION	"1.65"
#define FREEZE_ENABLE	1
#define FREEZE_TIME		5.0
#define ADMIN_FLAG		Admin_Generic

public Plugin:myinfo =
{
	name = "Anti-StrafeHack",
	author = "ici (Thanks to blacky)",
	description = "Based on BASH. Not BASH.",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/1ci"
};

enum CheatDetection
{
	INVALID_MOV_VARYINGSM = 0,
	INVALID_MOV_VARYINGFM = 1,
	UNSYNCHRONIZED_MOV = 2,
	SILENTSTRAFE_SMSPAM = 3,
	N_STRAFEHACK_20 = 4,
	N_STRAFEHACK_40 = 5,
	SW_STRAFEHACK_20 = 6,
	SW_STRAFEHACK_40 = 7
}

enum SuspectDetection
{
	ANGLEHACK = 0,
	PERFECT_KEY_CHANGES_AD = 1,
	PERFECT_KEY_CHANGES_WS = 2
}

// Generic
new g_Tick[MAXPLAYERS+1];
new g_LastTurnDir[MAXPLAYERS+1];
new g_LastTurnTime[MAXPLAYERS+1];
new bool:g_bTurned[MAXPLAYERS+1][2];
new bool:g_bOnGround[MAXPLAYERS+1];
new bool:g_bOldOnGround[MAXPLAYERS+1];
new bool:g_bWalking[MAXPLAYERS+1] = {true, ...};
new bool:g_bOldWalking[MAXPLAYERS+1];
new bool:g_bPreventInvalidMovSpam[MAXPLAYERS+1];

// Strafe Perfection
new g_TotalStrafes[MAXPLAYERS+1];
new g_GoodStrafes[MAXPLAYERS+1];
new g_PerfectStrafes[MAXPLAYERS+1];

// Loga
new String:g_sMapName[64];
new String:g_sLogFile[PLATFORM_MAX_PATH];
new Handle:gH_Logger = INVALID_HANDLE;
new String:g_sAPIKey[64];
new Handle:gH_Cvar_APIKey = INVALID_HANDLE;
new Handle:gH_Database = INVALID_HANDLE;
new Handle:gH_Cvar_Database_Driver = INVALID_HANDLE;

// Forwards
new g_Frames[MAXPLAYERS+1][40][2];
new g_CurrentFrame[MAXPLAYERS+1];
new g_LastMoveDir[MAXPLAYERS+1];
new g_LastMoveTime[MAXPLAYERS+1];
new g_TotalSync[MAXPLAYERS+1];
new g_GoodSync[MAXPLAYERS+1][3];
new g_TimerTotalSync[MAXPLAYERS+1];
new g_TimerGoodSync[MAXPLAYERS+1];

// Sideways
new g_FramesSW[MAXPLAYERS+1][40][2];
new g_CurrentFrameSW[MAXPLAYERS+1];
new g_LastMoveDirSW[MAXPLAYERS+1];
new g_LastMoveTimeSW[MAXPLAYERS+1];
new g_TotalSyncSW[MAXPLAYERS+1];
new g_GoodSyncSW[MAXPLAYERS+1][3];
new g_TimerTotalSyncSW[MAXPLAYERS+1];
new g_TimerGoodSyncSW[MAXPLAYERS+1];

// Half-Sideways
new g_TimerTotalSyncHSW[MAXPLAYERS+1];
new g_TimerGoodSyncHSW[MAXPLAYERS+1];

// Buttons
new g_CurrentFrameKeysAD[MAXPLAYERS+1];
new g_CurrentFrameKeysWS[MAXPLAYERS+1];

// Debug Menu
new g_AdminMenuPage[MAXPLAYERS+1] = {1, ...};
new g_AdminSelectedUserID[MAXPLAYERS+1];
new bool:g_bPrintAnalysis[MAXPLAYERS+1];
new bool:g_bDebugStrafes[MAXPLAYERS+1];
new bool:g_bCheckSync[MAXPLAYERS+1];
new bool:g_bPrintAnalysisSW[MAXPLAYERS+1];
new bool:g_bDebugStrafesSW[MAXPLAYERS+1];
new bool:g_bCheckSyncSW[MAXPLAYERS+1];
new bool:g_bDebugKeysHoldtimeAD[MAXPLAYERS+1];
new bool:g_bDebugKeysHoldtimeWS[MAXPLAYERS+1];
new bool:g_bConsoleOutput[MAXPLAYERS+1];
new bool:g_bPrintAngleDiff[MAXPLAYERS+1];
new bool:g_bCheckAngleDiff[MAXPLAYERS+1];
new bool:g_bIsDebugOnAnalysis = false;
new bool:g_bIsDebugOnStrafes = false;
new bool:g_bIsDebugOnAnalysisSW = false;
new bool:g_bIsDebugOnStrafesSW = false;
new bool:g_bIsDebugOnSync = false;
new bool:g_bIsDebugOnKeysAD = false;
new bool:g_bIsDebugOnKeysWS = false;
new bool:g_bIsDebugOnAdv = false;
new Handle:gH_TimerTopMsg[MAXPLAYERS+1] = {INVALID_HANDLE, ...};

// Anglehack
new bool:g_bBlockAngleCheck[MAXPLAYERS+1];

public OnPluginStart()
{
	// Plugin version
	CreateConVar("sm_ash_version", PLUGIN_VERSION, "Anti-StrafeHack Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	// Console variables
	gH_Cvar_Database_Driver = CreateConVar("sm_ash_database_driver", "anticheat", "Specifies the configuration driver to use from SourceMod's database.cfg", FCVAR_PLUGIN);
	gH_Cvar_APIKey = CreateConVar("sm_ash_api_key", "", "API Key");
	
	HookConVarChange(gH_Cvar_APIKey, CvarChange);
	AutoExecConfig(true, "anticheat");
	
	// Debugging menu for admins
	RegConsoleCmd("sm_ashdebug", SM_AshDebug, "Debugging menu");
	
	// Ultima Bhop server commands for timer communication purposes
	RegServerCmd("sm_startrecord", SM_StartRecord);
	RegServerCmd("sm_getsync", SM_GetSync);
	
	// Re-establishes connection to the database
	RegServerCmd("sm_ashdb", SM_AshDB);
	
	// Hooking events
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	
	// Store local logs in a plain text file
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/Anti-StrafeHack");
	if (!DirExists(g_sLogFile)) CreateDirectory(g_sLogFile, 511);
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/Anti-StrafeHack/log.txt");
}

public OnMapStart()
{
	#if (FREEZE_ENABLE == 1)
	// Precache freezing sound.
	PrecacheSound("physics/glass/glass_impact_bullet4.wav", true);
	#endif
	
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	HookTeleports();
}

public OnConfigsExecuted()
{
	GetConVarString(gH_Cvar_APIKey, g_sAPIKey, sizeof(g_sAPIKey));
	SQL_DBConnect();
}

public CvarChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	GetConVarString(gH_Cvar_APIKey, g_sAPIKey, sizeof(g_sAPIKey));
}

public OnClientPutInServer(client)
{
	// Generic
	g_Tick[client] = 0;
	g_CurrentFrame[client] = 0;
	g_bWalking[client] = true;
	g_bPreventInvalidMovSpam[client] = false;
	
	// Forwards
	g_TotalSync[client] = 0;
	g_GoodSync[client][0] = 0;
	g_GoodSync[client][1] = 0;
	g_GoodSync[client][2] = 0;
	g_TimerTotalSync[client] = 0;
	g_TimerGoodSync[client] = 0;
	
	// Sideways
	g_CurrentFrameSW[client] = 0;
	g_TotalSyncSW[client] = 0;
	g_GoodSyncSW[client][0] = 0;
	g_GoodSyncSW[client][1] = 0;
	g_GoodSyncSW[client][2] = 0;
	g_TimerTotalSyncSW[client] = 0;
	g_TimerGoodSyncSW[client] = 0;
	
	// Half-Sideways
	g_TimerTotalSyncHSW[client] = 0;
	g_TimerGoodSyncHSW[client] = 0;
	
	// Buttons
	g_CurrentFrameKeysAD[client] = 0;
	g_CurrentFrameKeysWS[client] = 0;
	
	// Debug Menu
	g_AdminMenuPage[client] = 1;
	g_AdminSelectedUserID[client] = 0;
	g_bPrintAnalysis[client] = false;
	g_bDebugStrafes[client] = false;
	g_bCheckSync[client] = false;
	g_bPrintAnalysisSW[client] = false;
	g_bDebugStrafesSW[client] = false;
	g_bCheckSyncSW[client] = false;
	g_bDebugKeysHoldtimeAD[client] = false;
	g_bDebugKeysHoldtimeWS[client] = false;
	g_bConsoleOutput[client] = false;
	g_bPrintAngleDiff[client] = false;
	g_bCheckAngleDiff[client] = false;
	
	// Anglehack
	g_bBlockAngleCheck[client] = false;
}

/* 
Disabling auto-strafeperfection tophud message.

public OnClientPostAdminCheck(client)
{
	if (IsAdmin(client) && !IsFakeClient(client)) // Just in case.
	{
		if (gH_TimerTopMsg[client] == INVALID_HANDLE)
			gH_TimerTopMsg[client] = CreateTimer(11.1, Timer_TopMsg, client, TIMER_REPEAT);
	}
}
*/

public OnClientDisconnect_Post(client)
{
	if (gH_TimerTopMsg[client] != INVALID_HANDLE)
	{
		KillTimer(gH_TimerTopMsg[client]);
		gH_TimerTopMsg[client] = INVALID_HANDLE;
	}
	
	g_bPrintAnalysis[client] = false;
	g_bIsDebugOnAnalysis = IsDebugOnAnalysis();
	
	g_bDebugStrafes[client] = false;
	g_bIsDebugOnStrafes = IsDebugOnStrafes();
	
	g_bCheckSync[client] = false;
	g_bCheckSyncSW[client] = false;
	g_bIsDebugOnSync = IsDebugOnSync();
	
	g_bPrintAnalysisSW[client] = false;
	g_bIsDebugOnAnalysisSW = IsDebugOnAnalysisSW();
	
	g_bDebugStrafesSW[client] = false;
	g_bIsDebugOnStrafesSW = IsDebugOnStrafesSW();
	
	g_bDebugKeysHoldtimeAD[client] = false;
	g_bIsDebugOnKeysAD = IsDebugOnKeysAD();
	
	g_bDebugKeysHoldtimeWS[client] = false;
	g_bIsDebugOnKeysWS = IsDebugOnKeysWS();
	
	g_bConsoleOutput[client] = false;
	g_bPrintAngleDiff[client] = false;
	g_bCheckAngleDiff[client] = false;
	g_bIsDebugOnAdv = IsDebugOnAdv();
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	static Float:fOldAngleY[MAXPLAYERS+1];
	static Float:fOldAngleX[MAXPLAYERS+1];
	static Float:fOldSideMove[MAXPLAYERS+1];
	static Float:fOldForwardMove[MAXPLAYERS+1];
	static Float:fOldAngleDiff[MAXPLAYERS+1];
	
	static ticksAfterAngleCheckBlock[MAXPLAYERS+1];
	static skipFramesAfterAngleCheckBlock[MAXPLAYERS+1];
	
	if (IsFakeClient(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	new Float:fAngleDiff = angles[1] - fOldAngleY[client];
	if (fAngleDiff > 180.0)
		fAngleDiff -= 360.0; // Negative value (turned to the right)
	else if (fAngleDiff < -180.0)
		fAngleDiff += 360.0; // Positive value (turned to the left)
	
	if (g_bBlockAngleCheck[client])
	{
		if (fAngleDiff > 70.0 || fAngleDiff < -70.0)
		{
			// Skip the anglehack check
			g_bBlockAngleCheck[client] = false;
			ticksAfterAngleCheckBlock[client] = 0;
			skipFramesAfterAngleCheckBlock[client] = 20;
		}
		else if (ticksAfterAngleCheckBlock[client] > 50)
		{
			// Stop checking for anglediff of >< 70
			g_bBlockAngleCheck[client] = false;
			ticksAfterAngleCheckBlock[client] = 0;
		}
		// Keep checking for anglediff of >< 70 for 50 ticks
		++ticksAfterAngleCheckBlock[client];
	}
	else if (skipFramesAfterAngleCheckBlock[client] == 0 && fOldAngleDiff[client] == 0.0
	&& ((89.99 <= fAngleDiff <= 90.01) || (-89.99 >= fAngleDiff >= -90.01) || (179.99 <= fAngleDiff <= 180.01) || (-179.99 >= fAngleDiff >= -180.01)))
	{
		// TODO: Anti-AngleHack should really be implemented in a new plugin
		// SayText2Admins("\x01\x07FFD700%N is suspected of having an anglehack!", client);
		// LogSuspect(client, ANGLEHACK, "Suspected of having an anglehack.\nDetection: Anglehack Check", _, fAngleDiff);
	}
	fOldAngleDiff[client] = fAngleDiff;
	
	if (g_bIsDebugOnAdv)
		DebugAdvanced(client, vel[0], vel[1], angles[0], angles[1], fAngleDiff, skipFramesAfterAngleCheckBlock[client]);
	
	if (skipFramesAfterAngleCheckBlock[client] > 0)
		--skipFramesAfterAngleCheckBlock[client];
	
	if (InvalidMovement(client, vel[0], vel[1], angles[0], angles[1], fOldAngleX[client], fOldAngleY[client], fOldSideMove[client], fOldForwardMove[client], buttons))
		return Plugin_Continue;
	
	fOldSideMove[client] = vel[1];
	fOldForwardMove[client] = vel[0];
	fOldAngleY[client] = angles[1];
	fOldAngleX[client] = angles[0];
	
	g_bOldWalking[client] = g_bWalking[client];
	if (GetEntityMoveType(client) == MOVETYPE_WALK)
		g_bWalking[client] = true;
	else {
		g_bWalking[client] = false;
		return Plugin_Continue;
	}
	if (GetEntityFlags(client) & FL_ONGROUND)
		g_bOnGround[client] = true;
	else
		g_bOnGround[client] = false;
	
	// The tick is used as a time reference.
	// Have in mind that this plugin is meant
	// to be used on 100 tickrate servers.
	++g_Tick[client];
	
	// Check if the client has turned with the mouse
	// and check if he switched between forwardmove / sidemove.
	CheckIfTurned(client, fAngleDiff);
	CheckIfSwitchedMov(client, vel[1], vel[0], angles[1]);
	
	// Now check if he switched between buttons (keys)
	CheckIfSwitchedKeys(client, buttons);
	
	// Handle sync
	if ((!g_bOnGround[client] || (g_bOnGround[client] && !g_bOldOnGround[client])) && g_bOldWalking[client])
	{
		switch (GetDirection(client, angles[1], 0))
		{
			case 1: CheckSync(client, buttons, vel[1], fAngleDiff);
			case 2: CheckSyncSW(client, buttons, vel[0], fAngleDiff, angles[1]);
			case 3: CheckSyncHSW(client, buttons, fAngleDiff);
		}
	}
	
	if (g_bIsDebugOnSync)
		DebugSync(client);
	
	g_bOldOnGround[client] = g_bOnGround[client];
	return Plugin_Continue;
}

//----------------------------------------------------------------------
// This function checks for invalid and unsynchronized movement.
// Valid movement = 0, 100, 200, 400
// Movement triggered by anything else but buttons is considered
// to be unsynchronized.
// +strafe prevention is handled in this function.
//----------------------------------------------------------------------
bool:InvalidMovement(client, Float:fForwardMove, Float:fSideMove, Float:fAngleX, Float:fAngleY, Float:fOldAngleX, Float:fOldAngleY, Float:fOldSideMove, Float:fOldForwardMove, buttons)
{
	static invalidForwardMove[MAXPLAYERS+1];
	static invalidSideMove[MAXPLAYERS+1];
	static dodgyBehaviour[MAXPLAYERS+1];
	
	if (fForwardMove == 400.0 || fForwardMove == 200.0 || fForwardMove == 100.0
	|| fForwardMove == 0.0
	|| fForwardMove == -100.0 || fForwardMove == -200.0 || fForwardMove == -400.0)
		invalidForwardMove[client] = 0;
	else
		++invalidForwardMove[client];
	
	if (fSideMove == 400.0 || fSideMove == 200.0 || fSideMove == 100.0
	|| fSideMove == 0.0
	|| fSideMove == -100.0 || fSideMove == -200.0 || fSideMove == -400.0)
		invalidSideMove[client] = 0;
	else
		++invalidSideMove[client];
	
	if ((invalidForwardMove[client] > 1 || invalidSideMove[client] > 1) && !g_bPreventInvalidMovSpam[client])
	{
		decl bool:varyingSideMove;
		if ((fSideMove > 0.0 && fOldSideMove > 0.0)
		|| (fSideMove < 0.0 && fOldSideMove < 0.0))
			varyingSideMove = false;
		else
			varyingSideMove = true;
		
		if (fOldAngleY == fAngleY && fOldAngleX == fAngleX
		&& (!(395.0 < fSideMove <= 400.0) && !(-395.0 > fSideMove >= -400.0))) // +strafe detected!
		{
			new Handle:sync = CreateHudSynchronizer();
			if (sync != INVALID_HANDLE)
			{
				SetHudTextParams(-1.0, -0.8, 5.0, 255, 255, 255, 255, 0, 5.0, 0.1, 0.2);
				ShowSyncHudText(client, sync, "+strafe is not allowed on this server!");
				CloseHandle(sync);
			}
			FreezeSilent(client, FREEZE_TIME);
			
			g_bPreventInvalidMovSpam[client] = true;
			invalidForwardMove[client] = 0;
			invalidSideMove[client] = 0;
			dodgyBehaviour[client] = 0;
			CreateTimer(FREEZE_TIME, Timer_PreventInvalidMovSpam, GetClientUserId(client));
			return true;
		}
		else if (varyingSideMove)
		{
			// Usually catches silentstrafe because of varying sidemove. (varying = 1st frame positive, next frame negative and vice versa)
			SayText2All("\x01\x07FF6200%N is suspected of having invalid movement (varying sidemove)!", client);
			#if (FREEZE_ENABLE == 1)
			FreezeClient(client, FREEZE_TIME);
			#endif
			LogCheater(client, INVALID_MOV_VARYINGSM, "Suspected of having invalid movement (varying sidemove).\nDetection: Automatic (Invalid movement - varying sidemove)");
			
			g_bPreventInvalidMovSpam[client] = true;
			invalidForwardMove[client] = 0;
			invalidSideMove[client] = 0;
			dodgyBehaviour[client] = 0;
			CreateTimer(FREEZE_TIME, Timer_PreventInvalidMovSpam, GetClientUserId(client));
			return true;
		}
		
		decl bool:varyingForwardMove;
		if ((fForwardMove > 0.0 && fOldForwardMove > 0.0)
		|| (fForwardMove < 0.0 && fOldForwardMove < 0.0))
			varyingForwardMove = false;
		else
			varyingForwardMove = true;
		
		if (fOldAngleY == fAngleY && fOldAngleX == fAngleX
		&& (!(395.0 < fForwardMove <= 400.0) && !(-395.0 > fForwardMove >= -400.0))) // +strafe detected!
		{
			new Handle:sync = CreateHudSynchronizer();
			if (sync != INVALID_HANDLE)
			{
				SetHudTextParams(-1.0, -0.8, 5.0, 255, 255, 255, 255, 0, 5.0, 0.1, 0.2);
				ShowSyncHudText(client, sync, "+strafe is not allowed on this server!");
				CloseHandle(sync);
			}
			FreezeSilent(client, FREEZE_TIME);
			
			g_bPreventInvalidMovSpam[client] = true;
			invalidForwardMove[client] = 0;
			invalidSideMove[client] = 0;
			dodgyBehaviour[client] = 0;
			CreateTimer(FREEZE_TIME, Timer_PreventInvalidMovSpam, GetClientUserId(client));
			return true;
		}
		else if (varyingForwardMove)
		{
			SayText2All("\x01\x07FF6200%N is suspected of having invalid movement (varying forwardmove)!", client);
			#if (FREEZE_ENABLE == 1)
			FreezeClient(client, FREEZE_TIME);
			#endif
			LogCheater(client, INVALID_MOV_VARYINGFM, "Suspected of having invalid movement (varying forwardmove).\nDetection: Automatic (Invalid movement - varying forwardmove)");
			
			g_bPreventInvalidMovSpam[client] = true;
			invalidForwardMove[client] = 0;
			invalidSideMove[client] = 0;
			dodgyBehaviour[client] = 0;
			CreateTimer(FREEZE_TIME, Timer_PreventInvalidMovSpam, GetClientUserId(client));
			return true;
		}
	}
	
	if ((fOldAngleY != fAngleY || fOldAngleX != fAngleX) && !g_bPreventInvalidMovSpam[client])
	{
		if (fSideMove > 0.0) // Right
			if (!(buttons & IN_MOVERIGHT))
				++dodgyBehaviour[client];
		
		if (fSideMove < 0.0) // Left
			if (!(buttons & IN_MOVELEFT))
				++dodgyBehaviour[client];
		
		if (fForwardMove > 0.0) // Forward
			if (!(buttons & IN_FORWARD))
				++dodgyBehaviour[client];
		
		if (fForwardMove < 0.0) // Back
			if (!(buttons & IN_BACK))
				++dodgyBehaviour[client];
	}
	
	if (dodgyBehaviour[client] > 4 && !g_bPreventInvalidMovSpam[client])
	{
		SayText2All("\x01\x07FF6200%N is suspected of having unsynchronized movement!", client);
		#if (FREEZE_ENABLE == 1)
		FreezeClient(client, FREEZE_TIME);
		#endif
		LogCheater(client, UNSYNCHRONIZED_MOV, "Suspected of having unsynchronized movement.\nDetection: Automatic (Unsynchronized movement)");
		
		g_bPreventInvalidMovSpam[client] = true;
		invalidForwardMove[client] = 0;
		invalidSideMove[client] = 0;
		dodgyBehaviour[client] = 0;
		CreateTimer(FREEZE_TIME, Timer_PreventInvalidMovSpam, GetClientUserId(client));
		return true;
	}
	
	return false;
}

//----------------------------------------------------------------------
// Checks if a client turned his mouse to the left or to the right.
//----------------------------------------------------------------------
void CheckIfTurned(client, Float:fAngleDiff)
{
	if (fAngleDiff > 0.0 && g_LastTurnDir[client] == 1)
	{
		ClientTurned(client, 0); // Player has turned to the left.
		return;
	}
	if (fAngleDiff < 0.0 && g_LastTurnDir[client] == 0)
	{
		ClientTurned(client, 1); // Player has turned to the right.
	}
}

//----------------------------------------------------------------------
// Client turned his mouse.
//----------------------------------------------------------------------
void ClientTurned(client, turnDirection)
{
	g_LastTurnDir[client] = turnDirection;
	g_LastTurnTime[client] = g_Tick[client];
	g_bTurned[client][turnDirection] = true;
	g_bTurned[client][(turnDirection + 1) % 2] = false;
	
	if ((g_bOnGround[client] && !(g_bOnGround[client] && !g_bOldOnGround[client])) || !g_bOldWalking[client])
		return;
	
	// This will happen if you've moved first.
	HandleFrameIfMovedFirst(client, turnDirection);
	HandleFrameIfMovedFirst_SW(client, turnDirection);
}

//----------------------------------------------------------------------
// Client moved first and then turned his mouse.
// Style: Forwards
//----------------------------------------------------------------------
void HandleFrameIfMovedFirst(client, turnDirection)
{
	if (turnDirection == g_LastMoveDir[client])
	{
		// The difference in ticks will mostly be negative or 0 if perfect.
		new difference = (g_LastMoveTime[client] - g_LastTurnTime[client]) + 1;
		if (-20 <= difference <= 20)
		{
			g_Frames[client][g_CurrentFrame[client]][0] = difference;
			g_Frames[client][g_CurrentFrame[client]][1] = 0;
			++g_CurrentFrame[client];
			
			++g_TotalStrafes[client];
			if (-1 <= difference <= 1)
				++g_PerfectStrafes[client];
			if (-5 <= difference <= 5)
				++g_GoodStrafes[client];
			
			if (g_bIsDebugOnStrafes)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bDebugStrafes[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x07FF69B4moved first \x07FFFFFF| F | TD: \x07FFFF00%d", client, difference);
				}
			}
			
			AntiCheatCheck1(client, g_CurrentFrame[client]);
			AntiCheatCheck2(client, g_CurrentFrame[client]);
		}
	}
}

//----------------------------------------------------------------------
// Anticheat checks based on strafe tick difference and sync.
// Style: Forwards
//----------------------------------------------------------------------
void AntiCheatCheck1(client, numFrames)
{
	if (numFrames == 20)
	{
		new movedFirstCount, turnedFirstCount;
		new movedFirstPerfect, turnedFirstPerfect;
		new movedFirst1, turnedFirst1;
		new movedFirst2, turnedFirst2;
		
		CountFrames(client, g_Frames, 20, movedFirstCount, turnedFirstCount, movedFirstPerfect, turnedFirstPerfect, movedFirst1, turnedFirst1, movedFirst2, turnedFirst2);
		
		new Float:fSync1 = GetClientSync(client, 0);
		new Float:fSync2 = GetClientSync(client, 1);
		new Float:fSync3 = GetClientSync(client, 2);
		
		if (fSync1 < fSync2 || fSync2 > fSync3 || fSync1 < fSync3 || (IsSyncEqual(fSync1, fSync2, fSync3) && turnedFirstPerfect >= 15))
		{
			SayText2Admins("\x01\x07FFFF0020\x07FFFFFF Strafes Tick Difference Analysis");
			SayText2Admins("\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
			SayText2Admins("\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
			SayText2Admins("\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", fSync1, fSync2, fSync3);
			SayText2Admins("\x01\x07FFFFFFPlayer: \x0700FF08%N", client);
			SayText2All("\x01\x07FF6200%N is suspected of using a strafehack!", client);
			#if (FREEZE_ENABLE == 1)
			FreezeClient(client, FREEZE_TIME);
			#endif
			LogCheater(client, N_STRAFEHACK_20, "Suspected of using a strafehack.\nDetection: 20 Strafes Tick Difference", fSync1, fSync2, fSync3, movedFirstCount, movedFirstPerfect, turnedFirstCount, turnedFirstPerfect, movedFirst1, movedFirst2, turnedFirst1, turnedFirst2);
		}
		else
		{
			if (g_bIsDebugOnAnalysis)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bPrintAnalysis[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
					{
						SayText2(i, "\x01\x07FFFF0020\x07FFFFFF Strafes Tick Difference Analysis");
						SayText2(i, "\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
						SayText2(i, "\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
						SayText2(i, "\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", fSync1, fSync2, fSync3);
						SayText2(i, "\x01\x07FFFFFFPlayer: \x0700FF08%N", client);
					}
				}
			}
		}
	}
}

void AntiCheatCheck2(client, numFrames)
{
	if (numFrames == 40)
	{
		new movedFirstCount, turnedFirstCount;
		new movedFirstPerfect, turnedFirstPerfect;
		new movedFirst1, turnedFirst1;
		new movedFirst2, turnedFirst2;
		
		CountFrames(client, g_Frames, 40, movedFirstCount, turnedFirstCount, movedFirstPerfect, turnedFirstPerfect, movedFirst1, turnedFirst1, movedFirst2, turnedFirst2);
		
		new Float:fSync1 = GetClientSync(client, 0);
		new Float:fSync2 = GetClientSync(client, 1);
		new Float:fSync3 = GetClientSync(client, 2);
		
		if (turnedFirstPerfect >= 30 || fSync1 < fSync2 || fSync2 > fSync3 || fSync1 < fSync3 || (IsSyncEqual(fSync1, fSync2, fSync3) && turnedFirstPerfect >= 25))
		{
			SayText2Admins("\x01\x07FFFF0040\x07FFFFFF Strafes Tick Difference Analysis");
			SayText2Admins("\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
			SayText2Admins("\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
			SayText2Admins("\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", fSync1, fSync2, fSync3);
			SayText2Admins("\x01\x07FFFFFFPlayer: \x0700FF08%N", client);
			SayText2All("\x01\x07FF6200%N is suspected of using a strafehack!", client);
			#if (FREEZE_ENABLE == 1)
			FreezeClient(client, FREEZE_TIME);
			#endif
			LogCheater(client, N_STRAFEHACK_40, "Suspected of using a strafehack.\nDetection: 40 Strafes Tick Difference", fSync1, fSync2, fSync3, movedFirstCount, movedFirstPerfect, turnedFirstCount, turnedFirstPerfect, movedFirst1, movedFirst2, turnedFirst1, turnedFirst2);
		}
		else
		{
			if (g_bIsDebugOnAnalysis)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bPrintAnalysis[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
					{
						SayText2(i, "\x01\x07FFFF0040\x07FFFFFF Strafes Tick Difference Analysis");
						SayText2(i, "\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
						SayText2(i, "\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
						SayText2(i, "\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", fSync1, fSync2, fSync3);
						SayText2(i, "\x01\x07FFFFFFPlayer: \x0700FF08%N", client);
					}
				}
			}
		}
		
		g_TotalSync[client] = 0;
		g_GoodSync[client][0] = 0;
		g_GoodSync[client][1] = 0;
		g_GoodSync[client][2] = 0;
		
		g_CurrentFrame[client] = 0;
	}
}

//----------------------------------------------------------------------
// Client moved first and then turned his mouse.
// Style: Sideways
//----------------------------------------------------------------------
void HandleFrameIfMovedFirst_SW(client, turnDirection)
{
	if (turnDirection == g_LastMoveDirSW[client])
	{
		// The difference in ticks will mostly be negative or 0 if perfect.
		new differenceSW = (g_LastMoveTimeSW[client] - g_LastTurnTime[client]) + 1;
		if (-20 <= differenceSW <= 20)
		{
			g_FramesSW[client][g_CurrentFrameSW[client]][0] = differenceSW;
			g_FramesSW[client][g_CurrentFrameSW[client]][1] = 0;
			++g_CurrentFrameSW[client];
			
			if (g_bIsDebugOnStrafesSW)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bDebugStrafesSW[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x07FF69B4moved first \x07FFFFFF| S | TD: \x07FFFF00%d", client, differenceSW);
				}
			}
			
			AntiCheatCheck1_SW(client, g_CurrentFrameSW[client]);
			AntiCheatCheck2_SW(client, g_CurrentFrameSW[client]);
		}
	}
}

//----------------------------------------------------------------------
// Anticheat checks based on strafe tick difference and sync.
// Style: Sideways
//----------------------------------------------------------------------
void AntiCheatCheck1_SW(client, numFrames)
{
	if (numFrames == 20)
	{
		new movedFirstCount, turnedFirstCount;
		new movedFirstPerfect, turnedFirstPerfect;
		new movedFirst1, turnedFirst1;
		new movedFirst2, turnedFirst2;
		
		CountFrames(client, g_FramesSW, 20, movedFirstCount, turnedFirstCount, movedFirstPerfect, turnedFirstPerfect, movedFirst1, turnedFirst1, movedFirst2, turnedFirst2);
		
		new Float:fSync1 = GetClientSyncSW(client, 0);
		new Float:fSync2 = GetClientSyncSW(client, 1);
		new Float:fSync3 = GetClientSyncSW(client, 2);
		
		if (fSync1 < fSync2 || fSync2 > fSync3 || (IsSyncEqual(fSync1, fSync2, fSync3) && turnedFirstPerfect >= 10)) // I'm aware it's 10 here
		{
			SayText2Admins("\x01\x07FFFF0020\x07FFFFFF Strafes Tick Difference Analysis [Sideways]");
			SayText2Admins("\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
			SayText2Admins("\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
			SayText2Admins("\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", fSync1, fSync2, fSync3);
			SayText2Admins("\x01\x07FFFFFFPlayer: \x0700FF08%N", client);
			SayText2All("\x01\x07FF6200%N is suspected of using a strafehack! [Sideways]", client);
			#if (FREEZE_ENABLE == 1)
			FreezeClient(client, FREEZE_TIME);
			#endif
			LogCheater(client, SW_STRAFEHACK_20, "Suspected of using a strafehack [Sideways].\nDetection: 20 Strafes Tick Difference [Sideways]", fSync1, fSync2, fSync3, movedFirstCount, movedFirstPerfect, turnedFirstCount, turnedFirstPerfect, movedFirst1, movedFirst2, turnedFirst1, turnedFirst2);
		}
		else
		{
			if (g_bIsDebugOnAnalysisSW)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bPrintAnalysisSW[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
					{
						SayText2(i, "\x01\x07FFFF0020\x07FFFFFF Strafes Tick Difference Analysis [Sideways]");
						SayText2(i, "\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
						SayText2(i, "\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
						SayText2(i, "\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", fSync1, fSync2, fSync3);
						SayText2(i, "\x01\x07FFFFFFPlayer: \x0700FF08%N", client);
					}
				}
			}
		}
	}
}

void AntiCheatCheck2_SW(client, numFrames)
{
	if (numFrames == 40)
	{
		new movedFirstCount, turnedFirstCount;
		new movedFirstPerfect, turnedFirstPerfect;
		new movedFirst1, turnedFirst1;
		new movedFirst2, turnedFirst2;
		
		CountFrames(client, g_FramesSW, 40, movedFirstCount, turnedFirstCount, movedFirstPerfect, turnedFirstPerfect, movedFirst1, turnedFirst1, movedFirst2, turnedFirst2);
		
		new Float:fSync1 = GetClientSyncSW(client, 0);
		new Float:fSync2 = GetClientSyncSW(client, 1);
		new Float:fSync3 = GetClientSyncSW(client, 2);
		
		if (fSync1 < fSync2 || fSync2 > fSync3 || (IsSyncEqual(fSync1, fSync2, fSync3) && turnedFirstPerfect >= 20)) // Also aware that it's 20
		{
			SayText2Admins("\x01\x07FFFF0040\x07FFFFFF Strafes Tick Difference Analysis [Sideways]");
			SayText2Admins("\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
			SayText2Admins("\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
			SayText2Admins("\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", fSync1, fSync2, fSync3);
			SayText2Admins("\x01\x07FFFFFFPlayer: \x0700FF08%N", client);
			SayText2All("\x01\x07FF6200%N is suspected of using a strafehack! [Sideways]", client);
			#if (FREEZE_ENABLE == 1)
			FreezeClient(client, FREEZE_TIME);
			#endif
			LogCheater(client, SW_STRAFEHACK_40, "Suspected of using a strafehack [Sideways].\nDetection: 40 Strafes Tick Difference [Sideways]", fSync1, fSync2, fSync3, movedFirstCount, movedFirstPerfect, turnedFirstCount, turnedFirstPerfect, movedFirst1, movedFirst2, turnedFirst1, turnedFirst2);
		}
		else
		{
			if (g_bIsDebugOnAnalysisSW)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bPrintAnalysisSW[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
					{
						SayText2(i, "\x01\x07FFFF0040\x07FFFFFF Strafes Tick Difference Analysis [Sideways]");
						SayText2(i, "\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
						SayText2(i, "\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
						SayText2(i, "\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", fSync1, fSync2, fSync3);
						SayText2(i, "\x01\x07FFFFFFPlayer: \x0700FF08%N", client);
					}
				}
			}
		}
		
		g_TotalSyncSW[client] = 0;
		g_GoodSyncSW[client][0] = 0;
		g_GoodSyncSW[client][1] = 0;
		g_GoodSyncSW[client][2] = 0;
		
		g_CurrentFrameSW[client] = 0;
	}
}

//----------------------------------------------------------------------
// Checks if a client switched movement (forwardmove / sidemove)
//----------------------------------------------------------------------
void CheckIfSwitchedMov(client, Float:fSideMove, Float:fForwardMove, Float:fAngleY)
{
	// Store last/old values to check if keys have been switched.
	static Float:fLastSideMove[MAXPLAYERS+1];
	static Float:fLastForwardMove[MAXPLAYERS+1];
	
	// Those are used for the sidemove spam check.
	static moveTicks[MAXPLAYERS+1][20][2];
	static currentMoveTick[MAXPLAYERS+1];
	
	if (fSideMove < 0.0) // Left
	{
		if (fLastSideMove[client] >= 0.0)
		{
			if (g_Tick[client] - g_LastMoveTime[client] <= 5)
			{
				moveTicks[client][currentMoveTick[client]][0] = 0;
				moveTicks[client][currentMoveTick[client]][1] = g_Tick[client];
				++currentMoveTick[client];
				
				if (currentMoveTick[client] == 20)
				{
					new moveLeftTime, moveRightTime;
					for (new f = 0; f < 20; ++f)
					{
						if (moveTicks[client][f][0] == 0)
							moveLeftTime += moveTicks[client][f][1];
						else
							moveRightTime += moveTicks[client][f][1];
					}
					
					if (-1 <= (moveLeftTime - moveRightTime) <= 1)
					{
						SayText2All("\x01\x07FF6200%N is suspected of using a silentstrafe hack! (SM Spam)", client);
						#if (FREEZE_ENABLE == 1)
						FreezeClient(client, FREEZE_TIME);
						#endif
						LogCheater(client, SILENTSTRAFE_SMSPAM, "Suspected of using a silentstrafe hack.\nDetection: Automatic (Sidemove Spam)");
					}
					currentMoveTick[client] = 0;
				}
			}
			else
			{
				currentMoveTick[client] = 0;
			}
			g_LastMoveDir[client] = 0;
			g_LastMoveTime[client] = g_Tick[client];
			if ((!g_bOnGround[client] || (g_bOnGround[client] && !g_bOldOnGround[client])) && g_bOldWalking[client])
				ClientSwitchedMov(client);
		}
	}
	else if (fSideMove > 0.0) // Right
	{
		if (fLastSideMove[client] <= 0.0)
		{
			if (g_Tick[client] - g_LastMoveTime[client] <= 5)
			{
				moveTicks[client][currentMoveTick[client]][0] = 1;
				moveTicks[client][currentMoveTick[client]][1] = g_Tick[client];
				++currentMoveTick[client];
				
				if (currentMoveTick[client] == 20)
				{
					new moveLeftTime, moveRightTime;
					for (new f = 0; f < 20; ++f)
					{
						if (moveTicks[client][f][0] == 0)
							moveLeftTime += moveTicks[client][f][1];
						else
							moveRightTime += moveTicks[client][f][1];
					}
					
					if (-1 <= (moveLeftTime - moveRightTime) <= 1)
					{
						SayText2All("\x01\x07FF6200%N is suspected of using a silentstrafe hack! (SM Spam)", client);
						#if (FREEZE_ENABLE == 1)
						FreezeClient(client, FREEZE_TIME);
						#endif
						LogCheater(client, SILENTSTRAFE_SMSPAM, "Suspected of using a silentstrafe hack.\nDetection: Automatic (Sidemove Spam)");
					}
					currentMoveTick[client] = 0;
				}
			}
			else
			{
				currentMoveTick[client] = 0;
			}
			g_LastMoveDir[client] = 1;
			g_LastMoveTime[client] = g_Tick[client];
			if ((!g_bOnGround[client] || (g_bOnGround[client] && !g_bOldOnGround[client])) && g_bOldWalking[client])
				ClientSwitchedMov(client);
		}
	}
	
	fLastSideMove[client] = fSideMove;
	
	if (fForwardMove > 0.0) // Forward
	{
		if (fLastForwardMove[client] <= 0.0)
		{
			switch (GetDirection(client, fAngleY, 1))
			{
				case 1: // 90
				{
					g_LastMoveDirSW[client] = 1;
					g_LastMoveTimeSW[client] = g_Tick[client];
					if ((!g_bOnGround[client] || (g_bOnGround[client] && !g_bOldOnGround[client])) && g_bOldWalking[client])
						ClientSwitchedMovSW(client);
				}
				case 2: // 270
				{
					g_LastMoveDirSW[client] = 0;
					g_LastMoveTimeSW[client] = g_Tick[client];
					if ((!g_bOnGround[client] || (g_bOnGround[client] && !g_bOldOnGround[client])) && g_bOldWalking[client])
						ClientSwitchedMovSW(client);
				}
			}
		}
	}
	else if (fForwardMove < 0.0) // Back
	{
		if (fLastForwardMove[client] >= 0.0)
		{
			switch (GetDirection(client, fAngleY, 1))
			{
				case 1: // 90
				{
					g_LastMoveDirSW[client] = 0;
					g_LastMoveTimeSW[client] = g_Tick[client];
					if ((!g_bOnGround[client] || (g_bOnGround[client] && !g_bOldOnGround[client])) && g_bOldWalking[client])
						ClientSwitchedMovSW(client);
				}
				case 2: // 270
				{
					g_LastMoveDirSW[client] = 1;
					g_LastMoveTimeSW[client] = g_Tick[client];
					if ((!g_bOnGround[client] || (g_bOnGround[client] && !g_bOldOnGround[client])) && g_bOldWalking[client])
						ClientSwitchedMovSW(client);
				}
			}
		}
	}
	
	fLastForwardMove[client] = fForwardMove;
}

//----------------------------------------------------------------------
// Client switched movement (sidemove).
// Style: Forwards
//----------------------------------------------------------------------
void ClientSwitchedMov(client)
{
	// This will happen if you've turned first.
	if (g_bTurned[client][g_LastMoveDir[client]] == true)
	{
		// The difference in ticks will mostly be positive or 0 if perfect.
		new difference = g_LastMoveTime[client] - g_LastTurnTime[client];
		if (-20 <= difference <= 20)
		{
			g_Frames[client][g_CurrentFrame[client]][0] = difference;
			g_Frames[client][g_CurrentFrame[client]][1] = 1;
			++g_CurrentFrame[client];
			
			++g_TotalStrafes[client];
			if (-1 <= difference <= 1)
				++g_PerfectStrafes[client];
			if (-5 <= difference <= 5)
				++g_GoodStrafes[client];
			
			if (g_bIsDebugOnStrafes)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bDebugStrafes[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x0700FFFFturned first \x07FFFFFF| F | TD: \x07FFFF00%d", client, difference);
				}
			}
			
			AntiCheatCheck1(client, g_CurrentFrame[client]);
			AntiCheatCheck2(client, g_CurrentFrame[client]);
		}
	}
}

//----------------------------------------------------------------------
// Client switched movement (forwardmove).
// Style: Sideways
//----------------------------------------------------------------------
void ClientSwitchedMovSW(client)
{
	// This will happen if you've turned first.
	if (g_bTurned[client][g_LastMoveDirSW[client]] == true)
	{
		// The difference in ticks will mostly be positive or 0 if perfect.
		new differenceSW = g_LastMoveTimeSW[client] - g_LastTurnTime[client];
		if (-20 <= differenceSW <= 20)
		{
			g_FramesSW[client][g_CurrentFrameSW[client]][0] = differenceSW;
			g_FramesSW[client][g_CurrentFrameSW[client]][1] = 1;
			++g_CurrentFrameSW[client];
			
			if (g_bIsDebugOnStrafesSW)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bDebugStrafesSW[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x0700FFFFturned first \x07FFFFFF| S | TD: \x07FFFF00%d", client, differenceSW);
				}
			}
			
			AntiCheatCheck1_SW(client, g_CurrentFrameSW[client]);
			AntiCheatCheck2_SW(client, g_CurrentFrameSW[client]);
		}
	}
}

//----------------------------------------------------------------------
// Count the strafe frames, how many of them were perfect, etc.
//----------------------------------------------------------------------
void CountFrames(client, array[][][], amount, &movedFirstCount, &turnedFirstCount, &movedFirstPerfect, &turnedFirstPerfect, &movedFirst1, &turnedFirst1, &movedFirst2, &turnedFirst2)
{
	for (new f = 0; f < amount; ++f)
	{
		if (array[client][f][1] == 0) // [1] stands for the strafe type. 0 = moved first, 1 = turned first.
		{
			++movedFirstCount;
			switch (array[client][f][0]) // [0] is the tick difference. 0 = perfect.
			{
				case 0: ++movedFirstPerfect;
				case -1: ++movedFirst1;
				case -2: ++movedFirst2;
			}
		}
		else
		{
			++turnedFirstCount;
			switch (array[client][f][0])
			{
				case 0: ++turnedFirstPerfect;
				case 1: ++turnedFirst1;
				case 2: ++turnedFirst2;
			}
		}
	}
}

//----------------------------------------------------------------------
// Checks if a client switched between his keys (button flags)
// Note: A = left, D = right, W = forwards, S = backwards
// Note2: This function was originally meant to check the above,
// however, it is now checking for key holdtime.
//----------------------------------------------------------------------
void CheckIfSwitchedKeys(client, buttons)
{
	static oldButtons[MAXPLAYERS+1];
	
	static holdAD[MAXPLAYERS+1];
	static holdWS[MAXPLAYERS+1];
	
	// A/D
	if (buttons & IN_MOVELEFT)
	{
		if (buttons & IN_MOVERIGHT)
		{
			++holdAD[client];
		}
		else if (!(buttons & IN_MOVERIGHT) && (oldButtons[client] & IN_MOVERIGHT))
		{
			// D was released
			if (holdAD[client] == 0)
			{
				++g_CurrentFrameKeysAD[client];
				AntiCheatCheck_KeysAD(client, g_CurrentFrameKeysAD[client]);
			}
			else
			{
				g_CurrentFrameKeysAD[client] = 0;
			}
			
			if (g_bIsDebugOnKeysAD)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bDebugKeysHoldtimeAD[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x07FFFFFFD\x07FFFF00->\x07FFFFFFA | Hold: \x07FFFF00%d \x07FFFFFFStreak: \x07FFFF00%d", client, holdAD[client], g_CurrentFrameKeysAD[client]);
				}
			}
			holdAD[client] = 0;
		}
	}
	
	if (buttons & IN_MOVERIGHT)
	{
		if (!(buttons & IN_MOVELEFT) && (oldButtons[client] & IN_MOVELEFT))
		{
			// A was released
			if (holdAD[client] == 0)
			{
				++g_CurrentFrameKeysAD[client];
				AntiCheatCheck_KeysAD(client, g_CurrentFrameKeysAD[client]);
			}
			else
			{
				g_CurrentFrameKeysAD[client] = 0;
			}
			
			if (g_bIsDebugOnKeysAD)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bDebugKeysHoldtimeAD[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x07FFFFFFA\x07FFFF00->\x07FFFFFFD | Hold: \x07FFFF00%d \x07FFFFFFStreak: \x07FFFF00%d", client, holdAD[client], g_CurrentFrameKeysAD[client]);
				}
			}
			holdAD[client] = 0;
		}
	}
	
	// W/S
	if (buttons & IN_FORWARD)
	{
		if (buttons & IN_BACK)
		{
			++holdWS[client];
		}
		else if (!(buttons & IN_BACK) && (oldButtons[client] & IN_BACK))
		{
			// S was released
			if (holdWS[client] == 0)
			{
				++g_CurrentFrameKeysWS[client];
				AntiCheatCheck_KeysWS(client, g_CurrentFrameKeysWS[client]);
			}
			else
			{
				g_CurrentFrameKeysWS[client] = 0;
			}
			
			if (g_bIsDebugOnKeysWS)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bDebugKeysHoldtimeWS[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x07FFFFFFS\x07FFFF00->\x07FFFFFFW | Hold: \x07FFFF00%d \x07FFFFFFStreak: \x07FFFF00%d", client, holdWS[client], g_CurrentFrameKeysWS[client]);
				}
			}
			holdWS[client] = 0;
		}
	}
	
	if (buttons & IN_BACK)
	{
		if (!(buttons & IN_FORWARD) && (oldButtons[client] & IN_FORWARD))
		{
			// W was released
			if (holdWS[client] == 0)
			{
				++g_CurrentFrameKeysWS[client];
				AntiCheatCheck_KeysWS(client, g_CurrentFrameKeysWS[client]);
			}
			else
			{
				g_CurrentFrameKeysWS[client] = 0;
			}
			
			if (g_bIsDebugOnKeysWS)
			{
				for (new i = 1; i <= MaxClients; ++i)
				{
					if (!IsClientInGame(i) || IsFakeClient(i) || !g_bDebugKeysHoldtimeWS[i]) continue;
					new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
					if (target == client)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x07FFFFFFW\x07FFFF00->\x07FFFFFFS | Hold: \x07FFFF00%d \x07FFFFFFStreak: \x07FFFF00%d", client, holdWS[client], g_CurrentFrameKeysWS[client]);
				}
			}
			holdWS[client] = 0;
		}
	}
	
	oldButtons[client] = buttons;
}

//----------------------------------------------------------------------
// Anticheat checks based on button flags / keys.
// Note: These are meant to detect scripts which make holding both
// keys at the same time impossible (the old key is always released).
//----------------------------------------------------------------------
void AntiCheatCheck_KeysAD(client, numFrames)
{
	if (numFrames != 0 && numFrames % 100 == 0)
	{
		SayText2Admins("\x01\x07FFD700%N is suspected of having too many perfect key changes! |A/D| (%d)", client, numFrames);
		SayText2Admins("\x01\x07FFFFFFF Sync at frame \x07FFFF00%d\x07FFFFFF:  \x0700FF08%f \x07FFFFFF| \x0700FF08%f \x07FFFFFF| \x0700FF08%f", g_CurrentFrame[client], GetClientSync(client, 0), GetClientSync(client, 1), GetClientSync(client, 2));
		SayText2Admins("\x01\x07FFFFFFS Sync at frame \x07FFFF00%d\x07FFFFFF:  \x0700FF08%f \x07FFFFFF| \x0700FF08%f \x07FFFFFF| \x0700FF08%f", g_CurrentFrameSW[client], GetClientSyncSW(client, 0), GetClientSyncSW(client, 1), GetClientSyncSW(client, 2));
		
		if (numFrames >= 300)
		{
			LogSuspect(client, PERFECT_KEY_CHANGES_AD, "Suspected of having too many perfect keychanges.\nDetection: Key Holdtime |A/D|", numFrames, _);
			
			switch (numFrames)
			{
				case 300, 400:
				{
					new Handle:sync = CreateHudSynchronizer();
					if (sync != INVALID_HANDLE)
					{
						SetHudTextParams(-1.0, -0.8, 5.0, 255, 255, 255, 255, 0, 5.0, 0.1, 0.2);
						ShowSyncHudText(client, sync, "Strafe configs are not allowed on this server!");
						CloseHandle(sync);
					}
					// FreezeSilent(client, FREEZE_TIME);
				}
				case 500:
				{
					KickClient(client, "Strafe configs are not allowed on this server!");
				}
			}
		}
	}
}

void AntiCheatCheck_KeysWS(client, numFrames)
{
	if (numFrames != 0 && numFrames % 100 == 0)
	{
		SayText2Admins("\x01\x07FFD700%N is suspected of having too many perfect key changes! |W/S| (%d)", client, numFrames);
		SayText2Admins("\x01\x07FFFFFFF Sync at frame \x07FFFF00%d\x07FFFFFF:  \x0700FF08%f \x07FFFFFF| \x0700FF08%f \x07FFFFFF| \x0700FF08%f", g_CurrentFrame[client], GetClientSync(client, 0), GetClientSync(client, 1), GetClientSync(client, 2));
		SayText2Admins("\x01\x07FFFFFFS Sync at frame \x07FFFF00%d\x07FFFFFF:  \x0700FF08%f \x07FFFFFF| \x0700FF08%f \x07FFFFFF| \x0700FF08%f", g_CurrentFrameSW[client], GetClientSyncSW(client, 0), GetClientSyncSW(client, 1), GetClientSyncSW(client, 2));
		
		if (numFrames >= 300)
		{
			LogSuspect(client, PERFECT_KEY_CHANGES_WS, "Suspected of having too many perfect keychanges.\nDetection: Key Holdtime |W/S|", numFrames, _);
			
			switch (numFrames)
			{
				case 300, 400:
				{
					new Handle:sync = CreateHudSynchronizer();
					if (sync != INVALID_HANDLE)
					{
						SetHudTextParams(-1.0, -0.8, 5.0, 255, 255, 255, 255, 0, 5.0, 0.1, 0.2);
						ShowSyncHudText(client, sync, "Strafe configs are not allowed on this server!");
						CloseHandle(sync);
					}
					// FreezeSilent(client, FREEZE_TIME);
				}
				case 500:
				{
					KickClient(client, "Strafe configs are not allowed on this server!");
				}
			}
		}
	}
}

//----------------------------------------------------------------------
// The next 3 functions handle sync.
//----------------------------------------------------------------------
void CheckSync(client, buttons, Float:fSideMove, Float:fAngleDiff)
{
	if (VelocityLength2D(client) == 0.0)
		return;
	
	if (fAngleDiff > 0.0) // Left
	{
		++g_TotalSync[client];
		++g_TimerTotalSync[client];
		if (buttons & IN_MOVELEFT)
		{
			++g_GoodSync[client][0];
			if (!(buttons & IN_MOVERIGHT))
			{
				++g_GoodSync[client][1];
				++g_TimerGoodSync[client];
			}
		}
		if (fSideMove < 0.0)
		{
			++g_GoodSync[client][2];
		}
		return;
	}
	
	if (fAngleDiff < 0.0) // Right
	{
		++g_TotalSync[client];
		++g_TimerTotalSync[client];
		if (buttons & IN_MOVERIGHT)
		{
			++g_GoodSync[client][0];
			if (!(buttons & IN_MOVELEFT))
			{
				++g_GoodSync[client][1];
				++g_TimerGoodSync[client];
			}
		}
		if (fSideMove > 0.0)
		{
			++g_GoodSync[client][2];
		}
	}
}

void CheckSyncSW(client, buttons, Float:fForwardMove, Float:fAngleDiff, Float:fAngleY)
{
	if (VelocityLength2D(client) == 0.0)
		return;
	
	switch (GetDirection(client, fAngleY, 1))
	{
		case 1: // 90
		{
			if (fAngleDiff > 0.0) // Left
			{
				++g_TotalSyncSW[client];
				++g_TimerTotalSyncSW[client];
				
				if (buttons & IN_BACK)
				{
					++g_GoodSyncSW[client][0];
					if (!(buttons & IN_FORWARD))
					{
						++g_GoodSyncSW[client][1];
						++g_TimerGoodSyncSW[client];
					}
				}
				
				if (fForwardMove < 0.0)
				{
					++g_GoodSyncSW[client][2];
				}
				return;
			}
			
			if (fAngleDiff < 0.0) // Right
			{
				++g_TotalSyncSW[client];
				++g_TimerTotalSyncSW[client];
				
				if (buttons & IN_FORWARD)
				{
					++g_GoodSyncSW[client][0];
					if (!(buttons & IN_BACK))
					{
						++g_GoodSyncSW[client][1];
						++g_TimerGoodSyncSW[client];
					}
				}
				
				if (fForwardMove > 0.0)
				{
					++g_GoodSyncSW[client][2];
				}
			}
		}
		case 2: // 270
		{
			if (fAngleDiff > 0.0) // Left
			{
				++g_TotalSyncSW[client];
				++g_TimerTotalSyncSW[client];
				
				if (buttons & IN_FORWARD)
				{
					++g_GoodSyncSW[client][0];
					if (!(buttons & IN_BACK))
					{
						++g_GoodSyncSW[client][1];
						++g_TimerGoodSyncSW[client];
					}
				}
				
				if (fForwardMove > 0.0)
				{
					++g_GoodSyncSW[client][2];
				}
				return;
			}
			
			if (fAngleDiff < 0.0) // Right
			{
				++g_TotalSyncSW[client];
				++g_TimerTotalSyncSW[client];
				
				if (buttons & IN_BACK)
				{
					++g_GoodSyncSW[client][0];
					if (!(buttons & IN_FORWARD))
					{
						++g_GoodSyncSW[client][1];
						++g_TimerGoodSyncSW[client];
					}
				}
				
				if (fForwardMove < 0.0)
				{
					++g_GoodSyncSW[client][2];
				}
			}
		}
	}
}

void CheckSyncHSW(client, buttons, Float:fAngleDiff)
{
	if (VelocityLength2D(client) == 0.0)
		return;
	
	if (fAngleDiff > 0.0) // Left
	{
		++g_TimerTotalSyncHSW[client];
		if (buttons & IN_FORWARD)
		{
			if (buttons & IN_MOVELEFT)
			{
				if (!(buttons & IN_MOVERIGHT))
				{
					++g_TimerGoodSyncHSW[client];
				}
			}
		}
		return;
	}
	
	if (fAngleDiff < 0.0) // Right
	{
		++g_TimerTotalSyncHSW[client];
		if (buttons & IN_FORWARD)
		{
			if (buttons & IN_MOVERIGHT)
			{
				if (!(buttons & IN_MOVELEFT))
				{
					++g_TimerGoodSyncHSW[client];
				}
			}
		}
	}
}

//----------------------------------------------------------------------
// Gets the direction in which the player is moving (relative
// to his angles).
//----------------------------------------------------------------------
GetDirection(client, Float:fAngleY, type)
{
	decl Float:vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	
	new Float:fTempAngle;
	switch (type)
	{
		case 0: fTempAngle = fAngleY;
		case 1: fTempAngle = fAngleY + 90.0;
	}
	VectorAngles(vVel, fAngleY);
	
	if (fTempAngle < 0.0)
		fTempAngle += 360.0;
	
	new Float:fTempAngle2 = fTempAngle - fAngleY;
	
	if (fTempAngle2 < 0.0)
		fTempAngle2 = -fTempAngle2;
	
	switch (type)
	{
		case 0:
		{
			if (fTempAngle2 < 22.5 || fTempAngle2 > 337.5)
				return 1; // Forwards
			if (fTempAngle2 > 67.5 && fTempAngle2 < 112.5 || fTempAngle2 > 247.5 && fTempAngle2 < 292.5)
				return 2; // Sideways
			if (fTempAngle2 > 22.5 && fTempAngle2 < 67.5 || fTempAngle2 > 292.5 && fTempAngle2 < 337.5)
				return 3; // Half-Sideways (Forwards)
		}
		case 1:
		{
			if (fTempAngle2 < 22.5 || fTempAngle2 > 337.5)
				return 1; // Sideways 90 degrees
			if (fTempAngle2 > 157.5 && fTempAngle2 < 202.5)
				return 2; // Sideways 270 degrees
		}
	}
	return 0; // Unknown / Other direction
}

//----------------------------------------------------------------------
// Turns player's velocity vectors into angles.
// Note: I've modified it a bit due to optimization purposes.
// For more info: https://forums.alliedmods.net/showthread.php?t=234065
//----------------------------------------------------------------------
void VectorAngles(Float:vel[3], &Float:fAngleY)
{
	decl Float:yaw;
	
	if (vel[1] == 0.0 && vel[0] == 0.0)
	{
		yaw = 0.0;
	}
	else
	{
		yaw = (ArcTangent2(vel[1], vel[0]) * (180.0 / FLOAT_PI));
		if (yaw < 0.0)
			yaw += 360.0;
	}
	
	fAngleY = yaw;
}

stock Float:VelocityLength2D(client)
{
	decl Float:vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vVel);
	vVel[2] = 0.0;
	return GetVectorLength(vVel, false);
}

stock bool:IsSyncEqual(Float:fSync1, Float:fSync2, Float:fSync3)
{
	new Float:fS1 = TruncateFloat(fSync1);
	new Float:fS2 = TruncateFloat(fSync2);
	new Float:fS3 = TruncateFloat(fSync3);
	return (fS1 != 0.0 && fS2 != 0.0 && fS3 != 0.0 && fS1 == fS2 && fS1 == fS3 && fS2 == fS3);
}

stock Float:TruncateFloat(Float:trunc)
{
	return float(RoundToNearest(trunc * 100.0)) / 100.0;
}

stock SayText2(to, const String:message[], any:...)
{
	new Handle:hBf = StartMessageOne("SayText2", to);
	if (!hBf) return;
	decl String:buffer[1024];
	VFormat(buffer, sizeof(buffer), message, 3);
	BfWriteByte(hBf, to);
	BfWriteByte(hBf, true);
	BfWriteString(hBf, buffer);
	EndMessage();
}

stock SayText2All(const String:message[], any:...)
{
	for (new to = 1; to <= MaxClients; ++to)
	{
		if (!IsClientInGame(to) || IsFakeClient(to)) continue;
		new Handle:hBf = StartMessageOne("SayText2", to);
		if (!hBf) return;
		decl String:buffer[1024];
		VFormat(buffer, sizeof(buffer), message, 2);
		BfWriteByte(hBf, to);
		BfWriteByte(hBf, true);
		BfWriteString(hBf, buffer);
		EndMessage();
	}
}

stock SayText2Admins(const String:message[], any:...)
{
	for (new to = 1; to <= MaxClients; ++to)
	{
		if (!IsClientInGame(to) || IsFakeClient(to) || !IsAdmin(to)) continue;
		new Handle:hBf = StartMessageOne("SayText2", to);
		if (!hBf) return;
		decl String:buffer[1024];
		VFormat(buffer, sizeof(buffer), message, 2);
		BfWriteByte(hBf, to);
		BfWriteByte(hBf, true);
		BfWriteString(hBf, buffer);
		EndMessage();
	}
}

stock TopMessage(client, const String:text[], any:...)
{
	decl String:message[128];
	VFormat(message, sizeof(message), text, 3);	
	new Handle:kv = CreateKeyValues("Stuff", "title", message);
	KvSetColor(kv, "color", 0, 255, 50, 255);
	KvSetNum(kv, "level", 1);
	KvSetNum(kv, "time", 10);
	CreateDialog(client, kv, DialogType_Msg);
	CloseHandle(kv);
}

stock TopMessage2All(const String:text[], any:...)
{
	for (new to = 1; to <= MaxClients; ++to)
	{
		if (!IsClientInGame(to) || IsFakeClient(to)) continue;
		decl String:message[128];
		VFormat(message, sizeof(message), text, 2);	
		new Handle:kv = CreateKeyValues("Stuff", "title", message);
		KvSetColor(kv, "color", 0, 255, 50, 255);
		KvSetNum(kv, "level", 1);
		KvSetNum(kv, "time", 10);
		CreateDialog(to, kv, DialogType_Msg);
		CloseHandle(kv);
	}
}

stock TopMessage2Admins(const String:text[], any:...)
{
	for (new to = 1; to <= MaxClients; ++to)
	{
		if (!IsClientInGame(to) || IsFakeClient(to) || !IsAdmin(to)) continue;
		decl String:message[128];
		VFormat(message, sizeof(message), text, 2);	
		new Handle:kv = CreateKeyValues("Stuff", "title", message);
		KvSetColor(kv, "color", 0, 255, 50, 255);
		KvSetNum(kv, "level", 1);
		KvSetNum(kv, "time", 10);
		CreateDialog(to, kv, DialogType_Msg);
		CloseHandle(kv);
	}
}

stock bool:IsAdmin(client)
{
	new AdminId:admin = GetUserAdmin(client);
	new bool:customFlag = GetAdminFlag(AdminId:admin, AdminFlag:ADMIN_FLAG);
	if (customFlag) return true;
	return false;
}

#if (FREEZE_ENABLE == 1)
stock FreezeClient(client, Float:time)
{
	SetEntityMoveType(client, MOVETYPE_NONE);
	SetEntityRenderColor(client, 255, 128, 0, 190);
	
	new Float:vec[3];
	GetClientEyePosition(client, vec);
	EmitAmbientSound("physics/glass/glass_impact_bullet4.wav", vec, client, SNDLEVEL_RAIDSIREN);
	
	CreateTimer(time, Timer_FreezeClient, GetClientUserId(client));
}

public Action:Timer_FreezeClient(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	new Float:vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;	
	
	GetClientEyePosition(client, vec);
	EmitAmbientSound("physics/glass/glass_impact_bullet4.wav", vec, client, SNDLEVEL_RAIDSIREN);
	
	new Float:vVel[3] = {0.0, 0.0, 0.0};
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	return Plugin_Continue;
}
#endif

stock FreezeSilent(client, Float:time)
{
	SetEntityMoveType(client, MOVETYPE_NONE);
	CreateTimer(time, Timer_FreezeSilent, GetClientUserId(client));
}

public Action:Timer_FreezeSilent(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	new Float:vVel[3] = {0.0, 0.0, 0.0};
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
	SetEntityMoveType(client, MOVETYPE_WALK);
	
	return Plugin_Continue;
}

public Action:Timer_PreventInvalidMovSpam(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!client) return Plugin_Continue;
	g_bPreventInvalidMovSpam[client] = false;
	return Plugin_Continue;
}

public Action:SM_StartRecord(args)
{
	if (args < 1) return Plugin_Handled;
	
	decl String:sUserID[16];
	GetCmdArgString(sUserID, sizeof(sUserID));
	
	new client = GetClientOfUserId(StringToInt(sUserID));
	if (!client) return Plugin_Handled;
	
	g_TimerTotalSync[client] = 0;
	g_TimerGoodSync[client] = 0;
	g_TimerTotalSyncSW[client] = 0;
	g_TimerGoodSyncSW[client] = 0;
	g_TimerTotalSyncHSW[client] = 0;
	g_TimerGoodSyncHSW[client] = 0;
	g_TotalStrafes[client] = 0;
	g_GoodStrafes[client] = 0;
	g_PerfectStrafes[client] = 0;
	
	return Plugin_Handled;
}

public Action:SM_GetSync(args)
{
	if (args < 1) return Plugin_Handled;
	
	decl String:sUserID[16], String:sStyle[8], String:sSync[8];
	GetCmdArg(1, sUserID, sizeof(sUserID));
	GetCmdArg(2, sStyle, sizeof(sStyle));
	
	new client = GetClientOfUserId(StringToInt(sUserID));
	if (!client) return Plugin_Handled;
	new style = StringToInt(sStyle);
	
	switch (style)
	{
		case 1: // Forwards
		{
			new Float:fSync = GetClientTimerSync(client);
			FloatToString(fSync, sSync, sizeof(sSync));
			ServerCommand("sm_es_receivesync %s %.5s", sUserID, sSync);
		}
		case 2: // Sideways
		{
			new Float:fSync = GetClientTimerSyncSW(client);
			FloatToString(fSync, sSync, sizeof(sSync));
			ServerCommand("sm_es_receivesync %s %.5s", sUserID, sSync);
		}
		case 3: // Half-Sideways
		{
			new Float:fSync = GetClientTimerSyncHSW(client);
			FloatToString(fSync, sSync, sizeof(sSync));
			ServerCommand("sm_es_receivesync %s %.5s", sUserID, sSync);
		}
	}
	
	return Plugin_Handled;
}

stock Float:GetClientSync(client, syncNum)
{
	if (g_TotalSync[client] > 0)
		return float(g_GoodSync[client][syncNum]) / float(g_TotalSync[client]) * 100.0;
	return 0.0;
}

stock Float:GetClientSyncSW(client, syncNum)
{
	if (g_TotalSyncSW[client] > 0)
		return float(g_GoodSyncSW[client][syncNum]) / float(g_TotalSyncSW[client]) * 100.0;
	return 0.0;
}

stock Float:GetClientTimerSync(client)
{
	if (g_TimerTotalSync[client] > 0)
		return float(g_TimerGoodSync[client]) / float(g_TimerTotalSync[client]) * 100.0;
	return 0.0;
}

stock Float:GetClientTimerSyncSW(client)
{
	if (g_TimerTotalSyncSW[client] > 0)
		return float(g_TimerGoodSyncSW[client]) / float(g_TimerTotalSyncSW[client]) * 100.0;
	return 0.0;
}

stock Float:GetClientTimerSyncHSW(client)
{
	if (g_TimerTotalSyncHSW[client] > 0)
		return float(g_TimerGoodSyncHSW[client]) / float(g_TimerTotalSyncHSW[client]) * 100.0;
	return 0.0;
}

stock Float:GetClientStrafePerf(client)
{
	if (g_TotalStrafes[client] > 0)
		return float(g_PerfectStrafes[client]) / float(g_TotalStrafes[client]) * 100.0;
	return 0.0;
}

stock Float:GetClientGoodStrafePerf(client)
{
	if (g_TotalStrafes[client] > 0)
		return float(g_GoodStrafes[client]) / float(g_TotalStrafes[client]) * 100.0;
	return 0.0;
}

void LogSuspect(client, SuspectDetection:type, const String:reason[], pkc = 0, Float:fAngleDiff = 0.0)
{
	decl String:sBuffer[1024], String:sSteamID[192], String:sIP[17], Float:vClientOrigin[3];
	GetClientIP(client, sIP, sizeof(sIP), true);
	GetClientAuthId(client, AuthIdType:AuthId_Steam3, sSteamID, sizeof(sSteamID));
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", vClientOrigin);
	
	gH_Logger = OpenFile(g_sLogFile, "a+");
	FormatTime(sBuffer, sizeof(sBuffer), "%b %d |%H:%M:%S| %Y");
	Format(sBuffer, sizeof(sBuffer), "--------------------------------------------------\n%s\nName: %N\nSteamID: %s\nIP: %s\nMap: %s\nOrigin: %.2f %.2f %.2f\n%s\n", 
		sBuffer,
		client,
		sSteamID,
		sIP,
		g_sMapName,
		vClientOrigin[0],
		vClientOrigin[1],
		vClientOrigin[2],
		reason);
	
	if (type == ANGLEHACK)
		Format(sBuffer, sizeof(sBuffer), "%sY AngleDiff: %f\n", sBuffer, fAngleDiff);
	else
		Format(sBuffer, sizeof(sBuffer), "%sPKC: %i\n", sBuffer, pkc);
	
	WriteFileLine(gH_Logger, sBuffer);
	FlushFile(gH_Logger);
	CloseHandle(gH_Logger);
	
	// Skip any database queries if we're not connected to mysql.
	if (gH_Database == INVALID_HANDLE)
		return;
	
	FormatEx(sBuffer, sizeof(sBuffer), "%s", sSteamID);
	GetClientAuthId(client, AuthIdType:AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	Format(sSteamID, sizeof(sSteamID), "%s-%s", sBuffer, sSteamID);
	
	decl String:sClientName[64];
	GetClientName(client, sClientName, sizeof(sClientName));
	
	decl String:sClientSafeName[2 * strlen(sClientName) + 1];
	SQL_EscapeString(gH_Database, sClientName, sClientSafeName, 2 * strlen(sClientName) + 1);
	
	new now = GetTime();
	
	if (type < PERFECT_KEY_CHANGES_AD)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "INSERT INTO suspects (name, steamid, ip, timestamp, map, originX, originY, originZ, type, yanglediff, api_key) VALUES ('%s','%s','%s','%i','%s','%.2f','%.2f','%.2f','%i','%f','%s');", 
			sClientSafeName,
			sSteamID,
			sIP,
			now,
			g_sMapName,
			vClientOrigin[0],
			vClientOrigin[1],
			vClientOrigin[2],
			type,
			fAngleDiff,
			g_sAPIKey);
	}
	else
	{
		FormatEx(sBuffer, sizeof(sBuffer), "INSERT INTO suspects (name, steamid, ip, timestamp, map, originX, originY, originZ, type, pkc, api_key) VALUES ('%s','%s','%s','%i','%s','%.2f','%.2f','%.2f','%i','%i','%s');", 
			sClientSafeName,
			sSteamID,
			sIP,
			now,
			g_sMapName,
			vClientOrigin[0],
			vClientOrigin[1],
			vClientOrigin[2],
			type,
			pkc,
			g_sAPIKey);
	}
	SQL_TQuery(gH_Database, DB_Callback_Insert, sBuffer);
}

void LogCheater(client, CheatDetection:type, const String:reason[], Float:fSync1 = 0.0, Float:fSync2 = 0.0, Float:fSync3 = 0.0, mf = 0, mfp = 0, tf = 0, tfp = 0, mf1 = 0, mf2 = 0, tf1 = 0, tf2 = 0)
{
	decl String:sBuffer[1024], String:sSteamID[192], String:sIP[17], Float:vClientOrigin[3];
	GetClientIP(client, sIP, sizeof(sIP), true);
	GetClientAuthId(client, AuthIdType:AuthId_Steam3, sSteamID, sizeof(sSteamID));
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", vClientOrigin);
	
	gH_Logger = OpenFile(g_sLogFile, "a+");
	FormatTime(sBuffer, sizeof(sBuffer), "%b %d |%H:%M:%S| %Y");
	Format(sBuffer, sizeof(sBuffer), "--------------------------------------------------\n%s\nName: %N\nSteamID: %s\nIP: %s\nMap: %s\nOrigin: %.2f %.2f %.2f\n%s\n", 
		sBuffer,
		client,
		sSteamID,
		sIP,
		g_sMapName,
		vClientOrigin[0],
		vClientOrigin[1],
		vClientOrigin[2],
		reason);
	
	if (type == N_STRAFEHACK_20
	|| type == N_STRAFEHACK_40
	|| type == SW_STRAFEHACK_20
	|| type == SW_STRAFEHACK_40)
		Format(sBuffer, sizeof(sBuffer), "%sMF: %d MF2: %d MF1: %d MFP: %d\nTF: %d TF2: %d TF1: %d TFP: %d\nSync: %f %f %f\n", sBuffer, mf, mf2, mf1, mfp, tf, tf2, tf1, tfp, fSync1, fSync2, fSync3);
	
	WriteFileLine(gH_Logger, sBuffer);
	FlushFile(gH_Logger);
	CloseHandle(gH_Logger);
	
	// Skip any database queries if we're not connected to mysql.
	if (gH_Database == INVALID_HANDLE)
		return;
	
	FormatEx(sBuffer, sizeof(sBuffer), "%s", sSteamID);
	GetClientAuthId(client, AuthIdType:AuthId_SteamID64, sSteamID, sizeof(sSteamID));
	Format(sSteamID, sizeof(sSteamID), "%s-%s", sBuffer, sSteamID);
	
	decl String:sClientName[64];
	GetClientName(client, sClientName, sizeof(sClientName));
	
	decl String:sClientSafeName[2 * strlen(sClientName) + 1];
	SQL_EscapeString(gH_Database, sClientName, sClientSafeName, 2 * strlen(sClientName) + 1);
	
	new now = GetTime();
	
	if (type == N_STRAFEHACK_20
	|| type == N_STRAFEHACK_40
	|| type == SW_STRAFEHACK_20
	|| type == SW_STRAFEHACK_40)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "INSERT INTO stats (name, steamid, ip, timestamp, map, originX, originY, originZ, type, mf, mfp, tf, tfp, mf1, mf2, tf1, tf2, sync1, sync2, sync3, api_key) VALUES ('%s','%s','%s','%i','%s','%.2f','%.2f','%.2f','%i','%i','%i','%i','%i','%i','%i','%i','%i','%.2f','%.2f','%.2f','%s');", 
			sClientSafeName,
			sSteamID,
			sIP,
			now,
			g_sMapName,
			vClientOrigin[0],
			vClientOrigin[1],
			vClientOrigin[2],
			type,
			mf,
			mfp,
			tf,
			tfp,
			mf1,
			mf2,
			tf1,
			tf2,
			fSync1,
			fSync2,
			fSync3,
			g_sAPIKey);
	}
	else
	{
		FormatEx(sBuffer, sizeof(sBuffer), "INSERT INTO stats (name, steamid, ip, timestamp, map, originX, originY, originZ, type, api_key) VALUES ('%s','%s','%s','%i','%s','%.2f','%.2f','%.2f','%i','%s');", 
			sClientSafeName,
			sSteamID,
			sIP,
			now,
			g_sMapName,
			vClientOrigin[0],
			vClientOrigin[1],
			vClientOrigin[2],
			type,
			g_sAPIKey);
	}
	SQL_TQuery(gH_Database, DB_Callback_Insert, sBuffer);
	
	// sm_ban <#userid|name> <minutes|0> [reason]
	ServerCommand("sm_ban %i 0 %s", GetClientUserId(client), "Congratulations! You are now an official cheater. For more information: http://www.bhopultima.com/cheaters/");
}

void SQL_DBConnect()
{
	decl String:sDatabaseDriver[64];
	GetConVarString(gH_Cvar_Database_Driver, sDatabaseDriver, sizeof(sDatabaseDriver));
	
	if (SQL_CheckConfig(sDatabaseDriver))
	{
		if (gH_Database != INVALID_HANDLE)
		{
			CloseHandle(gH_Database);
			gH_Database = INVALID_HANDLE;
		}
		SQL_TConnect(DB_Callback_DBConnect, sDatabaseDriver);
	}
	else
	{
		PrintToServer("[ASH] Error: could not find database configuration \'%s\' at databases.cfg", sDatabaseDriver);
		LogError("[ASH] Error: could not find database configuration \'%s\' at databases.cfg", sDatabaseDriver);
		//SetFailState("[ASH] Error: could not find database configuration '%s' at databases.cfg", sDatabaseDriver);
	}
}

public DB_Callback_DBConnect(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		PrintToServer("[ASH] Database connection failure: %s", error);
		LogError("[ASH] Database connection failure: %s", error);
		//SetFailState("[ASH] Error while connecting to the database. Exiting.");
		return;
	}
	else
	{
		gH_Database = hndl;
		PrintToServer("[ASH] Database connection successful.");
	}
}

public DB_Callback_Insert(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		LogError("[ASH] Error on DB_Callback_Insert: %s", error);
		return;
	}
}

public Action:SM_AshDB(args)
{
	SQL_DBConnect();
	return Plugin_Handled;
}

public Action:SM_AshDebug(client, args)
{
	if (!client)
	{
		ReplyToCommand(client, "You cannot run this command through the server console.");
		return Plugin_Handled;
	}
	
	if (!IsAdmin(client))
	{
		SayText2(client, "\x01\x07FFFFFF[ASH] You are not authorized to run this command.");
		return Plugin_Handled;
	}
	
	AshDebugMenu(client, g_AdminMenuPage[client]);
	return Plugin_Handled;
}

void AshDebugMenu(client, page = 1)
{
	new Handle:panel = CreatePanel();
	SetPanelTitle(panel, "[ASH] Admin Debug Menu");
	//DrawPanelText(panel, " ");
	DrawPanelItem(panel, "Choose a player to debug");
	decl String:sText[256];
	new target = GetClientOfUserId(g_AdminSelectedUserID[client]);
	if (target)
	{
		FormatEx(sText, sizeof(sText), "Current player: %N", target);
		DrawPanelText(panel, sText);
	}
	DrawPanelText(panel, " ");
	switch (page)
	{
		case 1: // Forwards
		{
			DrawPanelText(panel, "Switches:");
			FormatEx(sText, sizeof(sText), "[%s] - Analysis", (g_bPrintAnalysis[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			FormatEx(sText, sizeof(sText), "[%s] - Strafes", (g_bDebugStrafes[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			FormatEx(sText, sizeof(sText), "[%s] - Sync", (g_bCheckSync[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			DrawPanelText(panel, " ");
			DrawPanelText(panel, "Executables:");
			DrawPanelItem(panel, "Analyse Current Strafes");
			DrawPanelItem(panel, "Print Sync");
			DrawPanelText(panel, " ");
			DrawPanelText(panel, "Section: Forwards");
			DrawPanelText(panel, "Page: 1/4");
			DrawPanelText(panel, " ");
			DrawPanelText(panel, " ");
			SetPanelCurrentKey(panel, 9);
			DrawPanelItem(panel, "Next");
			SetPanelCurrentKey(panel, 10);
			DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);
			SendPanelToClient(panel, client, AshDebugMenu_Page1, 0);
		}
		case 2: // Sideways
		{
			DrawPanelText(panel, "Switches:");
			FormatEx(sText, sizeof(sText), "[%s] - Analysis", (g_bPrintAnalysisSW[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			FormatEx(sText, sizeof(sText), "[%s] - Strafes", (g_bDebugStrafesSW[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			FormatEx(sText, sizeof(sText), "[%s] - Sync", (g_bCheckSyncSW[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			DrawPanelText(panel, " ");
			DrawPanelText(panel, "Executables:");
			DrawPanelItem(panel, "Analyse Current Strafes");
			DrawPanelItem(panel, "Print Sync");
			DrawPanelText(panel, " ");
			DrawPanelText(panel, "Section: Sideways");
			DrawPanelText(panel, "Page: 2/4");
			DrawPanelText(panel, " ");
			SetPanelCurrentKey(panel, 8);
			DrawPanelItem(panel, "Previous");
			SetPanelCurrentKey(panel, 9);
			DrawPanelItem(panel, "Next");
			SetPanelCurrentKey(panel, 10);
			DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);
			SendPanelToClient(panel, client, AshDebugMenu_Page2, 0);
		}
		case 3: // Keys
		{
			DrawPanelText(panel, "Switches:");
			FormatEx(sText, sizeof(sText), "[%s] - Holdtime |A/D|", (g_bDebugKeysHoldtimeAD[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			FormatEx(sText, sizeof(sText), "[%s] - Holdtime |W/S|", (g_bDebugKeysHoldtimeWS[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			DrawPanelText(panel, " ");
			DrawPanelText(panel, "Section: Keys");
			DrawPanelText(panel, "Page: 3/4");
			DrawPanelText(panel, " ");
			SetPanelCurrentKey(panel, 8);
			DrawPanelItem(panel, "Previous");
			SetPanelCurrentKey(panel, 9);
			DrawPanelItem(panel, "Next");
			SetPanelCurrentKey(panel, 10);
			DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);
			SendPanelToClient(panel, client, AshDebugMenu_Page3, 0);
		}
		case 4: // Advanced
		{
			DrawPanelText(panel, "Switches:");
			FormatEx(sText, sizeof(sText), "[%s] - Console Output", (g_bConsoleOutput[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			FormatEx(sText, sizeof(sText), "[%s] - Print Y AngleDiff >70", (g_bPrintAngleDiff[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			FormatEx(sText, sizeof(sText), "[%s] - Check Y AngleDiff", (g_bCheckAngleDiff[client]) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			FormatEx(sText, sizeof(sText), "[%s] - Strafe Perfection [F Only]", (gH_TimerTopMsg[client] != INVALID_HANDLE) ? "x" : "  ");
			DrawPanelItem(panel, sText);
			DrawPanelText(panel, " ");
			DrawPanelText(panel, "Section: Advanced");
			DrawPanelText(panel, "Page: 4/4");
			DrawPanelText(panel, " ");
			SetPanelCurrentKey(panel, 8);
			DrawPanelItem(panel, "Previous");
			DrawPanelText(panel, " ");
			SetPanelCurrentKey(panel, 10);
			DrawPanelItem(panel, "Exit", ITEMDRAW_CONTROL);
			SendPanelToClient(panel, client, AshDebugMenu_Page4, 0);
		}
	}
	CloseHandle(panel);
}

public AshDebugMenu_Page1(Handle:panel, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 1: // Choose a player to debug
				{
					SelectPlayer(param1);
				}
				case 2: // Print Analysis
				{
					g_bPrintAnalysis[param1] = !g_bPrintAnalysis[param1];
					g_bIsDebugOnAnalysis = IsDebugOnAnalysis();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 3: // Debug Strafes
				{
					g_bDebugStrafes[param1] = !g_bDebugStrafes[param1];
					g_bIsDebugOnStrafes = IsDebugOnStrafes();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 4: // Check Sync
				{
					g_bCheckSync[param1] = !g_bCheckSync[param1];
					if (g_bCheckSync[param1] && g_bCheckSyncSW[param1])
						g_bCheckSyncSW[param1] = false;
					g_bIsDebugOnSync = IsDebugOnSync();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 5: // Analyze Current Strafes
				{
					new target = GetClientOfUserId(g_AdminSelectedUserID[param1]);
					if (!target || !IsClientInGame(target))
					{
						SayText2(param1, "\x01\x07FFFFFF[ASH] The player you picked is not available.");
					}
					else
					{
						new movedFirstCount, turnedFirstCount;
						new movedFirstPerfect, turnedFirstPerfect;
						new movedFirst1, turnedFirst1;
						new movedFirst2, turnedFirst2;
						
						CountFrames(target, g_Frames, g_CurrentFrame[target], movedFirstCount, turnedFirstCount, movedFirstPerfect, turnedFirstPerfect, movedFirst1, turnedFirst1, movedFirst2, turnedFirst2);
						
						SayText2(param1, "\x01\x07FFFF00%d\x07FFFFFF Strafes Tick Difference Analysis", g_CurrentFrame[target]);
						SayText2(param1, "\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
						SayText2(param1, "\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
						SayText2(param1, "\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", GetClientSync(target, 0), GetClientSync(target, 1), GetClientSync(target, 2));
						SayText2(param1, "\x01\x07FFFFFFPlayer: \x0700FF08%N", target);
					}
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 6: // Print Sync
				{
					new target = GetClientOfUserId(g_AdminSelectedUserID[param1]);
					if (!target || !IsClientInGame(target))
					{
						SayText2(param1, "\x01\x07FFFFFF[ASH] The player you picked is not available.");
					}
					else
					{
						SayText2(param1, "\x01\x07FFFFFFF Sync at frame \x07FFFF00%d\x07FFFFFF:", g_CurrentFrame[target]);
						SayText2(param1, "\x01\x07FFFFFF#1: \x0700FF08%f", GetClientSync(target, 0));
						SayText2(param1, "\x01\x07FFFFFF#2: \x0700FF08%f", GetClientSync(target, 1));
						SayText2(param1, "\x01\x07FFFFFF#3: \x0700FF08%f", GetClientSync(target, 2));
						SayText2(param1, "\x01\x07FFFFFFPlayer: \x0700FF08%N", target);
					}
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 9: // Next page
				{
					++g_AdminMenuPage[param1];
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
			}
		}
	}
}

public AshDebugMenu_Page2(Handle:panel, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 1: // Choose a player to debug
				{
					SelectPlayer(param1);
				}
				case 2: // Print Analysis SW
				{
					g_bPrintAnalysisSW[param1] = !g_bPrintAnalysisSW[param1];
					g_bIsDebugOnAnalysisSW = IsDebugOnAnalysisSW();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 3: // Debug Strafes SW
				{
					g_bDebugStrafesSW[param1] = !g_bDebugStrafesSW[param1];
					g_bIsDebugOnStrafesSW = IsDebugOnStrafesSW();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 4: // Check Sync SW
				{
					g_bCheckSyncSW[param1] = !g_bCheckSyncSW[param1];
					if (g_bCheckSyncSW[param1] && g_bCheckSync[param1])
						g_bCheckSync[param1] = false;
					g_bIsDebugOnSync = IsDebugOnSync();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 5: // Analyze Current Strafes SW
				{
					new target = GetClientOfUserId(g_AdminSelectedUserID[param1]);
					if (!target || !IsClientInGame(target))
					{
						SayText2(param1, "\x01\x07FFFFFF[ASH] The player you picked is not available.");
					}
					else
					{
						new movedFirstCount, turnedFirstCount;
						new movedFirstPerfect, turnedFirstPerfect;
						new movedFirst1, turnedFirst1;
						new movedFirst2, turnedFirst2;
						
						CountFrames(target, g_FramesSW, g_CurrentFrameSW[target], movedFirstCount, turnedFirstCount, movedFirstPerfect, turnedFirstPerfect, movedFirst1, turnedFirst1, movedFirst2, turnedFirst2);
						
						SayText2(param1, "\x01\x07FFFF00%d\x07FFFFFF Strafes Tick Difference Analysis [Sideways]", g_CurrentFrameSW[target]);
						SayText2(param1, "\x01\x07FFFFFFMF:  \x0700FF08%d  \x07FFFFFFMF2:  \x0700FF08%d  \x07FFFFFFMF1:  \x0700FF08%d  \x07FFFFFFMFP:  \x0700FF08%d", movedFirstCount, movedFirst2, movedFirst1, movedFirstPerfect);
						SayText2(param1, "\x01\x07FFFFFFTF:  \x0700FF08%d  \x07FFFFFFTF2:  \x0700FF08%d  \x07FFFFFFTF1:  \x0700FF08%d  \x07FFFFFFTFP:  \x0700FF08%d", turnedFirstCount, turnedFirst2, turnedFirst1, turnedFirstPerfect);
						SayText2(param1, "\x01\x07FFFFFFSync:  \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f \x07FFFFFF| \x0700FF08%.2f", GetClientSyncSW(target, 0), GetClientSyncSW(target, 1), GetClientSyncSW(target, 2));
						SayText2(param1, "\x01\x07FFFFFFPlayer: \x0700FF08%N", target);
					}
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 6: // Print Sync SW
				{
					new target = GetClientOfUserId(g_AdminSelectedUserID[param1]);
					if (!target || !IsClientInGame(target))
					{
						SayText2(param1, "\x01\x07FFFFFF[ASH] The player you picked is not available.");
					}
					else
					{
						SayText2(param1, "\x01\x07FFFFFFS Sync at frame \x07FFFF00%d\x07FFFFFF:", g_CurrentFrameSW[target]);
						SayText2(param1, "\x01\x07FFFFFF#1: \x0700FF08%f", GetClientSyncSW(target, 0));
						SayText2(param1, "\x01\x07FFFFFF#2: \x0700FF08%f", GetClientSyncSW(target, 1));
						SayText2(param1, "\x01\x07FFFFFF#3: \x0700FF08%f", GetClientSyncSW(target, 2));
						SayText2(param1, "\x01\x07FFFFFFPlayer: \x0700FF08%N", target);
					}
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 8: // Previous page
				{
					--g_AdminMenuPage[param1];
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 9: // Next page
				{
					++g_AdminMenuPage[param1];
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
			}
		}
	}
}

public AshDebugMenu_Page3(Handle:panel, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 1: // Choose a player to debug
				{
					SelectPlayer(param1);
				}
				case 2: // Debug Holdtime [A/D]
				{
					g_bDebugKeysHoldtimeAD[param1] = !g_bDebugKeysHoldtimeAD[param1];
					g_bIsDebugOnKeysAD = IsDebugOnKeysAD();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 3: // Debug Holdtime [W/S]
				{
					g_bDebugKeysHoldtimeWS[param1] = !g_bDebugKeysHoldtimeWS[param1];
					g_bIsDebugOnKeysWS = IsDebugOnKeysWS();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 8: // Previous page
				{
					--g_AdminMenuPage[param1];
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 9: // Next page
				{
					++g_AdminMenuPage[param1];
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
			}
		}
	}
}

public AshDebugMenu_Page4(Handle:panel, MenuAction:action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (param2)
			{
				case 1: // Choose a player to debug
				{
					SelectPlayer(param1);
				}
				case 2: // Console Output
				{
					g_bConsoleOutput[param1] = !g_bConsoleOutput[param1];
					g_bIsDebugOnAdv = IsDebugOnAdv();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 3: // Print AngleDiff
				{
					g_bPrintAngleDiff[param1] = !g_bPrintAngleDiff[param1];
					g_bIsDebugOnAdv = IsDebugOnAdv();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 4: // Check AngleDiff
				{
					g_bCheckAngleDiff[param1] = !g_bCheckAngleDiff[param1];
					g_bIsDebugOnAdv = IsDebugOnAdv();
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 5: // Strafe Perfection [Forwards Only]
				{
					if (gH_TimerTopMsg[param1] != INVALID_HANDLE)
					{
						KillTimer(gH_TimerTopMsg[param1]);
						gH_TimerTopMsg[param1] = INVALID_HANDLE;
					}
					else
					{
						gH_TimerTopMsg[param1] = CreateTimer(11.1, Timer_TopMsg, param1, TIMER_REPEAT);
					}
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
				case 8: // Previous page
				{
					--g_AdminMenuPage[param1];
					AshDebugMenu(param1, g_AdminMenuPage[param1]);
				}
			}
		}
	}
}

void SelectPlayer(client)
{
	new Handle:menu = CreateMenu(SelectPlayer_Handler);
	SetMenuTitle(menu, "[ASH] Admin Debug Menu");
	decl userid, String:sBuffer[32], String:sName[64];
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		userid = GetClientUserId(i);
		IntToString(userid, sBuffer, sizeof(sBuffer));
		GetClientName(i, sName, sizeof(sName));
		AddMenuItem(menu, sBuffer, sName);
	}
	SetMenuOptionFlags(menu, MENUFLAG_BUTTON_EXIT|MENUFLAG_BUTTON_EXITBACK|MENUFLAG_NO_SOUND);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public SelectPlayer_Handler(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			AshDebugMenu(param1, g_AdminMenuPage[param1]);
		}
	}
	else if (action == MenuAction_Select)
	{
		decl String:sInfo[32];
		new userid, target;
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo));
		userid = StringToInt(sInfo);
		target = GetClientOfUserId(userid);
		
		if (!target || !IsClientInGame(target))
		{
			SayText2(param1, "\x01\x07FFFFFF[ASH] The player you picked is no longer available.");
		}
		else
		{
			g_AdminSelectedUserID[param1] = userid;
			AshDebugMenu(param1, g_AdminMenuPage[param1]);
		}
	}
}

bool:IsDebugOnAnalysis()
{
	for (new i = 1; i <= MaxClients; ++i)
		if (g_bPrintAnalysis[i]) return true;
	return false;
}

bool:IsDebugOnStrafes()
{
	for (new i = 1; i <= MaxClients; ++i)
		if (g_bDebugStrafes[i]) return true;
	return false;
}

bool:IsDebugOnAnalysisSW()
{
	for (new i = 1; i <= MaxClients; ++i)
		if (g_bPrintAnalysisSW[i]) return true;
	return false;
}

bool:IsDebugOnStrafesSW()
{
	for (new i = 1; i <= MaxClients; ++i)
		if (g_bDebugStrafesSW[i]) return true;
	return false;
}

bool:IsDebugOnSync()
{
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (g_bCheckSync[i]) return true;
		if (g_bCheckSyncSW[i]) return true;
	}
	return false;
}

bool:IsDebugOnKeysAD()
{
	for (new i = 1; i <= MaxClients; ++i)
		if (g_bDebugKeysHoldtimeAD[i]) return true;
	return false;
}

bool:IsDebugOnKeysWS()
{
	for (new i = 1; i <= MaxClients; ++i)
		if (g_bDebugKeysHoldtimeWS[i]) return true;
	return false;
}

bool:IsDebugOnAdv()
{
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (g_bConsoleOutput[i]) return true;
		if (g_bPrintAngleDiff[i]) return true;
		if (g_bCheckAngleDiff[i]) return true;
	}
	return false;
}

void DebugAdvanced(client, Float:fForwardMove, Float:fSideMove, Float:fAngleX, Float:fAngleY, Float:fAngleDiff, skippedFrames)
{
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i)) continue;
		if (g_bConsoleOutput[i])
		{
			new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
			if (target == client)
				PrintToConsole(i, "%N  FM: %.2f  SM: %.2f  AX: %.2f  AY: %.2f  AYDiff: %.2f", client, fForwardMove, fSideMove, fAngleX, fAngleY, fAngleDiff);
		}
		if (g_bPrintAngleDiff[i])
		{
			new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
			if (target == client)
			{
				if (fAngleDiff > 70.0 || fAngleDiff < -70.0)
				{
					if (skippedFrames)
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x07FFFFFFAngleDiff: \x07FFFF00%.3f \x07FFFFFF(Tele/Spawn | Skipped Frames: \x07FFFF00%d\x07FFFFFF/20)", client, fAngleDiff, (20 - skippedFrames));
					else
						SayText2(i, "\x01\x07FFFFFF[ASH] \x0700FF08%N \x07FFFFFFAngleDiff: \x07FFFF00%.3f", client, fAngleDiff);
				}
			}
		}
		if (g_bCheckAngleDiff[i])
		{
			new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
			if (target == client)
			{
				if (fAngleDiff > 0.0) // Left
					PrintCenterText(i, "< %f  ", fAngleDiff);
				else if (fAngleDiff < 0.0) // Right
					PrintCenterText(i, "  %f >", fAngleDiff);
				else
					PrintCenterText(i, "%f", fAngleDiff);
			}
		}
	}
}

void DebugSync(client)
{
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || IsFakeClient(i)) continue;
		if (g_bCheckSync[i])
		{
			new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
			if (target == client)
			{
				new Handle:sync = CreateHudSynchronizer();
				if (sync != INVALID_HANDLE)
				{
					SetHudTextParams(-1.0, -0.8, 0.1, 0, 127, 255, 255, 0, 0.0, 0.0, 0.0);
					ShowSyncHudText(i, sync, "F O R W A R D S\n%.2f | %.2f | %.2f", GetClientSync(client, 0), GetClientSync(client, 1), GetClientSync(client, 2));
					CloseHandle(sync);
				}
			}
			continue;
		}
		if (g_bCheckSyncSW[i])
		{
			new target = GetClientOfUserId(g_AdminSelectedUserID[i]);
			if (target == client)
			{
				new Handle:sync = CreateHudSynchronizer();
				if (sync != INVALID_HANDLE)
				{
					SetHudTextParams(-1.0, -0.8, 0.1, 0, 127, 255, 255, 0, 0.0, 0.0, 0.0);
					ShowSyncHudText(i, sync, "S I D E W A Y S\n%.2f | %.2f | %.2f", GetClientSyncSW(client, 0), GetClientSyncSW(client, 1), GetClientSyncSW(client, 2));
					CloseHandle(sync);
				}
			}
		}
	}
}

void HookTeleports()
{
	new index = -1;
	while ((index = FindEntityByClassname(index, "trigger_teleport")) != -1)
	{
		HookSingleEntityOutput(index, "OnStartTouch", Teleport_OnStartTouch);
	}
}

public Teleport_OnStartTouch(const String:output[], caller, activator, Float:delay)
{
	if (activator < 1 || activator > MaxClients || !IsClientInGame(activator) || !IsPlayerAlive(activator))
		return;
	
	g_bBlockAngleCheck[activator] = true;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_bBlockAngleCheck[client] = true;
}

public Action:Timer_TopMsg(Handle:timer, any:client)
{
	if (!IsClientInGame(client))
	{
		if (gH_TimerTopMsg[client] != INVALID_HANDLE)
		{
			gH_TimerTopMsg[client] = INVALID_HANDLE;
			return Plugin_Stop;
		}
	}
	
	if (!IsPlayerAlive(client))
	{
		new observerMode = GetEntProp(client, Prop_Data, "m_iObserverMode");
		new observerTarget = GetEntPropEnt(client, Prop_Data, "m_hObserverTarget");
		
		if ((observerMode == 4 || observerMode == 5) && !IsFakeClient(observerTarget))
		{
			new Handle:sync = CreateHudSynchronizer();
			if (sync != INVALID_HANDLE)
			{
				SetHudTextParams(0.95, -0.85, 10.0, 0, 255, 50, 255, 0, 6.0, 0.5, 0.5);
				ShowSyncHudText(client, sync, "%.2f", ((GetClientStrafePerf(observerTarget) + GetClientGoodStrafePerf(observerTarget)) / 2.0));
				CloseHandle(sync);
			}
		}
		return Plugin_Continue;
	}
	
	TopMessage(client, "%.2f", ((GetClientStrafePerf(client) + GetClientGoodStrafePerf(client)) / 2.0));
	return Plugin_Continue;
}

// ici is a sexy beast <3