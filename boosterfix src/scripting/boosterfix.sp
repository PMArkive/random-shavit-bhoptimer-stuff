#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <outputinfo>

//#define DEBUG
#define VERSION "0.9.1"

#define TICKS(%1) RoundFloat((%1) / GetTickInterval())
#define EXPAND_VECTOR(%1) %1[0], %1[1], %1[2]
#define VECTOR_OP(%1) for(new v = 0; v < 3; v++) { %1; }
#define VECTOR_OP_XY(%1) for(new v = 0; v < 2; v++) { %1; }
#define FLT_MAX 3.402823466e38

#define MAX_BOOSTERS 128
#define MAX_SINGLE_TRIGGERS 1024

enum ActivationType
{
	AT_Unknown = 0, 
	AT_Touch, 
	AT_Damage, 
}

new bool:g_bLateLoad = false;

new bool:g_bPushFix[MAXPLAYERS + 1] =  { true, ... };

new g_iPushCount = 0;
new g_iPush[MAX_BOOSTERS];
new String:g_sPushFilter[MAX_BOOSTERS][32];
new Float:g_fPushScale[MAX_BOOSTERS];
new Float:g_vPushDir[MAX_BOOSTERS][3];

new g_iTriggerCount = 0;
new g_iTrigger[MAX_BOOSTERS];
new String:g_sTriggerFilter[MAX_BOOSTERS][32];
new Float:g_fTriggerStartDelay[MAX_BOOSTERS];
new Float:g_fTriggerDelay[MAX_BOOSTERS];
new ActivationType:g_TriggerType[MAX_BOOSTERS] =  { AT_Unknown, ... };

new g_iSingleTriggerCount = 0;
new g_iSingleTrigger[MAX_SINGLE_TRIGGERS];
new String:g_sSingleTriggerFilter[MAX_SINGLE_TRIGGERS][32];
new Float:g_fSingleTriggerStartDelay[MAX_SINGLE_TRIGGERS];

new g_iGravityCount = 0;
new g_iGravity[MAX_BOOSTERS];
new Float:g_fGravityValue[MAX_BOOSTERS];
new Float:g_fGravityStartDelay[MAX_BOOSTERS];
new Float:g_fGravityDelay[MAX_BOOSTERS];
new ActivationType:g_GravityType[MAX_BOOSTERS] =  { AT_Unknown, ... };

new g_iFuncDoorCount = 0;
new g_iFuncDoor[MAX_BOOSTERS];
new Float:g_fFuncDoorSpeed[MAX_BOOSTERS];

new Float:g_fStartTime[MAXPLAYERS + 1] =  { 0.0, ... };
new Float:g_fEndTime[MAXPLAYERS + 1] =  { 0.0, ... };
new g_iCurTrigger[MAXPLAYERS + 1] =  { -1, ... };
new g_bCurTriggerHasPushed[MAXPLAYERS + 1] =  { false, ... };

new Float:g_fStartTimeGravity[MAXPLAYERS + 1] =  { 0.0, ... };
new Float:g_fEndTimeGravity[MAXPLAYERS + 1] =  { 0.0, ... };
new g_iCurGravity[MAXPLAYERS + 1] =  { -1, ... };

new Float:g_fStartTimeFuncDoor[MAXPLAYERS + 1] =  { 0.0, ... };
new g_iCurFuncDoor[MAXPLAYERS + 1] =  { -1, ... };

new g_iBasevelCount = 0;
new g_iBasevel[MAX_BOOSTERS];
new Float:g_vBasevelPush[MAX_BOOSTERS][3];
new Float:g_fBasevelStartDelay[MAX_BOOSTERS] =  { 0.0, ... };

new Float:g_fStartTimeBasevel[MAXPLAYERS + 1] =  { 0.0, ... };
new g_iCurBasevel[MAXPLAYERS + 1] =  { -1, ... };

new String:g_sCurrentMap[64];

new bool:g_bTraceShot = false;

new Handle:g_hTraceShot = INVALID_HANDLE;

new bool:g_bDesync = false;

public Plugin:myinfo = 
{
	name = "Booster fix", 
	author = "Miu & George, the best CSS mapper ever tbh", 
	description = "", 
	version = VERSION, 
}

Handle:CreateCvar(String:strName[], String:strValue[], flags = 0)
{
	new Handle:hCvar = CreateConVar(strName, strValue, "", flags);
	HookConVarChange(hCvar, OnCvarChange);
	
	return hCvar;
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	g_bLateLoad = late;
}

