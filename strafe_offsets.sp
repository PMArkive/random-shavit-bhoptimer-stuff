/*  Oryx AC: collects and analyzes statistics to find some cheaters in CS:S bhop
 *  Copyright (C) 2018  Nolan O.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <sourcemod>
/* #include <smlib/entities>
#include <smlib/clients>
#include <oryx>
#if defined bTimes
#include <bTimes-timer>
#include <bTimes-core>
#endif */

public Plugin:myinfo = 
{
    name = "Strafe offset helper",
    author = "Rusty",
    description = ": ~ )",
    version = "1.0",
    url = ""
}

int g_keyTransTick[MAXPLAYERS];
int g_angTransTick[MAXPLAYERS];
int g_strafeHist[MAXPLAYERS][30];
int g_strafeHistIdx[MAXPLAYERS];
bool g_keyChanged[MAXPLAYERS];
bool g_dirChanged[MAXPLAYERS];
bool g_suffBashData[MAXPLAYERS];
bool g_notifying[MAXPLAYERS];

public OnPluginStart()
{
    RegConsoleCmd("sm_show_transitions", Command_ToggleStrafeStats);
    RegConsoleCmd("sm_dump_transitions", Command_PrintStrafeStats);
    RegConsoleCmd("sm_show_offsets", Command_ToggleStrafeStats);
    RegConsoleCmd("sm_dump_offsets", Command_PrintStrafeStats);
    
    //BuildPath(Path_SM, logpath, sizeof(logpath), "logs/oryx-strafe-stats.log");
}

public bool OnClientConnect(int client, char[] rejectmsg, int maxlen)
{
	g_notifying[client] = false

    g_keyTransTick[client] = 0;
    g_angTransTick[client] = 0;
    g_keyChanged[client] = false;
    g_dirChanged[client] = false;
    g_suffBashData[client] = false;
    g_strafeHistIdx[client] = 0;
    for(int i=0; i<30; i++)
    {
        g_strafeHist[client][i] = 0;
    }
    
    return true;
}

public Action Command_PrintStrafeStats(int client, int args)
{
    if(g_suffBashData[client])
        PrintToConsole(client, FormatStrafeStats(client));
    else
        PrintToChat(client, "You don't not have sufficient strafe data yet!");
    return Plugin_Handled;
}

public Action Command_ToggleStrafeStats(int client, int args)
{
	g_notifying[client] = !g_notifying[client]
	if ( g_notifying[client] == true ) {
		PrintToConsole(client, "You'll now see your bash stats in real time");
		PrintToConsole(client, "Negative means your key transition happened before your mouse transition");
	}

    return Plugin_Handled;
}

char[] FormatStrafeStats(int target)
{
    decl String:name[64];
    GetClientName(target, name, sizeof(name));
    
    decl String:statStr[150];
    Format(statStr, sizeof(statStr), "\n\nSTRAFE STATS FOR:\n%s\n%d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",
        name,
        g_strafeHist[target][0],
        g_strafeHist[target][1],
        g_strafeHist[target][2],
        g_strafeHist[target][3],
        g_strafeHist[target][4],
        g_strafeHist[target][5],
        g_strafeHist[target][6],
        g_strafeHist[target][7],
        g_strafeHist[target][8],
        g_strafeHist[target][9],
        g_strafeHist[target][10],
        g_strafeHist[target][11],
        g_strafeHist[target][12],
        g_strafeHist[target][13],
        g_strafeHist[target][14],
        g_strafeHist[target][15],
        g_strafeHist[target][16],
        g_strafeHist[target][17],
        g_strafeHist[target][18],
        g_strafeHist[target][19],
        g_strafeHist[target][20],
        g_strafeHist[target][21],
        g_strafeHist[target][22],
        g_strafeHist[target][23],
        g_strafeHist[target][24],
        g_strafeHist[target][25],
        g_strafeHist[target][26],
        g_strafeHist[target][27],
        g_strafeHist[target][28],
        g_strafeHist[target][29]);
    return statStr;
}

public Action OnPlayerRunCmd(client, &buttons, &impulse, float vel_w[3], float angles[3])
{
    static float fPrevAng[MAXPLAYERS], fPrevDtAng[MAXPLAYERS], _fPrevDtAng[MAXPLAYERS];
    static int absTicks[MAXPLAYERS], iPrevButtons[MAXPLAYERS];
    //static AngDir angDir;
    
    if(!IsClientInGame(client) || !IsPlayerAlive(client) || IsFakeClient(client))
        return Plugin_Continue;
    
    absTicks[client]++;

    float _dtAng = angles[1] - fPrevAng[client];
    if (_dtAng > 180)
        _dtAng -= 360;
    else if(_dtAng < -180)
        _dtAng += 360;
    float dtAng = FloatAbs(_dtAng);
    
    if(dtAng < 1/64)
        return Plugin_Continue;
    
    /*
    * BASH remake
    * Some of the logic may seem redundant, but it probably isn't.
    */
    if(!(GetEntityFlags(client) & FL_ONGROUND))
    {
        if(!(buttons & IN_MOVERIGHT && buttons & IN_MOVELEFT))
        {
            if(buttons & IN_MOVELEFT){
                if((iPrevButtons[client] & IN_MOVERIGHT && iPrevButtons[client] & IN_MOVELEFT) || !(iPrevButtons[client] & IN_MOVELEFT))
                {
                    g_keyChanged[client] = true;
                    g_keyTransTick[client] = absTicks[client];
                }
            }
            else if(buttons & IN_MOVERIGHT){
                if((iPrevButtons[client] & IN_MOVERIGHT && iPrevButtons[client] & IN_MOVELEFT) || !(iPrevButtons[client] & IN_MOVERIGHT))
                {
                    g_keyChanged[client] = true;
                    g_keyTransTick[client] = absTicks[client];
                }
            }
        }
        if(dtAng != 0.0 && ((_dtAng < 0.0 && _fPrevDtAng[client] > 0.0) || (_dtAng > 0.0 && _fPrevDtAng[client] < 0.0) || fPrevDtAng[client] == 0.0))
        {
            if(!g_dirChanged[client])
            {
                g_dirChanged[client] = true;
                g_angTransTick[client] = absTicks[client];
            }
        }
        
        if(g_keyChanged[client] && g_dirChanged[client])
        {
            g_keyChanged[client] = false;
            g_dirChanged[client] = false;
            int t = g_keyTransTick[client] - g_angTransTick[client];
            //Chop off anything greater than 25 ticks of error
            if(t > -26 && t < 26)
            {
                g_strafeHist[client][g_strafeHistIdx[client]] = t;
                g_strafeHistIdx[client]++;

				if (g_notifying[client]) {
					PrintToChat(client, "%d", t)
				}
            }
        }
        
        if(!g_suffBashData[client])
            if(g_strafeHistIdx[client] == 30)
                g_suffBashData[client] = true;
        if(g_strafeHistIdx[client] == 30)
            g_strafeHistIdx[client] = 0;
    }
    else
    {
        g_keyChanged[client] = false;
        g_dirChanged[client] = false;
    }

    iPrevButtons[client] = buttons;
    fPrevAng[client] = angles[1];
    fPrevDtAng[client] = dtAng;
    _fPrevDtAng[client] = _dtAng;

    return Plugin_Continue;
}
