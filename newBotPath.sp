#include <sdktools>
#include <bTimes-core>
#include <bTimes-timer>
#include <bTimes-replay3>


// 总体思路
// 1.循环array总长, 在循环里 判断某一tick是否在地上, 在则以该tick的origin为原点, x y轴 ± 36(玩家的bounding box) 还需要判断两点间的距离是否超过 100 (50会更好点?)
// 2.每过1秒更新一次

char g_sMapName[64];

// Replay related
ArrayList g_Replay_Data[MAX_TYPES][MAX_STYLES][2];
int g_Replay_TimeFramesCount[MAX_TYPES][MAX_STYLES][2];
float g_Replay_Time[MAX_TYPES][MAX_STYLES][2];
int g_Replay_TimerStartEndTicks[MAX_TYPES][MAX_STYLES][2][2];

// Path related
//ArrayList g_Path_Data[MAX_TYPES][MAX_STYLES][2];
int g_iPathFrame[MAXPLAYERS + 1];
int g_iPathTexture;
float g_flClientLastPos[MAXPLAYERS + 1][3];
bool g_bFinishedDrawing[MAXPLAYERS + 1];

// Client settings related
bool g_bShowPath[MAXPLAYERS + 1];
//bool      g_bShowCompletion[MAXPLAYERS + 1];
int g_iSetting_Type[MAXPLAYERS + 1];
int g_iSetting_Style[MAXPLAYERS + 1];
int g_iSetting_Tas[MAXPLAYERS + 1];

public void OnPluginStart()
{
	for (int type; type < MAX_TYPES; type++)
	for (int style; style < MAX_STYLES; style++)
	for (int tas; tas < 2; tas++)
	g_Replay_Data[type][style][tas] = new ArrayList(REPLAY_FRAME_SIZE);
	
	RegConsoleCmdEx("sm_showpath", Command_ShowPath, "Show the route of WR bot");
	RegConsoleCmdEx("sm_path", Command_ShowPath, "Show the route of WR bot");
	RegConsoleCmdEx("sm_botpath", Command_ShowPath, "Show the route of WR bot");
	RegConsoleCmdEx("sm_showbotpath", Command_ShowPath, "Show the route of WR bot");
	RegConsoleCmdEx("sm_showroute", Command_ShowPath, "Show the route of WR bot");
}

public Action Command_ShowPath(int client, int args)
{
	if (!client)return Plugin_Handled;
	
	g_bShowPath[client] = !g_bShowPath[client];
	SayText2(client, "\x07FFFFFFShowPath: \x04 %s", g_bShowPath[client] ? "On" : "Off");
	
	return Plugin_Handled;
}

public void OnMapStart()
{
	GetCurrentMap(g_sMapName, sizeof(g_sMapName));
	LoadReplayData();
	//CreateTimer(1.0, Timer_ShowPath, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	
	g_iPathTexture = PrecacheModel("materials/sprites/laserbeam.vmt");
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		g_bShowPath[client] = true;
		g_iSetting_Type[client] = 0;
		g_iSetting_Style[client] = 0;
		g_iSetting_Tas[client] = 0;
		g_iPathFrame[client] = 0;
		g_bFinishedDrawing[client] = false;
	}
}