public OnPluginStart()
{
	CreateConVar("mboosterfix_version", VERSION, "boosterfix version", FCVAR_PLUGIN | FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("bullet_impact", Event_BulletImpact);
	
	RegConsoleCmd("sm_boosterfix", Command_PushFix);
	RegConsoleCmd("sm_pushfix", Command_PushFix);
	RegConsoleCmd("sm_boosterfixver", Command_Version);
	RegConsoleCmd("sm_bfver", Command_Version);
	
	RegConsoleCmd("sm_bflist", Command_List);
	
	g_hTraceShot = CreateCvar("sm_boosterfix_traceshot", "0", FCVAR_REPLICATED | FCVAR_NOTIFY);
	
	if (g_bLateLoad)
	{
		Init();
		
		/*for (new i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				OnClientPutInServer(i);
			}
		}*/
		
		//g_bTraceShot = GetConVarBool(g_hTraceShot);
	}
	
	#if defined DEBUG
	RegConsoleCmd("sm_init", Command_Init);
	#endif
}

#define ON_CVAR_CHANGE_BOOL(%0,%1) if(hCvar == %0) { %1 = bool:StringToInt(strNewValue); }

public OnCvarChange(Handle:hCvar, const String:strOldValue[], const String:strNewValue[])
{
	ON_CVAR_CHANGE_BOOL(g_hTraceShot, g_bTraceShot)
}

public Action:Command_PushFix(client, args)
{
	g_bPushFix[client] = !g_bPushFix[client];
	PrintToChat(client, "Booster fix is now %s", g_bPushFix[client]?"ENABLED":"DISABLED");
	
	return Plugin_Handled;
}

public Action:Command_Version(client, args)
{
	PrintToChat(client, "Booster fix %s by Miu -w-", VERSION);
	
	return Plugin_Handled;
}

public OnClientPutInServer(client)
{
	g_bPushFix[client] = true;
}

HookPushes()
{
	new ent = -1;
	decl String:filter[32], filterent;
	
	while ((ent = FindEntityByClassname(ent, "trigger_push")) != -1)
	{
		GetEntPropVector(ent, Prop_Data, "m_vecPushDir", g_vPushDir[g_iPushCount]);
		g_fPushScale[g_iPushCount] = GetEntPropFloat(ent, Prop_Data, "m_flSpeed");
		
		GetEntPropString(ent, Prop_Data, "m_iFilterName", filter, sizeof(filter));
		filterent = Entity_FindByName(filter, "filter_activator_name");
		
		new Float:vAngles[3];
		GetEntPropVector(ent, Prop_Data, "m_angRotation", vAngles);
		
		if (vAngles[0] || vAngles[1] || vAngles[2])
		{
			RotatePoint(g_vPushDir[g_iPushCount], g_vPushDir[g_iPushCount], vAngles);
			
			#if defined DEBUG
			PrintToServer("Has angle, rotating pushdir by %f, %f, %f", EXPAND_VECTOR(vAngles));
			#endif
		}
		
		if (filterent == INVALID_ENT_REFERENCE)
		{
			#if defined DEBUG
			PrintToServer("No filter entity found for trigger_push hammerid %d, skipping", GetEntProp(ent, Prop_Data, "m_iHammerID"));
			#endif
			
			continue;
		}
		
		GetEntPropString(filterent, Prop_Data, "m_iFilterName", filter, sizeof(filter));
		g_sPushFilter[g_iPushCount] = filter;
		
		g_iPush[g_iPushCount] = ent;
		
		SDKHook(ent, SDKHook_Touch, OnTouchPush);
		
		#if defined DEBUG
		PrintToServer("-- trigger_push HammerID %d --", GetHammerID(ent));
		PrintToServer("g_fPushScale[%d]: %f", g_iPushCount, g_fPushScale[g_iPushCount]);
		PrintToServer("g_vPushDir[%d]: %f, %f, %f", g_iPushCount, g_vPushDir[g_iPushCount][0], g_vPushDir[g_iPushCount][1], g_vPushDir[g_iPushCount][2]);
		PrintToServer("g_sPushFilter[%d]: %s", g_iPushCount, g_sPushFilter[g_iPushCount]);
		PrintToServer("");
		#endif
		
		if (++g_iPushCount >= MAX_BOOSTERS)
		{
			if (FindEntityByClassname(ent, "trigger_push") != -1)
			{
				LogError("Too many trigger_push boosters");
			}
			
			break;
		}
	}
}

HookTriggers(const String:sClassname[], const String:sOutput[])
{
	decl String:sPropOutput[32];
	FormatEx(sPropOutput, sizeof(sPropOutput), "m_%s", sOutput);
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, sClassname)) != -1)
	{
		new Count = GetOutputCount(ent, sPropOutput);
		
		new bool:bDoubleBreak = false;
		for (new i = 0; i < Count && !bDoubleBreak; i++)
		{
			decl String:sParameter[64];
			GetOutputParameter(ent, sPropOutput, i, sParameter);
			
			for (new j = 0; j < g_iPushCount && !bDoubleBreak; j++)
			{
				decl String:sCompare[64];
				FormatEx(sCompare, sizeof(sCompare), "targetname %s", g_sPushFilter[j]);
				
				if (StrEqual(sParameter, sCompare))
				{
					if (g_iTriggerCount >= MAX_BOOSTERS)
					{
						LogError("Too many triggers");
						
						return;
					}
					
					new bool:bFound = false;
					
					for (new k = 0; k < Count; k++)
					{
						decl String:sParameter2[64];
						GetOutputParameter(ent, sPropOutput, k, sParameter2);
						
						if (StrContains(sParameter2, "targetname ") != -1 && !StrEqual(sParameter2, sCompare))
						{
							g_iTrigger[g_iTriggerCount] = ent;
							strcopy(g_sTriggerFilter[g_iTriggerCount], sizeof(g_sTriggerFilter[]), g_sPushFilter[j]);
							g_fTriggerDelay[g_iTriggerCount] = GetOutputDelay(ent, sPropOutput, k);
							g_fTriggerStartDelay[g_iTriggerCount] = GetOutputDelay(ent, sPropOutput, i);
							
							if (StrEqual(sClassname, "trigger_multiple"))
							{
								g_TriggerType[g_iTriggerCount] = AT_Touch;
							}
							else if (StrEqual(sClassname, "func_button") || StrEqual(sClassname, "func_physbox"))
							{
								g_TriggerType[g_iTriggerCount] = AT_Damage;
							}
							
							g_iTriggerCount++;
							
							bFound = true;
							
							#if defined DEBUG
							new Float:origin[3];
							GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);
							PrintToServer("Initialized trigger %d filter %s hammerid %d type %s origin %f, %f, %f -- %f, %f", g_iTriggerCount - 1, g_sTriggerFilter[g_iTriggerCount - 1], GetHammerID(ent), sClassname, EXPAND_VECTOR(origin), g_fTriggerDelay[g_iTriggerCount - 1], g_fTriggerStartDelay[g_iTriggerCount - 1]);
							#endif
							
							break;
						}
					}
					
					if (bFound)
					{
						if (StrEqual(sClassname, "trigger_multiple"))
						{
							HookSingleEntityOutput(ent, sOutput, OnTrigger);
						}
					}
					/*else
					{
						#if defined DEBUG
						PrintToServer("Trigger hammerid %d sets push targetname %s but doesn't reset, skipping", GetEntProp(ent, Prop_Data, "m_iHammerID"), g_sPushFilter[j]);
						#endif
					}*/
					
					bDoubleBreak = true;
				}
			}
		}
	}
}

HookSingleTriggers(const String:sClassname[], const String:sOutput[])
{
	decl String:sPropOutput[32];
	FormatEx(sPropOutput, sizeof(sPropOutput), "m_%s", sOutput);
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, sClassname)) != -1)
	{
		new Count = GetOutputCount(ent, sPropOutput);
		
		new bool:bDoubleBreak = false;
		new bool:bFound = false;
		new bool:bContinue = false;
		
		decl String:sFilter[32];
		new Float:fDelay;
		
		for (new i = 0; i < Count && !bDoubleBreak; i++)
		{
			decl String:sParameter[64];
			GetOutputParameter(ent, sPropOutput, i, sParameter);
			
			if (StrContains(sParameter, "targetname ") != -1)
			{
				if (g_iSingleTriggerCount >= MAX_SINGLE_TRIGGERS)
				{
					LogError("Too many single triggers");
					
					return;
				}
				
				if (bFound)
				{
					bContinue = true;
					break;
				}
				
				for (new j = 0; j < strlen(sParameter) - strlen("targetname ") + 1; j++)
				{
					sFilter[j] = sParameter[j + strlen("targetname ")];
				}
				
				/*if(StrEqual(sFilter, "default")) // doesn't check for other default filternames
				{
					fDelay = GetOutputDelay(ent, sPropOutput, i);
					bFound = true;
				}
				
				for (new j = 0; j < g_iPushCount; j++)
				{
					if(StrEqual(sFilter, g_sPushFilter[j]))
					{
						fDelay = GetOutputDelay(ent, sPropOutput, i);
						bFound = true;
					}
				}*/
				
				fDelay = GetOutputDelay(ent, sPropOutput, i);
				bFound = true;
			}
		}
		
		if (bContinue || !bFound)
		{
			continue;
		}
		
		g_iSingleTrigger[g_iSingleTriggerCount] = ent;
		g_fSingleTriggerStartDelay[g_iSingleTriggerCount] = fDelay;
		strcopy(g_sSingleTriggerFilter[g_iSingleTriggerCount], sizeof(g_sSingleTriggerFilter[]), sFilter);
		g_iSingleTriggerCount++;
		
		HookSingleEntityOutput(ent, sOutput, OnTriggerSingle);
		
		#if defined DEBUG
		new Float:origin[3];
		GetOrigin(ent, origin);
		PrintToServer("Initialized single trigger %d hammerid %d type %s filter %s origin %f, %f, %f -- %f", g_iSingleTriggerCount - 1, GetHammerID(ent), sClassname, sFilter, EXPAND_VECTOR(origin), g_fSingleTriggerStartDelay[g_iSingleTriggerCount - 1]);
		#endif
	}
}

RemoveInactivatableBoosters()
{
	for (new i = 0; i < g_iPushCount; i++)
	{
		new bool:bFound = false;
		
		for (new j = 0; j < g_iTriggerCount; j++)
		{
			if (StrEqual(g_sPushFilter[i], g_sTriggerFilter[j]) && GetEntityDistance(g_iPush[i], g_iTrigger[j]) < 100.0)
			{
				bFound = true;
				
				break;
			}
		}
		
		if (!bFound)
		{
			#if defined DEBUG
			PrintToServer("Removing inactivatable booster %d hammerid %d", i, GetHammerID(g_iPush[i]));
			#endif
			
			g_iPush[i] = -1;
		}
	}
}

