native void SRCWR_Util_HardlinkNavs(const char[] mapsfolder);

public void OnPluginStart()
{
	SRCWR_Util_HardlinkNavs("asdf");
}