void LoadReplayData()
{
	char sPath[PLATFORM_MAX_PATH];
	any data[REPLAY_FRAME_SIZE];
	for (int type; type < MAX_TYPES; type++)
	{
		for (int style; style < MAX_STYLES; style++)
		{
			for (int tas; tas < 2; tas++)
			{
				if (Style(style).GetUseGhost(type))
				{
					g_Replay_Data[type][style][tas].Clear();
					g_Replay_Time[type][style][tas] = 0.0;
					g_Replay_TimeFramesCount[type][style][tas] = 0;
					
					BuildPath(Path_SM, sPath, sizeof(sPath), "data/btimes/%s_%d_%d_%d.txt", g_sMapName, type, style, tas);
					PrintToServer("Replay file loaded! Type:%d Style:%d Tas:%d", type, style, tas);
					
					if (FileExists(sPath))
					{
						// Open file for reading
						File file = OpenFile(sPath, "rb");
						
						// Read first line for player and time information
						any header[2];
						file.Read(header, 2, 4);
						
						// Decode line into needed information
						g_Replay_Time[type][style][tas] = header[1];
						
						// Read rest of file
						bool timerStarted, completed;
						while (!file.EndOfFile())
						{
							file.Read(data, REPLAY_FRAME_SIZE, 4);
							g_Replay_Data[type][style][tas].PushArray(data, REPLAY_FRAME_SIZE);
							if (data[REPLAY_DATA_BTN] & IN_BULLRUSH && completed == false)
							{
								if (timerStarted == false)
								{
									timerStarted = true;
									g_Replay_TimerStartEndTicks[type][style][tas][0] = g_Replay_Data[type][style][tas].Length - 1;
								}
								else
								{
									g_Replay_TimerStartEndTicks[type][style][tas][1] = g_Replay_Data[type][style][tas].Length - 1;
									timerStarted = false;
									completed = true;
								}
							}
							
							if (timerStarted)
							{
								g_Replay_TimeFramesCount[type][style][tas]++;
							}
						}
						
						if (!completed)
						{
							// Set first tick to IN_BULLRUSH to initate timer start
							SetArrayCell(g_Replay_Data[type][style][tas], 0, GetArrayCell(g_Replay_Data[type][style][tas], 0, REPLAY_DATA_BTN) | IN_BULLRUSH, REPLAY_DATA_BTN);
							g_Replay_TimerStartEndTicks[type][style][tas][0] = 0;
							
							// Set last tick to IN_BULLRUSH to initiate timer finish
							SetArrayCell(g_Replay_Data[type][style][tas], g_Replay_Data[type][style][tas].Length - 1, GetArrayCell(g_Replay_Data[type][style][tas], g_Replay_Data[type][style][tas].Length - 1, REPLAY_DATA_BTN) | IN_BULLRUSH, REPLAY_DATA_BTN);
							g_Replay_TimerStartEndTicks[type][style][tas][1] = g_Replay_Data[type][style][tas].Length - 1;
							
							// Set number of ticks the player had a timer for in their run
							g_Replay_TimeFramesCount[type][style][tas] = g_Replay_Data[type][style][tas].Length;
						}
						delete file;
						
					}
				}
			}
		}
	}
}

int FindClosestNodeToPlayer(int client)
{
	int iLength = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Length;
	
	int iLastGoodNode = -1;
	float vPos[3], vPlayerPos[3], flLastBestDistance = 500.1;
	GetClientAbsOrigin(client, vPlayerPos);
	
	for (int i = 0; i < iLength; i++)
	{
		vPos[0] = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Get(i, 0);
		vPos[1] = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Get(i, 1);
		vPos[2] = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Get(i, 2);
		
		float flDistance = GetVectorDistance(vPlayerPos, vPos);
		
		if (flDistance < flLastBestDistance && flDistance != 0.0)
		{
			flLastBestDistance = flDistance;
			iLastGoodNode = i;
		}
	}
	
	if (flLastBestDistance > 500.0)
		return -1;
	
	return iLastGoodNode;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (!IsFakeClient(client) && IsPlayerAlive(client) && g_bShowPath[client])
	{
		static float vPos[3], vLastPos[3];
		static int color[4] =  { 255, 128, 255, 255 };
		int iLength = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Length;
		
		int tpye = g_iSetting_Type[client];
		int style = g_iSetting_Style[client];
		int tas = g_iSetting_Tas[client];
		
		static int iFlags;
		static int iLastFlags;
		
		if (!g_bFinishedDrawing[client])
		{
			//if(g_iPathFrame[client] + 2 >= iLength)
			//g_bFinishedDrawing[client] = true;
			
			if (g_iPathFrame[client] < 0 || g_iPathFrame[client] + 2 >= iLength)
				g_iPathFrame[client] = 0;
			
			iFlags = g_Replay_Data[tpye][style][tas].Get(g_iPathFrame[client], REPLAY_DATA_FLG);
			
			if ((iFlags & FL_ONGROUND) && !(iLastFlags & FL_ONGROUND))
			{
				PrintToServer("g_iPathFrame[client]: %i -- OnGround.", g_iPathFrame[client]);
				vPos[0] = g_Replay_Data[tpye][style][tas].Get(g_iPathFrame[client], 0);
				vPos[1] = g_Replay_Data[tpye][style][tas].Get(g_iPathFrame[client], 1);
				vPos[2] = g_Replay_Data[tpye][style][tas].Get(g_iPathFrame[client], 2);
				CreateBeamForClient(client, vLastPos, vPos, color, 60.0);
			}
			else if (!(iFlags & FL_ONGROUND) && (iLastFlags & FL_ONGROUND))
			{
				PrintToServer("g_iPathFrame[client]: %i -- InAir.", g_iPathFrame[client]);
				
				vLastPos[0] = g_Replay_Data[tpye][style][tas].Get(g_iPathFrame[client] - 1, 0);
				vLastPos[1] = g_Replay_Data[tpye][style][tas].Get(g_iPathFrame[client] - 1, 1);
				vLastPos[2] = g_Replay_Data[tpye][style][tas].Get(g_iPathFrame[client] - 1, 2);
			}
			
			iLastFlags = iFlags;
			
			PrintToServer("vLastPos[0]: %.2f vLastPos[1]: %.2f vLastPos[2]: %.2f \n vPos[0]: %.2f vPos[1]: %.2f vPos[2]: %.2f \n \n", vLastPos[0], vLastPos[1], vLastPos[2], vPos[0], vPos[1], vPos[2]);
			
			g_flClientLastPos[client] = vPos;
			if (GetVectorDistance(g_flClientLastPos[client], vPos) > 2500.0)
			{
				g_iPathFrame[client] = FindClosestNodeToPlayer(client);
			}
			g_iPathFrame[client]++;
			
		}
		//PrintToServer("g_iPathFrame[client]: %i, iLength:%i, FinishedDrawing: %s ", g_iPathFrame[client], iLength, g_bFinishedDrawing[client] ? "True" : "False");
		
	}
	
}

