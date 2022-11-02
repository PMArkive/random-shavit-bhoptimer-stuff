/*

	"tf"
	{
		"Offsets"
		{
			// https://asherkin.github.io/vtable/
			"CTFGameMovement::CheckJumpButton"
			{
				"windows"   "29"
				"linux"     "30"
			}
		}
	}
*/

int gI_ClientProcessingMovement = 0;

void loaddhooks()
{
	// ....

	if (gEV_Type == Engine_TF2)
	{
		if (-1 == (offset = GameConfGetOffset(gamedataConf, "CTFGameMovement::CheckJumpButton")))
		{
			SetFailState("Failed to get CTFGameMovement::CheckJumpButton offset");
		}

		Handle checkJumpButton = DHookCreate(offset, HookType_Raw, ReturnType_Bool, ThisPointer_Ignore, DHook_CheckJumpButton);
		DHookRaw(checkJumpButton, true, IGameMovement);
	}

	// ....
}

public MRESReturn DHook_CheckJumpButton(DHookReturn hReturn)
{
	if (!IsFakeClient(gI_ClientProcessingMovement))
	{
		PrintToServer("hello %d", hReturn.Value);
		if (hReturn.Value == true)
		{
			DoJump(gI_ClientProcessingMovement);
		}
	}

	return MRES_Ignored;
}

public MRESReturn DHook_ProcessMovement(Handle hParams)
{
	int client = DHookGetParam(hParams, 1);
	gI_ClientProcessingMovement = client;

	// ...
}
