// uncomment to enable auto for 1hops
// #define AUTOSCROLL

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shavit>
#if defined AUTOSCROLL
#include <dump_parser>
#endif

#pragma newdecls required
#pragma semicolon 1

#define SHAVIT_ACCOUNT 204506329
#define SPEEDKEEP_MISS1TICK 0.92

#if defined AUTOSCROLL
#define BHOPBLOCK_THRESHOLD 0.10

// patterns for 1hop blocks
char gS_Patterns[][] =
{
	"targetname xhop", // badg3s/apricity 1hops
	"targetname yhop", // badg3s 1hops
	"targetname zhop", // badg3s 1hops
	"filter_*,TestActivator" // tony's prefab
};

// kz_bhop maps with irregular naming
char gS_KZBhopMaps[][] =
{
	"apricity",
	"badges2",
	"yonkoma"
};

bool gB_KZMap = false;
ArrayList gA_QualifiedTriggers = null;
float gF_EngineTime = 0.0;
float gF_LastTouch[MAXPLAYERS+1];
Handle gH_HUD = null;
#endif

bool gB_FairscrollStyle[MAXPLAYERS+1];
bool gB_Debug[MAXPLAYERS+1];

bool gB_OnGround[MAXPLAYERS+1];
int gI_LandedAt[MAXPLAYERS+1];
bool gB_Jumped[MAXPLAYERS+1];
float gF_LandVelocity[MAXPLAYERS+1][3];

public Plugin myinfo =
{
	name = "[shavit] Fairscroll Style",
	author = "shavit",
	description = "Introduces the Fairscroll style. Less RNG-reliant scroll gaming experience.",
	version = SHAVIT_VERSION,
	url = "https://github.com/shavitush/bhoptimer"
}

public void OnPluginStart()
{
	#if defined AUTOSCROLL
	gH_HUD = CreateHudSynchronizer();
	gA_QualifiedTriggers = new ArrayList();
	#endif

	HookEvent("player_jump", Player_Jump);

	RegConsoleCmd("sm_fsdebug", Command_FSDebug);
}

public void OnClientPutInServer(int client)
{
	#if defined AUTOSCROLL
	gF_LastTouch[client] = 0.0;
	#endif

	gB_Debug[client] = false;
}