/*public Action Timer_ShowPath(Handle hTimer, any data)
{
    if(g_iPathFrame == -1)
        return Plugin_Stop;
    float vPos[3], vLastPos[3];

    for(int client = 1; client <= MaxClients; client++)
    {
        int iLength = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Length;

        if(!IsClientInGame(client) || IsFakeClient(client) || !IsPlayerAlive(client) || !g_bShowPath[client])
            continue;

        for(int i = 0; i < iLength; i++)
        {
            vPos[0] = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Get(i, 0);
            vPos[1] = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Get(i, 1);
            vPos[2] = g_Replay_Data[g_iSetting_Type[client]][g_iSetting_Style[client]][g_iSetting_Tas[client]].Get(i, 2);

            CreateBeamForClient(client, vLastPos, vPos);
            
            vLastPos = vPos;
            g_iPathFrame++;
            PrintToServer("PathFrame: %i; i: %i", g_iPathFrame, i);

        }
    }
    return Plugin_Continue;
}*/

void CreateBeamForClient(int client, const float p1[3], const float p2[3], int color[4], float litetime = 1.0)
{
	TE_SetupBeamPoints(p1, p2, g_iPathTexture, g_iPathTexture, 0, 0, litetime, 1.0, 1.0, 10, 0.0, color, 0);
	TE_SendToClient(client);
}

public void OnTimerFinished_Post(int client, float Time, int Type, int style, int jumps, int strafes, float sync, bool tas, bool NewTime, int OldPosition, int NewPosition, float fOldTime, float fOldWRTime)
{
	if (NewTime)
	{
		if (NewPosition == 1)
		{
			LoadReplayData();
		}
	}
}

/*stock GetGroundOrigin(client, Float:pos[3])
{
	decl Float:fOrigin[3], Float:result[3];
	GetClientAbsOrigin(client, fOrigin);
	TraceClientGroundOrigin(client, result, 100.0);
	pos = fOrigin;
	pos[2] = result[2];
}

stock TraceClientGroundOrigin(client, Float:result[3], Float:offset)
{
	decl Float:temp[2][3];
	GetClientEyePosition(client, temp[0]);
	temp[1] = temp[0];
	temp[1][2] -= offset;
	new Float:mins[] ={-16.0, -16.0, 0.0};
	new Float:maxs[] =	{16.0, 16.0, 60.0};
	new Handle:trace = TR_TraceHullFilterEx(temp[0], temp[1], mins, maxs, MASK_SHOT, TraceEntityFilterPlayer);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(result, trace);
		CloseHandle(trace);
		return 1;
	}
	CloseHandle(trace);
	return 0;
}

public bool:TraceEntityFilterPlayer(entity, contentsMask)
{
    return entity > MaxClients;
}*/

stock SayText2(to, const String:message[], any:...)
{
	new Handle:hBf = StartMessageOne("SayText2", to, USERMSG_RELIABLE);
	if (!hBf)return;
	decl String:buffer[1024];
	VFormat(buffer, sizeof(buffer), message, 3);
	BfWriteByte(hBf, to);
	BfWriteByte(hBf, true);
	BfWriteString(hBf, buffer);
	EndMessage();
} 