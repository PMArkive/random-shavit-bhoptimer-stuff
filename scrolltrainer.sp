#include <sourcemod>
#include <clientprefs>

// plugin name: 
//            scrol trainer v1.0
// coded by: 
//            me
// 16/5/2009
// fuck you
// (do not steal)

const int bufsize = 20;
bool buf[MAXPLAYERS+1][bufsize];
int perf[MAXPLAYERS+1];
char thingy[MAXPLAYERS+1][bufsize+3];
int bufiter[MAXPLAYERS+1];
int buftimer[MAXPLAYERS+1];
bool pgrounded[MAXPLAYERS+1];
int showmsgtimer[MAXPLAYERS+1];
bool scrolltrainer[MAXPLAYERS+1] = {false, ...};
Handle scrolltrainercookie;

public bool OnClientConnect(client, String:rejectmsg[], int mlmlm){
    for (int i = 0; i < bufsize; i++){
        buf[client][i] = false;
    }
    perf[client] = 0;
    bufiter[client] = 0;
    buftimer[client] = 11;
    pgrounded[client] = true;
    showmsgtimer[client] = 201;

    return true;
}

public void OnPluginStart(){
	RegConsoleCmd("sm_scrolltrainer", Command_ScrollTrainer, "Toggles the Scroll trainer.");
	
	scrolltrainercookie = RegClientCookie("scrolltrainer_enabled", "scrolltrainer_enabled", CookieAccess_Protected);
	
	// Late loading
	for(int i = 1; i <= MaxClients; i++)
	{
		if(AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}
}

public void OnClientCookiesCached(int client)
{
    char cookie[8];
	GetClientCookie(client, scrolltrainercookie, cookie, sizeof(cookie));
	
	scrolltrainer[client] = (cookie[0] != '\0' && StringToInt(cookie));
}

void makethingy(int client){
    thingy[client][0] = '\0';

    for (int i = bufsize; i < bufsize+bufsize; i++){
        if (i == bufsize+9 || i == bufsize+10){
            StrCat(thingy[client],bufsize+3,"|");
        }
        if (buf[client][(bufiter[client]+i)%bufsize]){
            StrCat(thingy[client],bufsize+3,"+");
        } else {
            StrCat(thingy[client],bufsize+3,"-");
        }
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]){
    if (IsFakeClient(client) || !IsPlayerAlive(client) || !scrolltrainer[client]){
        return Plugin_Continue;
    }

    buf[client][bufiter[client]] = !!((buttons>>1)&1);
    bufiter[client] = (bufiter[client] + 1) % bufsize;

    MoveType mtMoveType = GetEntityMoveType(client);
    bool bInWater = (GetEntProp(client, Prop_Send, "m_nWaterLevel") >= 2);
	int iGroundEntity = GetEntPropEnt(client, Prop_Send, "m_hGroundEntity");
    bool grounded = (!bInWater && mtMoveType == MOVETYPE_WALK && iGroundEntity != -1);

    if (grounded && !pgrounded[client]){
        buftimer[client] = 0;
    }
    if (buftimer[client] == 1){
        perf[client]     = !grounded;
    }
    pgrounded[client] = grounded;

    if (buftimer[client] == 10){
        showmsgtimer[client] = 0;
        makethingy(client);
    }

    if (!(showmsgtimer[client] % 10)){
        Handle hText = CreateHudSynchronizer();

        if (hText != INVALID_HANDLE){
            SetHudTextParams(-1.0, 0.2, 0.15, 255-(perf[client]*255), perf[client]*255, 0, 255, 0, 0.0, 0.0, 0.1);
            ShowSyncHudText(client, hText, thingy[client]);
            
            CloseHandle(hText);
        }
    }
    if (buftimer[client] > 10){buftimer[client] = 11;}
    if (showmsgtimer[client] > 200){showmsgtimer[client] = 201;}

    buftimer[client]++;
    showmsgtimer[client]++;

    return Plugin_Continue;
}

public Action Command_ScrollTrainer(int client, int args){
    if (client != 0)
    	{
    		scrolltrainer[client] = !scrolltrainer[client];

            char cookie[8];
	        IntToString(scrolltrainer[client], cookie, sizeof(cookie));
	        SetClientCookie(client, scrolltrainercookie, cookie);

    		ReplyToCommand(client, "scroll trainer %s..", scrolltrainer[client] ? "enabled" : "disabled");

            if (!scrolltrainer[client]){
                return Plugin_Handled;
            }
            
            Handle hText = CreateHudSynchronizer();
            SetHudTextParams(-1.0, 0.2, 2.0, 255, 0, 255, 255, 0, 0.0, 0.0, 0.1);
            ShowSyncHudText(client, hText, "hii :)) ♥♥ welcome to scrolltrainer!! ♥ btw if you put 2 + in arow it doesnt count.");
    	}
        
    	return Plugin_Handled;
}