#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

native TraceTriggers(client, float flStart[3], float flEnd[3]);

public Plugin:myinfo =
{
	name = "Speed Run Stage Records",
	author = "backwards",
	description = "Shows Current Speedrun Times On Automatically Generated Stages.",
	version = SOURCEMOD_VERSION,
	url = "http://www.steamcommunity.com/id/mypassword"
}

#define SPECMODE_FIRSTPERSON 4
#define SPECMODE_3RDPERSON 5
#define ENDZONE_ENTITY_TRIGGER 3002
#define STARTZONE_ENTITY_TRIGGER 3005

new	ArrayList:g_NormalPlayerTimesTriggerstoTrigger[MAXPLAYERS+1];
new	ArrayList:g_BonusPlayerTimesTriggerstoTrigger[MAXPLAYERS+1];

new	ArrayList:g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[MAXPLAYERS+1];
new	ArrayList:g_BonusPlayerTimesTriggerstoTriggerCurrentRunOnly[MAXPLAYERS+1];

new PreviousPlayerTrigger[MAXPLAYERS+1] = {3000, ...};
new g_PreviousIgnoreTrigger[MAXPLAYERS+1] = {3001, ...};
new g_TeleportDestionations[2048+1] = {-1, ...};
bool g_bWantsStageRecords[MAXPLAYERS+1] = {false, ...};
//float g_NormalPlayerTimesTriggerstoTrigger[MAXPLAYERS+1][2048+1][2048+1];
float g_ClientCurrentTime[MAXPLAYERS+1] = {0.0, ...};
bool g_ClientComputingTime[MAXPLAYERS+1] = {false, ...};
int SpectatingPlayer[MAXPLAYERS+1] = {-1, ...};
int NextSequencePos[MAXPLAYERS+1] = {-1, ...};

new g_PlayerCurrentStage[MAXPLAYERS+1] = {0, ...};

new	ArrayList:PlayerRecordStringEntries[MAXPLAYERS+1];
char PlayersRecordsString[MAXPLAYERS+1][512];

new PlayersRecordsStringRGBforSpecs[MAXPLAYERS+1][3];
new PlayersRecordStringRGB[MAXPLAYERS+1][3];
float g_PlayerPastStageUpdateTime[MAXPLAYERS+1] = {0.0, ...};

Handle g_hStagesEnabled;

new EngineVersion:iEngineVersion = Engine_Unknown;

public OnPluginStart()
{
	iEngineVersion = GetEngineVersion();
	if(iEngineVersion != Engine_CSS && iEngineVersion != Engine_CSGO)
		SetFailState("backward's automatic stages plugin does not support engine version %d!", iEngineVersion);

	g_hStagesEnabled = RegClientCookie("SpeedRunStages", "backwards generated", CookieAccess_Public);
	HookEvent("player_spawn", OnPlayerSpawn);
	
	RegConsoleCmd("sm_stages", StagesToggle_CMD);
	RegConsoleCmd("sm_reset", StagesResetStats_CMD);
	RegConsoleCmd("sm_clear", StagesResetStats_CMD);
	//RegConsoleCmd("sm_resetrun", StagesResetCurrent_CMD);
	
	for(int client = 0;client<= MAXPLAYERS;client++)
	{
		g_NormalPlayerTimesTriggerstoTrigger[client] = CreateArray(12 + 1);
		g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client]  = CreateArray(12 + 1);
		PlayerRecordStringEntries[client] = CreateArray(64 + 4);
	}
	CreateTimer(0.2, Timer_CheckSpectators, _, TIMER_REPEAT);
}

public OnClientCookiesCached(client)
{
	if(IsClientInGame(client) && !IsFakeClient(client))
	{
		char sCookieValue[12];
		GetClientCookie(client, g_hStagesEnabled, sCookieValue, sizeof(sCookieValue));
		g_bWantsStageRecords[client] = StringToInt(sCookieValue) ? true : false;
	}
}

public OnClientPutInServer(client)
{
	if(!IsFakeClient(client))
	{
		if (AreClientCookiesCached(client))
		{
			char sCookieValue[12];
			GetClientCookie(client, g_hStagesEnabled, sCookieValue, sizeof(sCookieValue));
			g_bWantsStageRecords[client] = StringToInt(sCookieValue) ? true : false;
		}
	}
}

public OnClientDisconnect(client)
{

	char cValue[12];
	Format(cValue, 12, "%i", g_bWantsStageRecords[client] ? 1 : 0);
	SetClientCookie(client, g_hStagesEnabled, cValue);
	
	g_bWantsStageRecords[client] = false;
	PreviousPlayerTrigger[client] = 3000;
	g_PreviousIgnoreTrigger[client] = 3001;
	g_ClientCurrentTime[client] = 0.0;
	g_ClientComputingTime[client] = false;
	ClearArray(g_NormalPlayerTimesTriggerstoTrigger[client]);
	ClearArray(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client]);
	ClearArray(PlayerRecordStringEntries[client]);
	PlayersRecordsString[client][0] = '\0';
	NextSequencePos[client] = -1;
	g_PlayerCurrentStage[client] = 0;
	g_PlayerPastStageUpdateTime[client] = 0.0;
}