#if defined AUTOSCROLL
public void OnMapStart()
{
	gA_QualifiedTriggers.Clear();

	char sMap[64];
	GetCurrentMap(sMap, 64);
	GetMapDisplayName(sMap, sMap, 64);

	gB_KZMap = (StrContains(sMap, "kz_", false) != -1);

	for(int i = 0; i < sizeof(gS_KZBhopMaps); i++)
	{
		if(StrContains(sMap, gS_KZBhopMaps[i], false) != -1)
		{
			gB_KZMap = true;

			break;
		}
	}

	if(gB_KZMap)
	{
		CreateTimer(0.1, Timer_HUD, 0, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}
#endif

public void Player_Jump(Event event, const char[] name, bool dontBroadcast)
{
	gB_Jumped[GetClientOfUserId(GetEventInt(event, "userid"))] = true;
}

public Action Command_FSDebug(int client, int args)
{
	if(!IsShavit(client))
	{
		return Plugin_Continue;
	}

	gB_Debug[client] = !gB_Debug[client];
	ReplyToCommand(client, "fs debug %s", (gB_Debug[client])? "enabled":"disabled");

	return Plugin_Handled;
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
	char sSpecial[stylestrings_t::sSpecialString];
	Shavit_GetStyleStrings(newstyle, sSpecialString, sSpecial, stylestrings_t::sSpecialString);

	stylesettings_t aSettings;
	Shavit_GetStyleSettings(newstyle, aSettings);

	gB_FairscrollStyle[client] = (StrContains(sSpecial, "fairscroll", false) != -1 && !aSettings.bAutobhop);
}

#if defined AUTOSCROLL
public void OnEntityCreated(int entity, const char[] classname)
{
	if(gB_KZMap && StrEqual(classname, "trigger_multiple", false))
	{
		RequestFrame(Frame_HookTrigger, EntIndexToEntRef(entity));
	}
}

public void Frame_HookTrigger(any data)
{
	int entity = EntRefToEntIndex(data);

	if(entity == INVALID_ENT_REFERENCE || gA_QualifiedTriggers.FindValue(GetEntProp(entity, Prop_Data, "m_iHammerID")) == -1)
	{
		return;
	}

	SDKHook(entity, SDKHook_TouchPost, TouchPost_Trigger);
}

public void TouchPost_Trigger(int entity, int other)
{
	if(other < 1 || other > MaxClients || IsFakeClient(other))
	{
		return;
	}

	gF_LastTouch[other] = gF_EngineTime;
}

public void OnGameFrame()
{
	gF_EngineTime = GetEngineTime();
}

// -1 - incompatible style
// 0 - not on bhop blocks
// 1 - can
int CanAutoScroll(int client, float time = BHOPBLOCK_THRESHOLD)
{
	if(!gB_FairscrollStyle[client])
	{
		return -1;
	}

	if(gF_EngineTime - gF_LastTouch[client] > time)
	{
		return 0;
	}

	return 1;
}
#endif

// by danzay
void SetVectorHorizontalLength(float vec[3], float length)
{
	float newVec[3];
	newVec = vec;
	newVec[2] = 0.0;
	NormalizeVector(newVec, newVec);
	ScaleVector(newVec, length);
	newVec[2] = vec[2];
	vec = newVec;
}

void AddPerfectJump(int client)
{
	if(Shavit_GetTimerStatus(client) == Timer_Stopped)
	{
		return;
	}

	// HACK: instead of new native, just do this inside the snapshot
	timer_snapshot_t aSnapshot;
	Shavit_SaveSnapshot(client, aSnapshot);

	DebugPrint(client, "before %d after %d", aSnapshot.iPerfectJumps, (aSnapshot.iPerfectJumps + 1));

	aSnapshot.iPerfectJumps++;
	Shavit_LoadSnapshot(client, aSnapshot);
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if(!IsPlayerAlive(client) || IsFakeClient(client))
	{
		return Plugin_Continue;
	}

	MoveType mtMoveType = GetEntityMoveType(client);
	bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);

	#if defined AUTOSCROLL
	if(gB_KZMap &&
		CanAutoScroll(client) == 1 &&
		(buttons & IN_JUMP) > 0 &&
		mtMoveType == MOVETYPE_WALK &&
		!bInWater)
	{
		
		int iOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
		SetEntProp(client, Prop_Data, "m_nOldButtons", (iOldButtons & ~IN_JUMP));
	}
	#endif

	if(gB_FairscrollStyle[client])
	{
		int iTicks = GetGameTickCount();
		bool bOnGround = ((GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") != -1) && mtMoveType == MOVETYPE_WALK && !bInWater);

		if(bOnGround && !gB_OnGround[client])
		{
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", gF_LandVelocity[client]);

			gI_LandedAt[client] = iTicks;
		}

		// 1 mistimed tick
		else if(!bOnGround && gB_OnGround[client] && gB_Jumped[client] && iTicks - gI_LandedAt[client] == 2)
		{
			float fVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);

			float fBaseVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", fBaseVelocity);

			float fAdjustedVelocity[3];
			fAdjustedVelocity = gF_LandVelocity[client];
			fAdjustedVelocity[2] = fVelocity[2];
			SetVectorHorizontalLength(fAdjustedVelocity, SquareRoot(Pow(gF_LandVelocity[client][0], 2.0) + Pow(gF_LandVelocity[client][1], 2.0)) * SPEEDKEEP_MISS1TICK);
			AddVectors(fAdjustedVelocity, fBaseVelocity, fAdjustedVelocity);

			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, fAdjustedVelocity);
			AddPerfectJump(client);

			DebugPrint(client, "fixed jump");
		}

		gB_OnGround[client] = bOnGround;
		gB_Jumped[client] = false;
	}

	return Plugin_Continue;
}

bool IsShavit(int client)
{
	return (GetSteamAccountID(client) == SHAVIT_ACCOUNT);
}

void DebugPrint(int client, const char[] message, any ...)
{
	if(!IsShavit(client) || !gB_Debug[client])
	{
		return;
	}

	char buffer[300];
	SetGlobalTransTarget(client);
	VFormat(buffer, 300, message, 3);
	Shavit_PrintToChat(client, "[fairscroll debug] %s", buffer);
}

#if defined AUTOSCROLL
int GetHUDTarget(int client)
{
	int target = client;

	if(IsClientObserver(client))
	{
		int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

		if(iObserverMode >= 3 && iObserverMode <= 5)
		{
			int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

			if(IsValidClient(iTarget, true))
			{
				target = iTarget;
			}
		}
	}

	return target;
}

public Action Timer_HUD(Handle timer)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			int iTarget = GetHUDTarget(i);

			if(IsPlayerAlive(iTarget))
			{
				int iCanScroll = CanAutoScroll(iTarget, 0.6);

				if(iCanScroll == 1)
				{
					SetHudTextParams(-1.0, 0.90, 2.5, 0, 255, 0, 255, 0, 0.0, 0.0, 0.0);
					ShowSyncHudText(i, gH_HUD, "Autoscroll enabled");
				}

				else if(iCanScroll == 0)
				{
					SetHudTextParams(-1.0, 0.90, 2.5, 255, 0, 0, 255, 0, 0.0, 0.0, 0.0);
					ShowSyncHudText(i, gH_HUD, "-");
				}
			}
		}
	}
}

public void OnDumpFileProcessed()
{
	if(!gB_KZMap)
	{
		return;
	}

	int iEntity = -1;
	char sOutputs[1024];

	while((iEntity = FindEntityByClassname(iEntity, "trigger_multiple")) != -1)
	{
		Entity pEnt;
		GetDumpEntity(iEntity, pEnt);

		if(pEnt.OutputList != null)
		{
			pEnt.ToString(sOutputs, 1024);
			
			for(int i = 0; i < sizeof(gS_Patterns); i++)
			{
				if(StrContains(sOutputs, gS_Patterns[i], false) != -1)
				{
					gA_QualifiedTriggers.Push(StringToInt(pEnt.HammerID));

					break;
				}
			}
		}
	}

	if(gA_QualifiedTriggers.Length > 0)
	{
		FindConVar("mp_restartgame").IntValue = 1;
	}
}
#endif