HookGravityBoosters(const String:sOutput[])
{
	decl String:sPropOutput[32];
	FormatEx(sPropOutput, sizeof(sPropOutput), "m_%s", sOutput);
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "trigger_multiple")) != -1)
	{
		new Count = GetOutputCount(ent, sPropOutput);
		
		new bool:bGravityFound = false, bool:bDefaultFound = false, Float:fGravity, Float:fGravityStartDelay, Float:fGravityDelay;
		
		for (new i = 0; i < Count; i++)
		{
			decl String:sParameter[64];
			GetOutputParameter(ent, sPropOutput, i, sParameter);
			
			if (StrContains(sParameter, "gravity ") != -1 && StrContains(sParameter, "gravity 1") == -1)
			{
				decl String:sGravity[16];
				for (new j = 0; j < strlen(sParameter) - strlen("gravity ") + 1; j++)
				{
					sGravity[j] = sParameter[j + strlen("gravity ")];
				}
				bGravityFound = true;
				fGravity = StringToFloat(sGravity);
				fGravityStartDelay = GetOutputDelay(ent, sPropOutput, i);
			}
			else if (StrContains(sParameter, "gravity 1") != -1)
			{
				fGravityDelay = GetOutputDelay(ent, sPropOutput, i);
				bDefaultFound = true;
			}
		}
		
		if (bGravityFound && bDefaultFound)
		{
			decl String:filter[32];
			GetEntPropString(ent, Prop_Data, "m_iFilterName", filter, sizeof(filter));
			
			if (filter[0] != 0)
			{
				#if defined DEBUG
				PrintToServer("Gravity hammerid %d has filter, skipping", GetEntProp(ent, Prop_Data, "m_iHammerID"));
				#endif
				
				continue;
			}
			
			if (g_iGravityCount >= MAX_BOOSTERS)
			{
				LogError("Too many gravity boosters");
				
				return;
			}
			
			g_iGravity[g_iGravityCount] = ent;
			g_fGravityValue[g_iGravityCount] = fGravity;
			g_fGravityStartDelay[g_iGravityCount] = fGravityStartDelay;
			g_fGravityDelay[g_iGravityCount] = fGravityDelay;
			g_GravityType[g_iGravityCount] = AT_Touch;
			
			g_iGravityCount++;
			
			if (StrEqual(sOutput, "OnStartTouch"))
			{
				SDKHook(ent, SDKHook_StartTouch, OnGenericTouchGravity);
			}
			else if (StrEqual(sOutput, "OnTouch"))
			{
				SDKHook(ent, SDKHook_Touch, OnGenericTouchGravity);
			}
			else if (StrEqual(sOutput, "OnEndTouch"))
			{
				SDKHook(ent, SDKHook_EndTouch, OnGenericTouchGravity);
			}
			else if (StrEqual(sOutput, "OnTrigger"))
			{
				SDKHook(ent, SDKHook_StartTouch, OnGenericTouchGravity);
			}
			else
			{
				LogError("Unrecognized output for gravity %d hammerid %d", g_iGravityCount - 1, GetHammerID(ent));
			}
			
			#if defined DEBUG
			PrintToServer("Initialized gravity %d hammerid %d -- %f, %f, %f", g_iGravityCount - 1, GetHammerID(ent), g_fGravityValue[g_iGravityCount - 1], g_fGravityStartDelay[g_iGravityCount - 1], g_fGravityDelay[g_iGravityCount - 1]);
			#endif
		}
	}
}

HookGravityDamageBoosters(const String:sClassname[])
{
	decl String:sPropOutput[32] = "m_OnDamaged";
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, sClassname)) != -1)
	{
		new Count = GetOutputCount(ent, sPropOutput);
		
		new bool:bGravityFound = false, bool:bDefaultFound = false, Float:fGravity, Float:fGravityStartDelay, Float:fGravityDelay;
		
		for (new i = 0; i < Count; i++)
		{
			decl String:sParameter[64];
			GetOutputParameter(ent, sPropOutput, i, sParameter);
			
			if (StrContains(sParameter, "gravity 1") != -1)
			{
				fGravityDelay = GetOutputDelay(ent, sPropOutput, i);
				bDefaultFound = true;
			}
			else if (StrContains(sParameter, "gravity ") != -1)
			{
				decl String:sGravity[16];
				for (new j = 0; j < strlen(sParameter) - strlen("gravity ") + 1; j++)
				{
					sGravity[j] = sParameter[j + strlen("gravity ")];
				}
				bGravityFound = true;
				fGravity = StringToFloat(sGravity);
				fGravityStartDelay = GetOutputDelay(ent, sPropOutput, i);
			}
		}
		
		if (bGravityFound && bDefaultFound)
		{
			if (g_iGravityCount >= MAX_BOOSTERS)
			{
				LogError("Too many gravity boosters");
				
				return;
			}
			
			g_iGravity[g_iGravityCount] = ent;
			g_fGravityValue[g_iGravityCount] = fGravity;
			g_fGravityStartDelay[g_iGravityCount] = fGravityStartDelay;
			g_fGravityDelay[g_iGravityCount] = fGravityDelay;
			g_GravityType[g_iGravityCount] = AT_Damage;
			
			g_iGravityCount++;
			
			SDKHook(ent, SDKHook_OnTakeDamage, OnDamagedGravity);
			
			#if defined DEBUG
			PrintToServer("Initialized damage gravity %d -- %f, %f, %f", g_iGravityCount, g_fGravityValue[g_iGravityCount - 1], g_fGravityStartDelay[g_iGravityCount - 1], g_fGravityDelay[g_iGravityCount - 1]);
			#endif
		}
	}
}

HookFuncDoors()
{
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "func_door")) != -1)
	{
		new Float:vPushDir[3];
		GetEntPropVector(ent, Prop_Data, "m_vecMoveDir", vPushDir);
		
		if (!(GetEntProp(ent, Prop_Data, "m_spawnflags") & 1024))
		{
			#if defined DEBUG
			PrintToServer("func_door hammerid %d not activated by touch, spawnflags %d, skipping", GetEntProp(ent, Prop_Data, "m_iHammerID"), GetEntProp(ent, Prop_Data, "m_spawnflags"));
			#endif
			
			continue;
		}
		
		if (!FloatEquals(vPushDir[2], 1.0))
		{
			continue;
		}
		
		if (GetEntPropFloat(ent, Prop_Data, "m_flWait") > 0.1)
		{
			#if defined DEBUG
			PrintToServer("func_door hammerid %d m_flWait over 0.1, skipping", GetEntProp(ent, Prop_Data, "m_iHammerID"));
			#endif
			
			continue;
		}
		
		g_iFuncDoor[g_iFuncDoorCount] = ent;
		g_fFuncDoorSpeed[g_iFuncDoorCount] = GetEntPropFloat(ent, Prop_Data, "m_flSpeed");
		
		SDKHook(ent, SDKHook_StartTouch, OnStartTouchFuncDoor);
		SDKHook(ent, SDKHook_Touch, OnTouchFuncDoor);
		
		#if defined DEBUG
		PrintToServer("g_fFuncDoorSpeed[%d]: %f", g_iFuncDoorCount, g_fFuncDoorSpeed[g_iFuncDoorCount]);
		#endif
		
		if (++g_iFuncDoorCount >= MAX_BOOSTERS)
		{
			if (FindEntityByClassname(ent, "func_door") != -1)
			{
				LogError("Too many func_door boosters");
			}
			
			break;
		}
	}
}