public OnMapStart()
{
	for(int i = 0;i < 2049; i++)
		g_TeleportDestionations[i] = -1;

	for(int client = 0;client<= MAXPLAYERS;client++)
	{
		PreviousPlayerTrigger[client] = 3000;
		ClearArray(g_NormalPlayerTimesTriggerstoTrigger[client]);
		ClearArray(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client]);
		ClearArray(PlayerRecordStringEntries[client]);
		g_ClientCurrentTime[client] = 0.0;
		g_ClientComputingTime[client] = false;
		g_PreviousIgnoreTrigger[client] = 3001;
		PlayersRecordsString[client][0] = '\0';
		NextSequencePos[client] = -1;
		g_PlayerCurrentStage[client] = 0;
		g_PlayerPastStageUpdateTime[client] = 0.0;
	}
	FindAndMarkTeleportDestinations();
}

public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsValidClient(client) || !IsPlayerAlive(client))
		return Plugin_Continue;
	
	ResetPlayerCurrentRun(client);

	return Plugin_Continue;
}

void ResetPlayerCurrentRun(client)
{
	g_PlayerPastStageUpdateTime[client] = 0.0;
	g_PreviousIgnoreTrigger[client] = 3001;
	PreviousPlayerTrigger[client] = 3000;
	PlayersRecordsString[client][0] = '\0';
	g_ClientCurrentTime[client] = 0.0;
	g_ClientComputingTime[client] = true;
	NextSequencePos[client] = 0;
	g_PlayerCurrentStage[client] = 0;
	ClearArray(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client]);
	ClearArray(PlayerRecordStringEntries[client]);
}

public Action StagesResetCurrent_CMD(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Handled;
	
	ResetPlayerCurrentRun(client);
	
	if(iEngineVersion == Engine_CSS)
		PrintToChat(client, "[STAGES]: Reset Current Run.");
	else if(iEngineVersion == Engine_CSGO)
		PrintToChat(client, "\x04[\x01STAGES\x04]: \x03Reset Current Run.");
	
	return Plugin_Handled;
} 
public Action StagesResetStats_CMD(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Handled;
	
	g_PlayerPastStageUpdateTime[client] = 0.0;
	g_PreviousIgnoreTrigger[client] = 3001;
	PreviousPlayerTrigger[client] = 3000;
	ClearArray(g_NormalPlayerTimesTriggerstoTrigger[client]);
	g_ClientCurrentTime[client] = 0.0;
	g_ClientComputingTime[client] = true;
	NextSequencePos[client] = -1;
	g_PlayerCurrentStage[client] = 0;
	ClearArray(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client]);
	ClearArray(PlayerRecordStringEntries[client]);
	
	if(iEngineVersion == Engine_CSS)
		PrintToChat(client, "\x01\x0851E3BFFF[\x08FFFF96FFSTAGES\x0851E3BFFF]: \x0832FF14FFCleared Stage History\x0851E3BFFF.");
	else if(iEngineVersion == Engine_CSGO)
		PrintToChat(client, "[STAGES]: Cleared Stage History.");
		
	return Plugin_Handled;
} 

public Action StagesToggle_CMD(int client, int args)
{
	if(!IsValidClient(client))
		return Plugin_Handled;
	
	g_bWantsStageRecords[client] = !g_bWantsStageRecords[client];
	
	if(g_bWantsStageRecords[client])
	{
		if(iEngineVersion == Engine_CSS)
		{
			PrintToChat(client, "\x01\x08000000E6////////////////////////////////////////////////////");
			PrintToChat(client, "\x01\x08BB1738E6Experimental Plugin Created by \x08FF0000FFbackwards\x08BB1738FF.");
			PrintToChat(client, "\x01\x08FFFFFFE6Stages are automatically detected without specific map setup and are subject to bugs based on map design strategy and shortcuts used. The current record can be reset by typing !reset or !clear.");
			PrintToChat(client, "\x01\x08000000E6////////////////////////////////////////////////////");
			PrintToChat(client, "\x01\x0851E3BFFF[\x08FFFF96FFSTAGES\x0851E3BFFF]: \x0800FF00FFEnabled\x0851E3BFFF.");
		}
		else if(iEngineVersion == Engine_CSGO)
		{
			PrintToChat(client, "Experimental Plugin Created by backward.");
			PrintToChat(client, "Stages are automatically detected without specific map setup and are subject to bugs based on map design strategy and shortcuts used. The current record can be reset by typing !reset or !clear.");
			PrintToChat(client, "[STAGES]: Enabled.");
		}
		
		g_ClientComputingTime[client] = true;
	}
	else
	{
		if(iEngineVersion == Engine_CSS)
			PrintToChat(client, "\x01\x0851E3BFFF[\x08FFFF96FFSTAGES\x0851E3BFFF]: \x08FF0000FFDisabled\x0851E3BFFF.");
		else if(iEngineVersion == Engine_CSGO)
			PrintToChat(client, "[STAGES]: Disabled.");
			
		ResetPlayerCurrentRun(client);
		g_ClientComputingTime[client] = false;
	}
	
	return Plugin_Handled;
}