HookBasevelBoosters(const String:sOutput[])
{
	decl String:sPropOutput[32];
	FormatEx(sPropOutput, sizeof(sPropOutput), "m_%s", sOutput);
	
	new ent = -1;
	while ((ent = FindEntityByClassname(ent, "trigger_multiple")) != -1)
	{
		new Count = GetOutputCount(ent, sPropOutput);
		
		for (new i = 0; i < Count; i++)
		{
			decl String:sParameter[64];
			GetOutputParameter(ent, sPropOutput, i, sParameter);
			
			if (StrContains(sParameter, "basevelocity ") != -1)
			{
				decl String:filter[32];
				GetEntPropString(ent, Prop_Data, "m_iFilterName", filter, sizeof(filter));
				if (filter[0] != 0)
				{
					#if defined DEBUG
					PrintToServer("Basevel hammerid %d has filter, skipping", GetEntProp(ent, Prop_Data, "m_iHammerID"));
					#endif
					
					continue;
				}
				
				decl String:split[4][64];
				ExplodeString(sParameter, " ", split, 4, sizeof(split[]));
				
				g_iBasevel[g_iBasevelCount] = ent;
				g_vBasevelPush[g_iBasevelCount][0] = StringToFloat(split[1]);
				g_vBasevelPush[g_iBasevelCount][1] = StringToFloat(split[2]);
				g_vBasevelPush[g_iBasevelCount][2] = StringToFloat(split[3]);
				g_fBasevelStartDelay[g_iBasevelCount] = GetOutputDelay(ent, sPropOutput, i);
				
				if (StrEqual(g_sCurrentMap, "bhop_null_fix"))
				{
					new hammerid = GetEntProp(ent, Prop_Data, "m_iHammerID");
					
					if (hammerid == 742003 || hammerid == 741853 || hammerid == 741871 || hammerid == 741877)
					{
						g_vBasevelPush[g_iBasevelCount][0] *= 3;
						g_vBasevelPush[g_iBasevelCount][1] *= 3;
						g_vBasevelPush[g_iBasevelCount][2] *= 3;
					}
					else
					{
						g_vBasevelPush[g_iBasevelCount][0] *= 2;
						g_vBasevelPush[g_iBasevelCount][1] *= 2;
						g_vBasevelPush[g_iBasevelCount][2] *= 2;
					}
				}
				
				g_iBasevelCount++;
				
				SDKHook(ent, SDKHook_StartTouch, OnStartTouchBasevel);
				SDKHook(ent, SDKHook_Touch, OnTouchBasevel);
				
				#if defined DEBUG
				new hammerid = GetHammerID(ent);
				PrintToServer("-- Basevel booster %d hammerid %d --", g_iBasevelCount - 1, GetHammerID(ent));
				PrintToServer("Push: %f, %f, %f%s", EXPAND_VECTOR(g_vBasevelPush[g_iBasevelCount - 1]), StrEqual(g_sCurrentMap, "bhop_null_fix")?hammerid == 742003 || hammerid == 741853 || hammerid == 741871 || hammerid == 741877?" (3x)":" (2x)":"");
				PrintToServer("Start delay: %f", g_fBasevelStartDelay[g_iBasevelCount - 1]);
				PrintToServer("");
				#endif
				
				break;
			}
		}
	}
}

Init()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));
	
	if(StrEqual(g_sCurrentMap, "bhop_island_sr"))
	{
		g_bDesync = true;
	}
	else
	{
		g_bDesync = false;
	}
	
	g_iPushCount = 0;
	g_iTriggerCount = 0;
	g_iGravityCount = 0;
	g_iFuncDoorCount = 0;
	g_iBasevelCount = 0;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		g_fStartTime[i] = 0.0;
		g_fEndTime[i] = 0.0;
		g_iCurTrigger[i] = -1;
		g_bCurTriggerHasPushed[i] = false;
		g_fStartTimeGravity[i] = 0.0;
		g_fEndTimeGravity[i] = 0.0;
		g_iCurGravity[i] = -1;
		g_fStartTimeBasevel[i] = 0.0;
		g_iCurBasevel[i] = -1;
	}
	
	HookPushes();
	
	HookTriggers("trigger_multiple", "OnTrigger");
	HookTriggers("trigger_multiple", "OnStartTouch");
	HookTriggers("trigger_multiple", "OnTouching");
	HookTriggers("trigger_multiple", "OnEndTouch");
	
	HookTriggers("func_button", "OnDamaged");
	HookTriggers("func_physbox", "OnDamaged");
	HookTriggers("func_physbox_multiplayer", "OnDamaged");
	
	HookSingleTriggers("trigger_multiple", "OnTrigger");
	HookSingleTriggers("trigger_multiple", "OnStartTouch");
	HookSingleTriggers("trigger_multiple", "OnTouching");
	HookSingleTriggers("trigger_multiple", "OnEndTouch");
	HookSingleTriggers("func_button", "OnPressed");
	
	// This is a fix for maps like kz_bhop_yonkoma where the trigger work is different from the current method of finding them
	RemoveInactivatableBoosters();
	
	HookGravityBoosters("OnTrigger");
	HookGravityBoosters("OnStartTouch");
	HookGravityBoosters("OnEndTouch");
	
	HookGravityDamageBoosters("func_button");
	HookGravityDamageBoosters("func_physbox");
	HookGravityDamageBoosters("func_physbox_multiplayer");
	
	HookFuncDoors();
	
	HookBasevelBoosters("OnTrigger");
	HookBasevelBoosters("OnStartTouch");
	HookBasevelBoosters("OnTouching");
	HookBasevelBoosters("OnEndTouch");
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	Init();
}

CheckHit(client, const Float:vEye[3], const Float:vImpact[3])
{
	for (new i = 0; i < g_iTriggerCount; i++)
	{
		if (g_TriggerType[i] != AT_Damage)
		{
			continue;
		}
		
		new Float:mins[3], Float:maxs[3];
		GetAbsBoundingBox(g_iTrigger[i], mins, maxs);
		if (CheckLineBox(mins, maxs, vEye, vImpact))
		{
			OnTrigger("OnDamaged", g_iTrigger[i], client, 0.0);
		}
	}
	
	for (new i = 0; i < g_iGravityCount; i++)
	{
		if (g_GravityType[i] != AT_Damage)
		{
			continue;
		}
		
		new Float:mins[3], Float:maxs[3];
		GetAbsBoundingBox(g_iGravity[i], mins, maxs);
		if (CheckLineBox(mins, maxs, vEye, vImpact))
		{
			OnTriggerGravity("OnDamaged", g_iGravity[i], client, 0.0);
		}
	}
}

public Event_BulletImpact(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new Float:vEye[3], Float:vImpact[3];
	vImpact[0] = GetEventFloat(event, "x");
	vImpact[1] = GetEventFloat(event, "y");
	vImpact[2] = GetEventFloat(event, "z");
	GetClientEyePosition(client, vEye);
	
	if (!g_bTraceShot)
	{
		CheckHit(client, vEye, vImpact);
	}
}

AnglesToUV(Float:vOut[3], const Float:vAngles[3])
{
	vOut[0] = Cosine(vAngles[1] * FLOAT_PI / 180.0) * Cosine(vAngles[0] * FLOAT_PI / 180.0);
	vOut[1] = Sine(vAngles[1] * FLOAT_PI / 180.0) * Cosine(vAngles[0] * FLOAT_PI / 180.0);
	vOut[2] = -Sine(vAngles[0] * FLOAT_PI / 180.0);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	static bool:bLastAttack[MAXPLAYERS + 1];
	
	new bool:bAttack = bool:(buttons & IN_ATTACK);
	
	if (g_bTraceShot && bAttack && !bLastAttack[client])
	{
		new Float:vEye[3];
		GetClientEyePosition(client, vEye);
		
		const Float:tracelength = 10000.0;
		
		new Float:vTrace[3], Float:vLineEnd[3], Float:vDir[3], Float:vAng[3];
		AnglesToUV(vDir, angles);
		vLineEnd[0] = vEye[0] + vDir[0] * tracelength;
		vLineEnd[1] = vEye[1] + vDir[1] * tracelength;
		vLineEnd[2] = vEye[2] + vDir[2] * tracelength;
		TraceRay2(vTrace, vEye, vLineEnd);
		
		/*#if defined DEBUG
		CreateBeamClient(client, vEye, vTrace);
		#endif*/
		
		CheckHit(client, vEye, vTrace);
		
		const vertices = 30;
		const polygons = 10;
		const Float:angle = 10.0;
		for (new i = 0; i < vertices; i++)
		{
			for (new j = 1; j < polygons + 1; j++)
			{
				vAng[0] = angles[0] + Cosine(2 * FLOAT_PI * i / (vertices - 1)) * j * angle / polygons;
				vAng[1] = angles[1] + Sine(2 * FLOAT_PI * i / (vertices - 1)) * j * angle / polygons;
				AnglesToUV(vDir, vAng);
				vLineEnd[0] = vEye[0] + vDir[0] * tracelength;
				vLineEnd[1] = vEye[1] + vDir[1] * tracelength;
				vLineEnd[2] = vEye[2] + vDir[2] * tracelength;
				TraceRay2(vTrace, vEye, vLineEnd);
				
				/*#if defined DEBUG
				if(j == polygons)
				{
					CreateBeamClient(client, vEye, vTrace);
				}
				#endif*/
				
				CheckHit(client, vEye, vTrace);
			}
		}
	}
	
	bLastAttack[client] = bAttack;
}