public FindAndMarkTeleportDestinations()
{
	for(new entity = MaxClients;entity < GetMaxEntities();entity++)
	{
		if(IsValidEntity(entity) && IsValidEdict(entity))
		{
			decl String:className[128];
			GetEntityClassname(entity, className, sizeof(className));
			
			//decl Float:position[3];
			//int type = -1;
			
			if(StrEqual(className, "trigger_teleport", false))
			{
				/*new finaldestoffset = FindDataMapOffs(entity, "m_vecFinalDest");
				new vecPosition1offset = FindDataMapOffs(entity, "m_vecPosition1");
				new vecPosition2offset = FindDataMapOffs(entity, "m_vecPosition2");
				
				GetEntDataVector(entity, finaldestoffset, position);
				GetEntDataVector(entity, vecPosition1offset, position);
				GetEntDataVector(entity, vecPosition2offset, position);
				type = 1;
				
				new targetoffset = FindDataMapOffs(entity, "m_target");
				int index = GetEntDataEnt2(entity, targetoffset);
				
				//PrintToServer("offset = %i, target = %i", targetoffset, index);
				
				//int index = GetEntData(entity, targetoffset, 4);
				int entindex = EntRefToEntIndex(index);
				
				if(entindex != -1)
					GetEntPropVector(entindex, Prop_Data, "m_vecAbsOrigin", position);
				else
					type = -1;
					
				*/

				//new destination_entity = -1;
				decl String:targetname[228], String:destination_name[228];
				GetEntPropString(entity, Prop_Data, "m_target", targetname, sizeof(targetname));  
				
				//while ((destination_entity = FindEntityByClassname(destination_entity, "info_teleport_destination")) != -1)
				for(new destination_entity = MaxClients;destination_entity < GetMaxEntities();destination_entity++)
				{
					if(IsValidEntity(destination_entity) && IsValidEdict(destination_entity))
					{
						if(FindDataMapInfo(destination_entity, "m_iName") == -1)
							continue;
							
						GetEntPropString(destination_entity, Prop_Data, "m_iName", destination_name, sizeof(destination_name));

						if (StrEqual(destination_name, targetname))
						{
							g_TeleportDestionations[entity] = destination_entity;
							
							/*
							decl String:hammerIDstr[32];
							new hammerIDInt = GetEntProp(destination_entity, Prop_Data, "m_iHammerID");
							IntToString(hammerIDInt, hammerIDstr, 32);
							
							PrintToServer("Found %s index:%i with destionation of %s index:%i with hammerid: %s", className, entity, destination_name, destination_entity, hammerIDstr);
							*/
							break;
						}
					}
				}  
					
				
			}
			/*else if(StrEqual(className, "trigger_teleport_relative", false))
			{
				new finaldestoffset = FindDataMapOffs(entity, "m_vecFinalDest");
				
				GetEntDataVector(entity, finaldestoffset, position);
				type = 2;
			}
			else if(StrEqual(className, "point_teleport", false))
			{
				new targetoffset = FindDataMapOffs(entity, "m_target");
				int entindex = GetEntDataEnt2(entity, targetoffset);
				
				GetEntPropVector(entindex, Prop_Data, "m_vecAbsOrigin", position);
				type = 3;
			}
			else
			{
				continue;
			}
			
			//PrintToServer("endPos = {%f, %f, %f} type = %i", position[0], position[1], position[2], type);
			*/
		}
	}
}

bool IsValidClient(int client)
{
    if (!(1 <= client <= MaxClients) || !IsClientConnected(client) || !IsClientInGame(client) || IsClientSourceTV(client) || IsClientReplay(client))
        return false;
		
    return true;
}
 
int CheckTriggerUnderPlayer(client)
{
	new Float:flStart[3], Float:flEnd[3];
	GetClientAbsOrigin(client, flStart);
	flEnd = flStart;
	flEnd[2] -= 475.0;//good enough
	
	//int entity = TraceTriggers(client, flStart, flEnd);
	
	new ent = TraceTriggers(client, flStart, flEnd);
	
	/*PrintToServer("%f", retnval);
	
	int ent = 0;
	Handle hTrace = TR_TraceRayFilterEx(flStart, flEnd, MASK_ALL, RayType_EndPoint, TraceRayDontHitSelf, client);
	
	if(hTrace != INVALID_HANDLE)
	{
		ent = TR_GetEntityIndex(hTrace);
		delete hTrace;
	}
	*/
	return ent;
}

public bool:TraceRayDontHitSelf(entity, mask, any:data)  
{  
    return (entity != data);  
}

void EndRunOnStage(client, type)
{
	if(!g_ClientComputingTime[client])
		return;
	
	CheckTriggerSequence(client,  ENDZONE_ENTITY_TRIGGER);
	PreviousPlayerTrigger[client] =  ENDZONE_ENTITY_TRIGGER;
	g_ClientComputingTime[client] = false;
}

bool processedLastTick[MAXPLAYERS+1] = {false, ...};

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if(IsValidClient(client) && g_bWantsStageRecords[client] && !IsFakeClient(client) && IsPlayerAlive(client))
	{
		if(PreviousPlayerTrigger[client] == ENDZONE_ENTITY_TRIGGER)
			return;
			
		if(g_ClientComputingTime[client])
			g_ClientCurrentTime[client] += GetTickInterval();
		
		float Velocity = GetClientVelocity(client);
		
		//Optimization, skip single processing unit.
		if(processedLastTick[client] && Velocity < 500)
		{
			processedLastTick[client] = false;
			return;
		}
		
		processedLastTick[client] = true;
		
		if(Velocity > 0)
		{
			new trigger = CheckTriggerUnderPlayer(client);
			if(trigger == 0 || g_TeleportDestionations[trigger] == -1)
				return;
			
			if( g_TeleportDestionations[trigger] == PreviousPlayerTrigger[client])
				return;
			
			if(PreviousPlayerTrigger[client] != 3000)
			{
				if(g_TeleportDestionations[trigger] == g_PreviousIgnoreTrigger[client])
					return;
					
				CheckTriggerSequence(client,  g_TeleportDestionations[trigger]);
			}
			else
			{
				g_ClientCurrentTime[client] = 0.0;
			}
			//PrintToChat(client, "ent = %i", trigger);
			//PrintToChat(client, "Teleport Destination = %i", g_TeleportDestionations[trigger]);
			PreviousPlayerTrigger[client] =  g_TeleportDestionations[trigger];
		}
	}
}

bool CheckIfTriggerAlreadyUsedInCurrentSequence(client, trigger)
{
	new iSize = GetArraySize(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client]);

	//This is to prevent players from going backwards and getting new segments that are impossible...
	decl String:IgnoreTriggerName[12];
	Format(IgnoreTriggerName, sizeof(IgnoreTriggerName), "-%i", trigger);
	
	for(int i = 0;i < iSize;i++)
	{
		decl String:ArrayStringName[12];
		GetArrayString(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client], i, ArrayStringName, sizeof(ArrayStringName));
		if(StrContains(ArrayStringName, IgnoreTriggerName) != -1)
		{
			g_PreviousIgnoreTrigger[client] = trigger;
			return true;
		}
	}
	
	decl String:SequenceName[12], String:ArrayStringName[12];
	Format(SequenceName, sizeof(SequenceName), "%i-%i", trigger, PreviousPlayerTrigger[client]);
	
	bool found = false;
	for(int i = 0;i < iSize;i++)
	{
		GetArrayString(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client], i, ArrayStringName, sizeof(ArrayStringName));
		if(StrEqual(ArrayStringName, SequenceName))
		{
			float TimeBetweenSequences = GetArrayCell(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client], i, 12);
			float difference = TimeBetweenSequences - g_ClientCurrentTime[client];
			
			if(difference > 0.0)
				SetArrayCell(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client], i, g_ClientCurrentTime[client], 12);

			found = true;
			break;
		}
	}
	
	if(!found)
	{
		ResizeArray(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client], iSize+1);
		SetArrayString(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client], iSize, SequenceName);
		SetArrayCell(g_NormalPlayerTimesTriggerstoTriggerCurrentRunOnly[client], iSize, g_ClientCurrentTime[client], 12);
	}
	else
		return true;
	
	return false;
}

void CheckTriggerSequence(client, trigger)
{
	new iSize = GetArraySize(g_NormalPlayerTimesTriggerstoTrigger[client]);
	//ResizeArray(g_NormalPlayerTimesTriggerstoTrigger[client], iSize + 1);

	//This is to prevent players from going backwards and getting new segments that are impossible...
	/*decl String:IgnoreTriggerName[12];
	Format(IgnoreTriggerName, sizeof(IgnoreTriggerName), "-%i", trigger);
	
	for(int i = 0;i < iSize;i++)
	{
		decl String:ArrayStringName[12];
		GetArrayString(g_NormalPlayerTimesTriggerstoTrigger[client], i, ArrayStringName, sizeof(ArrayStringName));
		if(StrContains(ArrayStringName, IgnoreTriggerName) != -1)
		{
			g_PreviousIgnoreTrigger[client] = trigger;
			return;
		}
	}*/
	////
	
	if(CheckIfTriggerAlreadyUsedInCurrentSequence(client, trigger))
		return;
	
	decl String:SequenceName[12], String:ArrayStringName[12];
	Format(SequenceName, sizeof(SequenceName), "%i-%i", trigger, PreviousPlayerTrigger[client]);
	
	bool found = false;
	for(int i = 0;i < iSize;i++)
	{
		GetArrayString(g_NormalPlayerTimesTriggerstoTrigger[client], i, ArrayStringName, sizeof(ArrayStringName));
		if(StrEqual(ArrayStringName, SequenceName))
		{
			float TimeBetweenSequences = GetArrayCell(g_NormalPlayerTimesTriggerstoTrigger[client], i, 12);
			float difference = TimeBetweenSequences - g_ClientCurrentTime[client];
			
			if(difference > 0.0)
			{
				//SetArrayString(g_NormalPlayerTimesTriggerstoTrigger[client], i, SequenceName);
				SetArrayCell(g_NormalPlayerTimesTriggerstoTrigger[client], i, g_ClientCurrentTime[client], 12);
				//PrintToChat(client, "Time = old:%.2f current:%.2f new:%.2f diff:+%.2f", TimeBetweenSequences, g_ClientCurrentTime[client], g_ClientCurrentTime[client], difference);
			}
			else
			{
				//PrintToChat(client, "Time = old:%.2f current:%.2f new:%.2f diff:%.2f", TimeBetweenSequences, g_ClientCurrentTime[client], TimeBetweenSequences, difference);
			}
			
			
			if(i+1 > iSize-1)
				NextSequencePos[client] = -1;
			else
				NextSequencePos[client] = i+1;
			
			g_PlayerCurrentStage[client] = i+1;
			
			found = true;
			break;
		}
	}
	
	if(!found)
	{
		//PrintToChat(client, "No Sequence was found..");
		ResizeArray(g_NormalPlayerTimesTriggerstoTrigger[client], iSize+1);
		
		//new index_entry = PushArrayString(g_NormalPlayerTimesTriggerstoTrigger[client], SequenceName);
		//new index_entry2 = PushArrayCell(g_NormalPlayerTimesTriggerstoTrigger[client], g_ClientCurrentTime[client]);
		SetArrayString(g_NormalPlayerTimesTriggerstoTrigger[client], iSize, SequenceName);
		SetArrayCell(g_NormalPlayerTimesTriggerstoTrigger[client], iSize, g_ClientCurrentTime[client], 12);
		//PrintToChat(client, "Inserted New Sequence %s @ %.2f.", SequenceName, g_ClientCurrentTime[client]);
		NextSequencePos[client] = -1;
		g_PlayerCurrentStage[client] = iSize+1;
		//PushClientRecordString(client, PlayersRecordsString[client], PlayersRecordStringRGB[client][0], PlayersRecordStringRGB[client][1], PlayersRecordStringRGB[client][2]);
	}

	if(trigger == ENDZONE_ENTITY_TRIGGER)
	{
		PushClientRecordString(client, PlayersRecordsString[client], PlayersRecordStringRGB[client][0], PlayersRecordStringRGB[client][1], PlayersRecordStringRGB[client][2]);
		//PushClientRecordString(client, PlayersRecordsString[client], 0, 0, 255);
		g_PlayerCurrentStage[client] = ENDZONE_ENTITY_TRIGGER;
		//PushClientRecordString(client, PlayersRecordsString[client], 0, 0, 255);
	}
	else
	{
		PushClientRecordString(client, PlayersRecordsString[client], PlayersRecordStringRGB[client][0], PlayersRecordStringRGB[client][1], PlayersRecordStringRGB[client][2]);
	}
	//PushClientRecordString(client, PlayersRecordsString[client], PlayersRecordStringRGB[client][0], PlayersRecordStringRGB[client][1], PlayersRecordStringRGB[client][2]);
	g_ClientCurrentTime[client] = 0.0;
	//SetArrayCell(g_hFrame[client], iSize, vPos[0], 0);
	//SetArrayCell(g_hFrame[client], iSize, vPos[1], 1);

}