//
// Notes on timing:
//
// - GetGameTickCount() sometimes skips or duplicates ticks.
// - Maintaining a tick/time count in OnGameFrame has the same problem.
// - GetGameTime() accumulates very slight error over time.
// - GetGameTime() returns different times in different functions on certain maps.
//
// Rounding differences between times eliminates any possibility for error to accumulate, and having an internal time function that differentiates between maps is a poor fix for the desync issue.
//

new Float:g_fTime = 0.0;

Float:GetInternalTime()
{
	if (g_bDesync)
	{
		return g_fTime;
	}
	
	return GetGameTime();
}

bool:TimeIsWithin(Float:fStart, Float:fEnd)
{
	new Float:fTime = GetInternalTime();
	
	if (TICKS(fTime - fStart) < 0)
	{
		return false;
	}
	
	if (TICKS(fTime - fEnd) > 0 && fEnd != -1.0)
	{
		return false;
	}
	
	return true;
}

bool:TimeEquals(Float:f)
{
	new Float:fTime = GetInternalTime();
	
	return TICKS(fTime - f) == 0;
}

#if defined DEBUG
new g_nPushedTicks[MAXPLAYERS + 1] = 0;
new bool:g_bPushedThisJump[MAXPLAYERS + 1] = false;
#endif

public OnGameFrame()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			g_fTime = GetGameTime();
			new Float:fTime = GetInternalTime();
			
			if (TimeIsWithin(g_fStartTimeGravity[client], g_fEndTimeGravity[client]))
			{
				SetEntPropFloat(client, Prop_Data, "m_flGravity", g_fGravityValue[g_iCurGravity[client]]);
			}
			else if (TICKS(fTime - g_fEndTimeGravity[client]) == 1)
			{
				SetEntPropFloat(client, Prop_Data, "m_flGravity", 1.0);
			}
			
			if (TimeEquals(g_fStartTimeFuncDoor[client]))
			{
				AddVelocity2(client, 0.0, 0.0, g_fFuncDoorSpeed[g_iCurFuncDoor[client]]);
			}
			
			if (TimeEquals(g_fStartTimeBasevel[client]))
			{
				AddVelocity(client, g_vBasevelPush[g_iCurBasevel[client]]);
			}
		}
	}
	
	#if defined DEBUG
	OnGameFrame_Debug();
	#endif
}

public OnTriggerGeneric(const String:output[], caller, activator, Float:delay)
{
	decl String:m_output[64];
	Format(m_output, sizeof(m_output), "m_%s", output);
	new count = GetOutputCount(caller, m_output);
	decl String:clsname[64];
	GetEntityClassname(caller, clsname, sizeof(clsname));
	PrintToChatAll("%s triggered for %s, %d outputs", output, clsname, count);
	for (new i = 0; i < count; i++)
	{
		decl String:sParameter[64], String:sTarget[64];
		GetOutputTarget(caller, m_output, i, sTarget);
		GetOutputParameter(caller, m_output, i, sParameter);
		PrintToChatAll("%s, %s", sTarget, sParameter);
	}
}

public OnTrigger(const String:output[], caller, activator, Float:delay)
{
	new ent = caller;
	new client = activator;
	
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return;
	}
	
	new i;
	for (i = 0; i < g_iTriggerCount; i++) {
		if (ent == g_iTrigger[i]) {
			break;
		}
	}
	
	new Float:fTime = GetInternalTime();
	
	g_iCurTrigger[client] = i;
	
	if (TICKS(fTime - g_fEndTime[client]) + 1 < 0)
	{
		return;
	}
	
	g_bCurTriggerHasPushed[client] = false;
	
	g_fStartTime[client] = fTime + g_fTriggerStartDelay[i];
	g_fEndTime[client] = fTime + g_fTriggerDelay[i];
	
	if(g_fTriggerStartDelay[i])
		g_fStartTime[client] += 0.01;
	
	#if defined DEBUG
	PrintToConsole(client, "Trigger %d, delay %f! Start time %f, end time %f, current time %f, %d, %f, %d", g_iCurTrigger[client], g_fTriggerDelay[i], g_fStartTime[client], g_fEndTime[client], fTime, GetGameTickCount(), GetTickedTime(), GetSysTickCount());
	#endif
}

public OnTriggerSingle(const String:output[], caller, activator, Float:delay)
{
	new ent = caller;
	new client = activator;
	
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return;
	}
	
	new i;
	for (i = 0; i < g_iSingleTriggerCount; i++) {
		if (ent == g_iSingleTrigger[i]) {
			break;
		}
	}
	
	new Float:fTime = GetInternalTime();
	
	g_iCurTrigger[client] = i;
	
	g_bCurTriggerHasPushed[client] = false;
	
	g_fStartTime[client] = fTime + g_fSingleTriggerStartDelay[i];
	g_fEndTime[client] = -1.0;
	
	if(g_fSingleTriggerStartDelay[i])
		g_fStartTime[client] += 0.01;
	
	#if defined DEBUG
	PrintToConsole(client, "Single trigger %d, delay %f! Start time %f, end time %f, current time %f, %d, %f, %d", g_iCurTrigger[client], g_fTriggerDelay[i], g_fStartTime[client], g_fEndTime[client], fTime, GetGameTickCount(), GetTickedTime(), GetSysTickCount());
	#endif
}

public OnTriggerGravity(const String:output[], caller, activator, Float:delay)
{
	new ent = caller;
	new client = activator;
	
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return;
	}
	
	if (!g_bPushFix[client])
	{
		return;
	}
	
	new i;
	for (i = 0; i < g_iGravityCount; i++) {
		if (ent == g_iGravity[i]) {
			break;
		}
	}
	
	new Float:fTime = GetInternalTime();
	
	g_iCurGravity[client] = i;
	
	if (TICKS(fTime - g_fEndTimeGravity[client]) + 1 < 0)
	{
		return;
	}
	
	g_fStartTimeGravity[client] = fTime + g_fGravityStartDelay[i];
	g_fEndTimeGravity[client] = fTime + g_fGravityDelay[i] - 0.01;
	
	if(g_fGravityStartDelay[i])
		g_fStartTimeGravity[client] += 0.01;
	
	if (StrEqual(output, "OnEndTouch"))
	{
		g_fStartTimeGravity[client] += 0.01;
		g_fEndTimeGravity[client] += 0.01;
	}
	
	#if defined DEBUG
	PrintToConsole(client, "Gravity %d triggered! %f, %f, start time %f, end time %f, current time %f", i, g_fGravityStartDelay[i], g_fGravityDelay[i], g_fStartTimeGravity[client], g_fEndTimeGravity[client], fTime);
	#endif
}

public OnTriggerBasevel(const String:output[], caller, activator, Float:delay)
{
	new ent = caller;
	new client = activator;
	
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return;
	}
	
	if (!g_bPushFix[client])
	{
		return;
	}
	
	new iBasevel;
	for (iBasevel = 0; iBasevel < g_iBasevelCount; iBasevel++) {
		if (ent == g_iBasevel[iBasevel]) {
			break;
		}
	}
	
	new Float:fTime = GetInternalTime();
	
	g_iCurBasevel[client] = iBasevel;
	
	if (TICKS(g_fBasevelStartDelay[iBasevel]) < 1)
	{
		g_fStartTimeBasevel[client] = fTime + 0.01;
	}
	else
	{
		g_fStartTimeBasevel[client] = fTime + g_fBasevelStartDelay[iBasevel];
	}
	
	#if defined DEBUG
	PrintToConsole(client, "Basevel trigger %d, start delay %f! Start time %f, current time %f, %f", g_iCurBasevel[client], g_fBasevelStartDelay[iBasevel], g_fStartTimeBasevel[client], fTime, GetGameTime());
	#endif
}