#define MaxEntireLineDisplay 5

void PushClientRecordString(client, String:str[512], r, g, b)
{
	//PrintToChat(client, "pushing %s", str);
	
	new iSize = GetArraySize(PlayerRecordStringEntries[client]);

	if(iSize >= MaxEntireLineDisplay)
	{
		//RemoveFromArray(PlayerRecordStringEntries[client], MaxEntireLineDisplay);
		ShiftArrayUp(PlayerRecordStringEntries[client], 0);
		
		//not iSize-1 here cause shiftarray adds 1 and isize should be isize+1 so no need to -1
		ResizeArray(PlayerRecordStringEntries[client], iSize);
		//iSize--;
	}
	else
	{
		if(iSize == 0)
			ResizeArray(PlayerRecordStringEntries[client], iSize+1);
			
		ShiftArrayUp(PlayerRecordStringEntries[client], 0);
		//ShiftArrayUp(PlayerRecordStringEntries[client], 0);
		//iSize++; //+= 2
	}
	
	//ShiftArrayUp(PlayerRecordStringEntries[client], 0);

	
	//ResizeArray(PlayerRecordStringEntries[client], iSize+1);
	SetArrayString(PlayerRecordStringEntries[client], 0, str);
	SetArrayCell(PlayerRecordStringEntries[client], 0, r, 64);
	SetArrayCell(PlayerRecordStringEntries[client], 0, g, 65);
	SetArrayCell(PlayerRecordStringEntries[client], 0, b, 66);
	
	SetArrayCell(PlayerRecordStringEntries[client], 0, 1, 67);
	
	//PushArrayString(PlayerRecordStringEntries[client], str);
	
	//PlayersRecordsString[client][0] = '\0';
	
	/*for(int i = 0;i < iSize;i++)
	{
		decl String:ArrayStringName[64];
		GetArrayString(PlayerRecordStringEntries[client], i, ArrayStringName, sizeof(ArrayStringName));
		
		PrintToChat(client, "Found %s @ %i", ArrayStringName, i);
		//Format(PlayersRecordsString[client], sizeof(PlayersRecordsString[client]), "%s%s\n", PlayersRecordsString[client], ArrayStringName);
	}*/
}

void DisplayClientTimesToSpectator(spectator, client)
{
	new iSize = GetArraySize(PlayerRecordStringEntries[client]);
	if(iSize == 0)
		return;
		
	for(int i = 0;i < iSize-1;i++)
	{
		decl String:ArrayText[64];
		GetArrayString(PlayerRecordStringEntries[client], i, ArrayText, sizeof(ArrayText));
		
		
		new r = GetArrayCell(PlayerRecordStringEntries[client], i, 64);
		new g = GetArrayCell(PlayerRecordStringEntries[client], i, 65);
		new b = GetArrayCell(PlayerRecordStringEntries[client], i, 66);
		
		ShowHudMsg(spectator, ArrayText, 0.01, 0.45 - ((i+1) * 0.03), r, g, b, 255 /* - (i * 70)*/, i+2, false);
	}
	
	//current
	ShowHudMsg(spectator, PlayersRecordsString[client], 0.01, 0.45, PlayersRecordsStringRGBforSpecs[client][0] , PlayersRecordsStringRGBforSpecs[client][1] , PlayersRecordsStringRGBforSpecs[client][2], 255, 1, false);
}