public Action:OnTouchPush(entity, client)
{
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return Plugin_Continue;
	}
	
	new String:filter[32] = "";
	new iPush = -1;
	
	for (new i = 0; i < g_iPushCount; i++)
	{
		if (entity == g_iPush[i])
		{
			filter = g_sPushFilter[i];
			iPush = i;
			break;
		}
	}
	
	
	if (g_bPushFix[client] && iPush != -1)
	{
		// the tick count is inaccurate lol
		//new nTick = GetGameTickCount();
		//new iTick = GetTick();
		//new Float:fTime = GetInternalTime();
		
		new bool:bPush = false;
		
		if (TimeIsWithin(g_fStartTime[client], g_fEndTime[client]) && StrEqual(filter, g_sTriggerFilter[g_iCurTrigger[client]])) // g_iStartTick[client] <= iTick && iTick <= g_iEndTick[client]
		{
			if (g_vPushDir[iPush][2] != 1.0)
			{
				if (!g_bCurTriggerHasPushed[client])
				{
					bPush = true;
				}
			}
			else
			{
				bPush = true;
			}
		}
		
		
		if (bPush)
		{
			new Float:vVel[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
			
			if (g_vPushDir[iPush][2] != 1.0) //g_iStartTick[client] == iTick)
			{
				vVel[0] += g_fPushScale[iPush] * g_vPushDir[iPush][0];
				vVel[1] += g_fPushScale[iPush] * g_vPushDir[iPush][1];
				vVel[2] += g_fPushScale[iPush] * g_vPushDir[iPush][2];
			}
			else
			{
				vVel[2] += g_fPushScale[iPush] * GetTickInterval() * g_vPushDir[iPush][2];
			}
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
			
			g_bCurTriggerHasPushed[client] = true;
			
			#if defined DEBUG
			PrintToConsole(client, "Pushing %d, cur trig %d, time %d, %f, %f, %f, %d", iPush, g_iCurTrigger[client], GetGameTickCount(), GetInternalTime(), GetGameTime(), GetTickedTime(), GetSysTickCount());
			g_nPushedTicks[client]++;
			g_bPushedThisJump[client] = true;
			#endif
		}
		
		
		/*if((filter[0] == 0 || Entity_NameMatches(client, filter)) && (GetEntityFlags(client) & FL_ONGROUND) && g_vPushDir[iPush][2] == 1.0)
		{
			decl Float:pos[3];
			Entity_GetAbsOrigin(client, pos);
			pos[2] += 3.0;
			Entity_SetAbsOrigin(client, pos);
			SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", INVALID_ENT_REFERENCE);
			SetEntityFlags(client, GetEntityFlags(client) & ~FL_ONGROUND);
		}*/
		
		return Plugin_Handled;
	}
	
	#if defined DEBUG
	if (Entity_NameMatches(client, filter))
	{
		PrintToConsole(client, "Natural pushing hammerid %d, cur trig %d, time %d, %f, %f, %d", GetEntProp(entity, Prop_Data, "m_iHammerID"), g_iCurTrigger[client], GetGameTickCount(), GetInternalTime(), GetTickedTime(), GetSysTickCount());
		g_nPushedTicks[client]++;
		g_bPushedThisJump[client] = true;
	}
	#endif
	
	return Plugin_Continue;
}

public Action:OnGenericTouchGravity(entity, client)
{
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return Plugin_Continue;
	}
	
	#if defined DEBUG
	PrintToConsole(client, "OnGenericTouchGravity! Time %f", GetInternalTime());
	#endif
	
	if (g_bPushFix[client])
	{
		OnTriggerGravity("OnEndTouch", entity, client, 0.0);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:OnDamagedGravity(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	new client = attacker;
	
	#if defined DEBUG
	PrintToServer("OnDamagedGravity! Time %f", GetInternalTime());
	#endif
	
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return Plugin_Continue;
	}
	
	#if defined DEBUG
	PrintToConsole(client, "OnDamagedGravity! Time %f", GetInternalTime());
	#endif
	
	if (g_bPushFix[client])
	{
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:OnStartTouchFuncDoor(entity, client)
{
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return Plugin_Continue;
	}
	
	new Float:origin[3], Float:doororigin[3];
	
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", origin);
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", doororigin);
	
	if (origin[2] < doororigin[2])
	{
		#if defined DEBUG
		PrintToConsole(client, "func_door is above you, returning");
		#endif
		
		return Plugin_Continue;
	}
	
	new iFuncDoor = -1;
	
	for (new i = 0; i < g_iFuncDoorCount; i++)
	{
		if (entity == g_iFuncDoor[i])
		{
			iFuncDoor = i;
			break;
		}
	}
	
	#if defined DEBUG
	new Float:vVel[3];
	GetVelocity(client, vVel);
	
	PrintToConsole(client, "OnStartTouchFuncDoor! Time %f, vel %f, %f, %f", GetInternalTime(), EXPAND_VECTOR(vVel));
	#endif
	
	if (g_bPushFix[client])
	{
		new Float:fTime = GetInternalTime();
		
		// Adding velocity instantly doesn't work since you touch it on the last tick of descension, when you're about to have your Z vel reset.
		g_iCurFuncDoor[client] = iFuncDoor;
		g_fStartTimeFuncDoor[client] = fTime + 0.01;
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public Action:OnTouchFuncDoor(entity, client)
{
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return Plugin_Continue;
	}
	
	#if defined DEBUG
	new Float:vVel[3];
	GetVelocity(client, vVel);
	
	PrintToConsole(client, "OnTouchFuncDoor! Time %f, vel %f, %f, %f", GetInternalTime(), EXPAND_VECTOR(vVel));
	#endif
	
	if (g_bPushFix[client])
	{
		return Plugin_Handled;
	}
	#if defined DEBUG
	else
	{
		g_nPushedTicks[client]++;
		g_bPushedThisJump[client] = true;
	}
	#endif
	
	return Plugin_Continue;
}

public Action:OnStartTouchBasevel(entity, client)
{
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return Plugin_Continue;
	}
	
	#if defined DEBUG
	new Float:vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	
	PrintToConsole(client, "OnStartTouchBasevel! Time %f, vel %f, %f, %f", GetInternalTime(), vVel[0], vVel[1], vVel[2]);
	#endif
	
	if (g_bPushFix[client])
	{
		OnTriggerBasevel("OnStartTouch", entity, client, 0.0);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}


public Action:OnTouchBasevel(entity, client)
{
	if (!(client >= 1 && client <= MaxClients && !IsFakeClient(client)))
	{
		return Plugin_Continue;
	}
	
	#if defined DEBUG
	new Float:vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	
	PrintToConsole(client, "OnTouchBasevel! Time %f, vel %f, %f, %f", GetInternalTime(), vVel[0], vVel[1], vVel[2]);
	#endif
	
	if (g_bPushFix[client])
	{
		return Plugin_Handled;
	}
	#if defined DEBUG
	else
	{
		g_nPushedTicks[client]++;
		g_bPushedThisJump[client] = true;
	}
	#endif
	
	return Plugin_Continue;
}


GetAbsBoundingBox(ent, Float:mins[3], Float:maxs[3])
{
	decl Float:origin[3];
	
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", origin);
	GetEntPropVector(ent, Prop_Data, "m_vecMins", mins);
	GetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxs);
	
	mins[0] += origin[0];
	mins[1] += origin[1];
	mins[2] += origin[2];
	
	maxs[0] += origin[0];
	maxs[1] += origin[1];
	maxs[2] += origin[2];
}

bool:CheckLineBox(const Float:B1[3], const Float:B2[3], const Float:L1[3], const Float:L2[3])
{
	new Float:Hit[3];
	
	if (L2[0] < B1[0] && L1[0] < B1[0])return false;
	if (L2[0] > B2[0] && L1[0] > B2[0])return false;
	if (L2[1] < B1[1] && L1[1] < B1[1])return false;
	if (L2[1] > B2[1] && L1[1] > B2[1])return false;
	if (L2[2] < B1[2] && L1[2] < B1[2])return false;
	if (L2[2] > B2[2] && L1[2] > B2[2])return false;
	if (L1[0] > B1[0] && L1[0] < B2[0] && 
		L1[1] > B1[1] && L1[1] < B2[1] && 
		L1[2] > B1[2] && L1[2] < B2[2])
	{
		return true;
	}
	
	if ((GetIntersection(L1[0] - B1[0], L2[0] - B1[0], L1, L2, Hit) && InBox(Hit, B1, B2, 1))
		 || (GetIntersection(L1[1] - B1[1], L2[1] - B1[1], L1, L2, Hit) && InBox(Hit, B1, B2, 2))
		 || (GetIntersection(L1[2] - B1[2], L2[2] - B1[2], L1, L2, Hit) && InBox(Hit, B1, B2, 3))
		 || (GetIntersection(L1[0] - B2[0], L2[0] - B2[0], L1, L2, Hit) && InBox(Hit, B1, B2, 1))
		 || (GetIntersection(L1[1] - B2[1], L2[1] - B2[1], L1, L2, Hit) && InBox(Hit, B1, B2, 2))
		 || (GetIntersection(L1[2] - B2[2], L2[2] - B2[2], L1, L2, Hit) && InBox(Hit, B1, B2, 3)))
	{
		return true;
	}
	
	return false;
}

bool:GetIntersection(const Float:fDst1, const Float:fDst2, const Float:P1[3], const Float:P2[3], Float:Hit[3])
{
	if ((fDst1 * fDst2) >= 0.0)return false;
	if (fDst1 == fDst2)return false;
	Hit[0] = P1[0] + (P2[0] - P1[0]) * (-fDst1 / (fDst2 - fDst1));
	Hit[1] = P1[1] + (P2[1] - P1[1]) * (-fDst1 / (fDst2 - fDst1));
	Hit[2] = P1[2] + (P2[2] - P1[2]) * (-fDst1 / (fDst2 - fDst1));
	return true;
}

bool:InBox(Float:Hit[3], const Float:B1[3], const Float:B2[3], Axis)
{
	if (Axis == 1 && Hit[2] > B1[2] && Hit[2] < B2[2] && Hit[1] > B1[1] && Hit[1] < B2[1])return true;
	if (Axis == 2 && Hit[2] > B1[2] && Hit[2] < B2[2] && Hit[0] > B1[0] && Hit[0] < B2[0])return true;
	if (Axis == 3 && Hit[0] > B1[0] && Hit[0] < B2[0] && Hit[1] > B1[1] && Hit[1] < B2[1])return true;
	return false;
}

stock AddVelocity(client, Float:vec[3])
{
	new Float:vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	
	vVel[0] += vec[0];
	vVel[1] += vec[1];
	vVel[2] += vec[2];
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
}

stock AddVelocity2(client, Float:x, Float:y, Float:z)
{
	new Float:vVel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vVel);
	
	vVel[0] += x;
	vVel[1] += y;
	vVel[2] += z;
	
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vVel);
}

stock GetVelocity(entity, Float:output[3])
{
	GetEntPropVector(entity, Prop_Data, "m_vecVelocity", output);
}

stock GetOrigin(entity, Float:output[3])
{
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", output);
}

stock GetHammerID(entity)
{
	return GetEntProp(entity, Prop_Data, "m_iHammerID");
}

stock bool:FloatEquals(Float:a, Float:b)
{
	return a - b < 0.000001 && a - b > -0.000001;
}

stock bool:CheckPointBoxIntersection(const Float:point[3], const Float:bb[2][3])
{
	if (point[0] > bb[0][0] && point[0] < bb[1][0] && 
		point[1] > bb[0][1] && point[1] < bb[1][1] && 
		point[2] > bb[0][2] && point[2] < bb[1][2])
	{
		return true;
	}
	
	return false;
}

stock Float:GetEntityDistance(ent1, ent2)
{
	new Float:bb1[2][3], Float:bb2[2][3];
	GetAbsBoundingBox(ent1, bb1[0], bb1[1]);
	GetAbsBoundingBox(ent2, bb2[0], bb2[1]);
	
	new bool:above[3], bool:below[3];
	
	for (new i = 0; i < 3; i++)
	{
		above[i] = bb1[0][i] > bb2[1][i];
		below[i] = bb1[1][i] < bb2[0][i];
	}
	
	new Float:p1[3] =  { 0.0, 0.0, 0.0 }, Float:p2[3] =  { 0.0, 0.0, 0.0 };
	
	for (new i = 0; i < 3; i++)
	{
		if (above[i])
		{
			p1[0] = bb1[0][i];
			p2[0] = bb2[1][i];
		}
		else if (below[i])
		{
			p1[0] = bb1[1][i];
			p2[0] = bb2[0][i];
		}
	}
	
	return GetVectorDistance(p1, p2);
}

stock RotatePoint(Float:out[3], const Float:p[3], const Float:angles[3])
{
	new Float:sin[3], Float:cos[3], Float:temp[3];
	
	sin[0] = Sine(angles[0] * FLOAT_PI / 180.0);
	sin[1] = Sine(angles[1] * FLOAT_PI / 180.0);
	sin[2] = Sine(angles[2] * FLOAT_PI / 180.0);
	cos[0] = Cosine(angles[0] * FLOAT_PI / 180.0);
	cos[1] = Cosine(angles[1] * FLOAT_PI / 180.0);
	cos[2] = Cosine(angles[2] * FLOAT_PI / 180.0);
	
	temp[0] = cos[1] * cos[0] * p[0] + (cos[1] * sin[0] * sin[2] - sin[1] * cos[2]) * p[1] + (sin[1] * sin[2] + cos[1] * sin[0] * cos[2]) * p[2];
	temp[1] = sin[1] * cos[0] * p[0] + (cos[1] * cos[2] + sin[1] * sin[0] * sin[2]) * p[1] + (sin[1] * sin[0] * cos[2] - cos[1] * sin[2]) * p[2];
	temp[2] = cos[0] * sin[2] * p[1] + cos[0] * cos[2] * p[2] - sin[0] * p[0];
	
	out = temp;
}

public bool:WorldFilter(entity, mask)
{
	if (entity)
		return false;
	
	return true;
}

bool:TraceRay(Float:vEndPos[3], Float:vNormal[3], const Float:vTraceOrigin[3], const Float:vEndPoint[3], bool:bCorrectError = true)
{
	TR_TraceRayFilter(vTraceOrigin, vEndPoint, MASK_PLAYERSOLID, RayType_EndPoint, WorldFilter);
	
	if (!TR_DidHit())
	{
		return false;
	}
	
	TR_GetEndPosition(vEndPos);
	TR_GetPlaneNormal(INVALID_HANDLE, vNormal);
	
	// correct slopes
	if (vNormal[2])
	{
		vNormal[2] = 0.0;
		NormalizeVector(vNormal, vNormal);
	}
	
	if (bCorrectError)
	{
		vEndPos[0] -= vNormal[0] * 0.03125;
		vEndPos[1] -= vNormal[1] * 0.03125;
	}
	
	new Float:fDist = GetVectorDistance(vTraceOrigin, vEndPos);
	return fDist != 0.0 && fDist < GetVectorDistance(vTraceOrigin, vEndPoint);
}

bool:TraceRay2(Float:vEndPos[3], const Float:vTraceOrigin[3], const Float:vEndPoint[3], bool:bCorrectError = true)
{
	new Float:vNormal[3];
	
	return TraceRay(vEndPos, vNormal, vTraceOrigin, vEndPoint, bCorrectError);
}


/////////////////
// debug stuff //
/////////////////