void DisplayClientPastTimes(client)
{
	new iSize = GetArraySize(PlayerRecordStringEntries[client]);
	if(iSize == 0)
		return;
		
	for(int i = 0;i < iSize-1;i++)
	{
		decl String:ArrayText[64];
		GetArrayString(PlayerRecordStringEntries[client], i, ArrayText, sizeof(ArrayText));
		
		
		new r = GetArrayCell(PlayerRecordStringEntries[client], i, 64);
		new g = GetArrayCell(PlayerRecordStringEntries[client], i, 65);
		new b = GetArrayCell(PlayerRecordStringEntries[client], i, 66);
		new flash = GetArrayCell(PlayerRecordStringEntries[client], i, 67);
		SetArrayCell(PlayerRecordStringEntries[client], i, 0, 67);
		
		ShowHudMsg(client, ArrayText, 0.01, 0.45 - ((i+1) * 0.03), r, g, b, 255/* - (i * 70)*/, i+2, flash ? true : false, true);
		
		//SetArrayString(g_NormalPlayerTimesTriggerstoTrigger[client], iSize, SequenceName);
		//SetArrayCell(g_NormalPlayerTimesTriggerstoTrigger[client], iSize, g_ClientCurrentTime[client], 12);
	}
}

public Action:Timer_CheckSpectators(Handle:timer, any:unused)
{
	for(new client = 1; client <= MaxClients; client++) 
	{ 
		if(!IsValidClient(client))
			continue;
			
		if(GetClientTeam(client) > CS_TEAM_SPECTATOR && IsPlayerAlive(client))
		{
			SpectatingPlayer[client] = -1;
		}
		else
		{
			new ObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
			if (ObserverMode == SPECMODE_FIRSTPERSON || ObserverMode == SPECMODE_3RDPERSON)
			{
				SpectatingPlayer[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
				if(SpectatingPlayer[client] != -1 && IsPlayerAlive(SpectatingPlayer[client]) && g_bWantsStageRecords[SpectatingPlayer[client]] && PreviousPlayerTrigger[SpectatingPlayer[client]] != 3000)
					DisplayClientTimesToSpectator(client, SpectatingPlayer[client]);
			}
			else
			{
				SpectatingPlayer[client] = -1;
			}
		}
	}
	
	return Plugin_Continue;
}

float GetPredictedNextTimeTriggerSequence(client)
{
	if(NextSequencePos[client] == -1)
		return -1.0;
	if(GetArraySize(g_NormalPlayerTimesTriggerstoTrigger[client]) == 0)
		return -1.0;
		
	float TimeBetweenSequences = GetArrayCell(g_NormalPlayerTimesTriggerstoTrigger[client], NextSequencePos[client], 12);
	return TimeBetweenSequences;
}

void ShowRecordOverlay(client)
{
	float PredictedNextTime = GetPredictedNextTimeTriggerSequence(client);
	//PrintToChat(client, "PredictedNext = %.2f", PredictedNextTime);
	new Float:flRed, Float:flGreen, Float:flBlue
	
	if(PredictedNextTime == -1)
	{
		flRed = 1.0; flGreen = 1.0; flBlue = 1.0;
	}
	else
	{
		//125 = green
		//0 = red,
		//map % 125 to 0 backwards.
		
		float calculated_degree = 0.0;
		
		//Get color degree
		new Float:Percentage = (g_ClientCurrentTime[client] / PredictedNextTime) * 125.0;
		
		//Remap colors to go from 125 to 0 inverse from 0 to 125;
		//calculated_degree = ( (old_value - 0) / (125 - 0) ) * (new_max - new_min) + new_min
		calculated_degree = ((Percentage * -1) + 125);
		
		//Fix it to red if too late...
		if(g_ClientCurrentTime[client] > PredictedNextTime)
			calculated_degree = 0.0;
		
		HSVtoRGB(calculated_degree, 1.0, 1.0, flRed, flGreen, flBlue);
	}
	flRed *= 255; flGreen *= 255; flBlue *= 255;
	
	decl String:TempStringWithRandomTail[512];
	TempStringWithRandomTail[0] = '\0';
	PlayersRecordsString[client][0] = '\0';
	
	Format(TempStringWithRandomTail, 512, "STAGE %i | ", g_PlayerCurrentStage[client] + 1);
	if(PredictedNextTime != -1.0)
	{
		AddTimeFormatedFromSecondsToString(TempStringWithRandomTail, PredictedNextTime, false);
		StrCat(TempStringWithRandomTail, 512, " | ");
	}
	Format(PlayersRecordsString[client], 512, "%s", TempStringWithRandomTail);
	
	AddTimeFormatedFromSecondsToString(TempStringWithRandomTail, g_ClientCurrentTime[client], true);
	AddTimeFormatedFromSecondsToString(PlayersRecordsString[client], g_ClientCurrentTime[client], false);
	
	//if(g_ClientCurrentTime[client] > PredictedNextTime)
	//{
	if(PredictedNextTime != -1.0)
	{
		float difference = PredictedNextTime - g_ClientCurrentTime[client];
		if(difference > 0)
		{
			Format(PlayersRecordsString[client], 512, "%s | + %.2f (%i ticks)", PlayersRecordsString[client], difference + 0.01, RoundToNearest((FloatAbs(difference)/GetTickInterval())));
			Format(TempStringWithRandomTail, 512, "%s | + %.1f%i (%i%i ticks)", TempStringWithRandomTail, difference + 0.01, GetRandomInt(0, 9), RoundToNearest((FloatAbs(difference)/GetTickInterval()))/10, GetRandomInt(0, 9));
		}
		else
		{
			Format(PlayersRecordsString[client], 512, "%s | - %.2f (%i ticks)", PlayersRecordsString[client], FloatAbs(difference) + 0.01, RoundToNearest((FloatAbs(difference)/GetTickInterval())));
			Format(TempStringWithRandomTail, 512, "%s | - %.1f%i (%i%i ticks)", TempStringWithRandomTail, FloatAbs(difference) + 0.01, GetRandomInt(0, 9), RoundToNearest((FloatAbs(difference)/GetTickInterval()))/10, GetRandomInt(0, 9));
		}
	}
	//}
	
	//Format(PlayersRecordsString[client], sizeof(PlayersRecordsString[client]), "%.2f : %.1f%i", PredictedNextTime, g_ClientCurrentTime[client], GetRandomInt(0, 9));
	if(g_PlayerCurrentStage[client] != ENDZONE_ENTITY_TRIGGER)
	{
		ShowHudMsg(client, TempStringWithRandomTail, 0.01, 0.45, RoundToNearest(flRed), RoundToNearest(flGreen), RoundToNearest(flBlue), 255, 1, false);
		PlayersRecordsStringRGBforSpecs[client][0] = RoundToNearest(flRed);
		PlayersRecordsStringRGBforSpecs[client][1] = RoundToNearest(flGreen);
		PlayersRecordsStringRGBforSpecs[client][2] = RoundToNearest(flBlue);
	}
	else
	{
		new iSize = GetArraySize(g_NormalPlayerTimesTriggerstoTrigger[client]);
		if(iSize != 0)
		{
			float TotalTime = 0.0;
			for(int i = 0;i < iSize;i++)
			{
				float StageTime = GetArrayCell(g_NormalPlayerTimesTriggerstoTrigger[client], i, 12);
				TotalTime+= StageTime;
			}
			decl String:TotalTimeSTR[512];
			Format(TotalTimeSTR, sizeof(TotalTimeSTR), "Total: ");
			AddTimeFormatedFromSecondsToString(TotalTimeSTR, TotalTime, false);
			ShowHudMsg(client, TotalTimeSTR, 0.01, 0.45, 0, 255, 0, 255, 1, false);
		}
	}
	PlayersRecordStringRGB[client][0] = RoundToNearest(flRed);
	PlayersRecordStringRGB[client][1] = RoundToNearest(flGreen);
	PlayersRecordStringRGB[client][2] = RoundToNearest(flBlue);
	
	//optimization
	//show only twice in a second updates on these cause they are mostly static to prevent buffer overflow
	if(g_PlayerCurrentStage[client] > 0 && GetGameTime() >= g_PlayerPastStageUpdateTime[client])
	{
		DisplayClientPastTimes(client);
		g_PlayerPastStageUpdateTime[client] = GetGameTime() + 0.5;
	}
}

void AddTimeFormatedFromSecondsToString(String:str[512], Float:totalseconds, bool RandomizeEndingDecimal)
{
	float hours = totalseconds / 3600;
	if(hours >= 1.0)
	{
		if(hours < 10.0)
			Format(str, sizeof(str), "%s0", str);
			
		Format(str, sizeof(str), "%s%i:", str, RoundToFloor(hours));
	}
	
	int minutes = RoundToFloor((totalseconds / 60)) % 60;
	if(minutes >= 1)
	{
		if(minutes < 10)
			Format(str, sizeof(str), "%s0", str);
			
		Format(str, sizeof(str), "%s%i:", str, minutes);
	}
		
	int seconds = RoundToFloor(totalseconds) % 60;
	if(seconds < 10)
		Format(str, sizeof(str), "%s0", str);
	
	if(RandomizeEndingDecimal)
		Format(str, sizeof(str), "%s%i:%.0f%i", str, seconds, ((totalseconds - RoundToFloor(totalseconds)) * 10), GetRandomInt(0, 9));
	else
	{
		float millseconds = ((totalseconds - RoundToFloor(totalseconds)) * 100);
		if(millseconds < 10.0)
			Format(str, sizeof(str), "%s%i:0%.0f", str, seconds, ((totalseconds - RoundToFloor(totalseconds)) * 100));
		else
			Format(str, sizeof(str), "%s%i:%.0f", str, seconds, ((totalseconds - RoundToFloor(totalseconds)) * 100));
	}
}

int frames = 0;

public void OnGameFrame()
{
	frames++;
	if(frames == 10)
		frames = 0;
		
	//if((frames % 10) != 0)

	//Optimization, every tick checks players 01 11 21 31 41 51 6//next tick 02 12 22 32 42 52 62
	for(new client = frames;client <= MAXPLAYERS;client+=10)
	{
		if(IsValidClient(client) && !IsFakeClient(client) && IsPlayerAlive(client) && /*g_ClientComputingTime[client] &&*/ PreviousPlayerTrigger[client] != 3000) //&& GetClientVelocity(client) > 0)
		{
			//if(g_PlayerCurrentStage[client] != -1)
				ShowRecordOverlay(client);
		}
	}
}

void ShowHudMsg(int client, char[] message, float x, float y, int r, int g, int b, int a, channel, bool flash, bool past = false)
{
	float holdtime = 0.11;
	if(past)
		if(iEngineVersion == Engine_CSS)
			holdtime = 0.51;
		else if(iEngineVersion == Engine_CSGO)
			holdtime = 0.6;
			
	//Each HudSync uses a seperate Channel for the packet to prevent displays overwriting each other
	if(channel == 1)
	{
		static Handle hudSync;
		if(hudSync == null)
			hudSync = CreateHudSynchronizer();
		
		if(flash)
			SetHudTextParams(x, y, holdtime, r, g, b, a, 2, 0.5, 0.0, 0.0);
		else
			SetHudTextParams(x, y, holdtime, r, g, b, a, 0, 0.0, 0.0, 0.0);
			
		ShowSyncHudText(client, hudSync, message);
	}
	else if(channel == 2)
	{
		static Handle hudSync;
		if(hudSync == null)
			hudSync = CreateHudSynchronizer();
		
		if(flash)
			SetHudTextParams(x, y, holdtime, r, g, b, a, 2, 0.5, 0.0, 0.0);
		else
			SetHudTextParams(x, y, holdtime, r, g, b, a, 0, 0.0, 0.0, 0.0);
			
		ShowSyncHudText(client, hudSync, message);
	}
	else if(channel == 3)
	{
		static Handle hudSync;
		if(hudSync == null)
			hudSync = CreateHudSynchronizer();
		
		if(flash)
			SetHudTextParams(x, y, holdtime, r, g, b, a, 2, 0.5, 0.0, 0.0);
		else
			SetHudTextParams(x, y, holdtime, r, g, b, a, 0, 0.0, 0.0, 0.0);
			
		ShowSyncHudText(client, hudSync, message);
	}
	else if(channel == 4)
	{
		static Handle hudSync;
		if(hudSync == null)
			hudSync = CreateHudSynchronizer();
		
		if(flash)
			SetHudTextParams(x, y, holdtime, r, g, b, a, 2, 0.5, 0.0, 0.0);
		else
			SetHudTextParams(x, y, holdtime, r, g, b, a, 0, 0.0, 0.0, 0.0);
			
		ShowSyncHudText(client, hudSync, message);
	}
	else if(channel == 5)
	{
		static Handle hudSync;
		if(hudSync == null)
			hudSync = CreateHudSynchronizer();
		
		if(flash)
			SetHudTextParams(x, y, holdtime, r, g, b, a, 2, 0.5, 0.0, 0.0);
		else
			SetHudTextParams(x, y, holdtime, r, g, b, a, 0, 0.0, 0.0, 0.0);
			
		ShowSyncHudText(client, hudSync, message);
	}
	else if(channel == 6)
	{
		static Handle hudSync;
		if(hudSync == null)
			hudSync = CreateHudSynchronizer();
		
		if(flash)
			SetHudTextParams(x, y, holdtime, r, g, b, a, 2, 0.5, 0.0, 0.0);
		else
			SetHudTextParams(x, y, holdtime, r, g, b, a, 0, 0.0, 0.0, 0.0);
			
		ShowSyncHudText(client, hudSync, message);
	}
}

public OnStyleChanged(client, OldStyle, NewStyle, Type)
{
	if(client > -1 && client <= MAXPLAYERS+1)
	{
		if(!g_bWantsStageRecords[client])
			return;
			
		if(Type == 0) //Normal
		{
			ResetPlayerCurrentRun(client);
		}
		else if(Type == 1) //Bonus
		{
			ResetPlayerCurrentRun(client);
			g_ClientComputingTime[client] = false; //Not Supported Yet.
		}
	}
}

public OnTimerStart_Post(client, Type, Style)
{
	if(client > -1 && client <= MAXPLAYERS+1)
	{
		if(!g_bWantsStageRecords[client])
			return;
			
		if(Type == 0) //Normal
		{
			ResetPlayerCurrentRun(client);
		}
		else if(Type == 1) //Bonus
		{
			ResetPlayerCurrentRun(client);
			g_ClientComputingTime[client] = false; //Not Supported Yet.
		}
	}
}

public OnTimerFinished_Post(client, Float:Time, Type, Style, bool:NewTime, OldPosition, NewPosition)
{
	if(!g_bWantsStageRecords[client])
		return;
		
	EndRunOnStage(client, Type);
}

float GetClientVelocity(client)
{
	new Float:vVel[3];
	
	vVel[0] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[0]");
	vVel[1] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[1]");
	vVel[2] = GetEntPropFloat(client, Prop_Send, "m_vecVelocity[2]");
	
	return GetVectorLength(vVel);
}

HSVtoRGB(&Float:h, Float:s, Float:v, &Float:r, &Float:g, &Float:b)
{
	if(h > 360.0) h -= 360.0
	else if(h < 0.0) h += 360.0
	
	if (s == 0)
	{
		r = v;g = v;b = v;
	}
	else
	{
		new Float:fHue, Float:fValue, Float:fSaturation;
		new i;  new Float:f;  new Float:p,Float:q,Float:t;
		if (h == 360.0) h = 0.0;
		fHue = h / 60.0;
		i = RoundToFloor(fHue);
		f = fHue - i;
		fValue = v;
		fSaturation = s;
		p = fValue * (1.0 - fSaturation);
		q = fValue * (1.0 - (fSaturation * f));
		t = fValue * (1.0 - (fSaturation * (1.0 - f)));
		switch (i)
		{
		   case 0: {r = fValue; g = t; b = p;}
		   case 1: {r = q; g = fValue; b = p; }
		   case 2: {r = p; g = fValue; b = t;}
		   case 3: {r = p; g = q; b = fValue;}
		   case 4: {r = t; g = p; b = fValue;}
		   case 5: {r = fValue; g = p; b = q; }
		}
	}
}