public Action:Command_List(client, args)
{
	decl Float:origin[3];
	for (new i = 0; i < g_iPushCount; i++)
	{
		new id = GetEntProp(g_iPush[i], Prop_Data, "m_iHammerID");
		GetEntPropVector(g_iPush[i], Prop_Data, "m_vecOrigin", origin);
		
		if (g_iPush[i] == -1)
		{
			PrintToConsole(client, "inactivatable push %d hammerid %d origin %f, %f, %f: scale %f filter %s", i, id, g_fPushScale[i], g_sPushFilter[i]);
			
			continue;
		}
		
		PrintToConsole(client, "push %d hammerid %d origin %f, %f, %f: scale %f filter %s", i, id, EXPAND_VECTOR(origin), g_fPushScale[i], g_sPushFilter[i]);
	}
	
	for (new i = 0; i < g_iTriggerCount; i++)
	{
		decl String:buf[64];
		GetEntityClassname(g_iTrigger[i], buf, sizeof(buf));
		
		new id = GetEntProp(g_iTrigger[i], Prop_Data, "m_iHammerID");
		GetEntPropVector(g_iPush[i], Prop_Data, "m_vecOrigin", origin);
		
		PrintToConsole(client, "trigger %d hammerid %d type %s origin %f, %f, %f: filter %s", i, id, buf, EXPAND_VECTOR(origin), g_sTriggerFilter[i]);
	}
	
	for (new i = 0; i < g_iGravityCount; i++)
	{
		new id = GetEntProp(g_iGravity[i], Prop_Data, "m_iHammerID");
		GetEntPropVector(g_iPush[i], Prop_Data, "m_vecOrigin", origin);
		
		PrintToConsole(client, "gravity %d hammerid %d origin %f, %f, %f: value %f", i, id, EXPAND_VECTOR(origin), g_fGravityValue[i]);
	}
	
	for (new i = 0; i < g_iFuncDoorCount; i++)
	{
		new id = GetEntProp(g_iFuncDoor[i], Prop_Data, "m_iHammerID");
		GetEntPropVector(g_iPush[i], Prop_Data, "m_vecOrigin", origin);
		
		PrintToConsole(client, "func_door %d hammerid %d origin %f, %f, %f: speed %f", i, id, EXPAND_VECTOR(origin), g_fFuncDoorSpeed[i]);
	}
	
	for (new i = 0; i < g_iBasevelCount; i++)
	{
		new id = GetEntProp(g_iBasevel[i], Prop_Data, "m_iHammerID");
		GetEntPropVector(g_iBasevel[i], Prop_Data, "m_vecOrigin", origin);
		
		PrintToConsole(client, "basevel %d hammerid %d origin %f, %f, %f: push %f, %f, %f", i, id, EXPAND_VECTOR(origin), EXPAND_VECTOR(g_vBasevelPush[i]));
	}
	
	PrintToChat(client, "Output in console");
	
	return Plugin_Handled;
}

#if defined DEBUG
new Float:g_fApexZVel[MAXPLAYERS + 1] = 0.0;
new Float:g_fStartZ[MAXPLAYERS + 1] = 0.0;
new Float:g_fApexZ[MAXPLAYERS + 1] = 0.0;
new Float:g_fStartZVel[MAXPLAYERS + 1] = 0.0;

new Float:g_fGravStartTime[MAXPLAYERS + 1] = 0.0;
new Float:g_fLastGravity[MAXPLAYERS + 1] = 1.0;

OnGameFrame_Debug()
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			new client = i;
			
			new Float:fTime = GetInternalTime();
			
			if (TICKS(fTime - g_fStartTimeFuncDoor[client]) == 0)
			{
				#if defined DEBUG
				new Float:vel[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
				PrintToConsole(client, "func_door! %f, vel: %f, time %f", g_fFuncDoorSpeed[g_iCurFuncDoor[client]], vel[2], GetInternalTime());
				
				g_nPushedTicks[client]++;
				g_bPushedThisJump[client] = true;
				#endif
			}
			
			if (TICKS(fTime - g_fStartTimeBasevel[client]) == 0)
			{
				#if defined DEBUG
				new Float:vel[3];
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", vel);
				PrintToConsole(client, "Basevel! %f, vel: %f, time %f", g_vBasevelPush[g_iCurBasevel[client]][2], vel[2], GetInternalTime());
				
				g_nPushedTicks[client]++;
				g_bPushedThisJump[client] = true;
				#endif
			}
			
			
			static bool:bLastOnGround = true;
			new bool:bGround = bool:(GetEntityFlags(i) & FL_ONGROUND);
			new Float:vOrigin[3], Float:vVel[3];
			GetClientAbsOrigin(i, vOrigin);
			GetEntPropVector(i, Prop_Data, "m_vecVelocity", vVel);
			
			if (bGround && !bLastOnGround)
			{
				PlayerLand(i);
			}
			else if (!bGround && bLastOnGround)
			{
				g_fApexZVel[i] = -FLT_MAX;
				g_nPushedTicks[i] = 0;
				g_fStartZ[i] = vOrigin[2];
				g_fApexZ[i] = -FLT_MAX;
				g_bPushedThisJump[i] = false;
				g_fStartZVel[i] = vVel[2];
			}
			
			bLastOnGround = bGround;
			
			
			if (vVel[2] > g_fApexZVel[i])
			{
				g_fApexZVel[i] = vVel[2];
			}
			
			if (vOrigin[2] > g_fApexZ[i])
			{
				g_fApexZ[i] = vOrigin[2];
			}
			
			
			new Float:fGravity = GetEntPropFloat(i, Prop_Data, "m_flGravity");
			
			
			if (fGravity != 1.0 && fGravity != 0.0)
			{
				PrintToConsole(i, "Gravity %f! Time %f", fGravity, GetInternalTime());
			}
			
			if (fGravity != 1.0 && g_fLastGravity[i] == 1.0)
			{
				g_fGravStartTime[i] = GetInternalTime();
			}
			else if (fGravity == 1.0 && g_fLastGravity[i] != 1.0)
			{
				decl String:buf[256];
				FormatEx(buf, sizeof(buf), "Gravity lasted %f", GetInternalTime() - g_fGravStartTime[i]);
				
				new Handle:hBuffer = StartMessageOne("KeyHintText", i);
				BfWriteByte(hBuffer, 1);
				BfWriteString(hBuffer, buf);
				EndMessage();
				
				PrintToConsole(i, buf);
				PrintToConsole(i, ""); // Newline
			}
			
			g_fLastGravity[i] = fGravity;
		}
	}
}

public PlayerLand(client)
{
	if (!g_bPushedThisJump[client])
	{
		return;
	}
	
	new Float:vPos[3];
	GetClientAbsOrigin(client, vPos);
	
	decl String:buf[256];
	FormatEx(buf, sizeof(buf), "Pushfix %s\n\nStart Z vel: %.02f\nPush ticks: %d\nJump height: %.02f\nLanding point: %.02f, %.02f, %.02f", 
		g_bPushFix[client]?"ON":"OFF", g_fStartZVel[client], g_nPushedTicks[client], g_fApexZ[client] - g_fStartZ[client], vPos[0], vPos[1], vPos[2]);
	
	new Handle:hBuffer = StartMessageOne("KeyHintText", client);
	BfWriteByte(hBuffer, 1);
	BfWriteString(hBuffer, buf);
	EndMessage();
	
	PrintToConsole(client, buf);
	PrintToConsole(client, ""); // Newline
}

public Action:Command_Init(client, args)
{
	Init();
}

stock CreateBeamClient(client, const Float:v1[3], const Float:v2[3], r = 255, g = 255, b = 255, Float:fLifetime = 10.0)
{
	new color[4];
	color[0] = r;
	color[1] = g;
	color[2] = b;
	color[3] = 100;
	TE_SetupBeamPoints(v1, v2, PrecacheModel("materials/sprites/bluelaser1.vmt"), 0, 0, 0, fLifetime, 10.0, 10.0, 10, 0.0, color, 0);
	TE_SendToClient(client);
}
#endif