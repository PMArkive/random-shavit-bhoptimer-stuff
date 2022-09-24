
#include <sourcemod>
#include <shavit/replay-file>
#include <shavit/replay-stocks.sp>

void writeframe(File fout, int changed, any[] frame, int framesize)
{
	for (int asdf = 0; asdf < framesize; asdf++) {
		if (changed & (1 << asdf))
			fout.WriteInt32(frame[asdf]);
	}
}

void writeframediff(File fout, any[] oldframe, any[] newframe, int framesize)
{
	int changed = 0;
	for (int asdf = 0; asdf < framesize; asdf++) {
		if (newframe[asdf] != oldframe[asdf])
			changed |= (1 << asdf);
	}
	fout.WriteInt16(changed);
	writeframe(fout, changed, newframe, framesize);
}

public void OnPluginStart()
{
	char replayfolder[PLATFORM_MAX_PATH];
	Shavit_GetReplayFolderPath_Stock(replayfolder);

	char replayfile[PLATFORM_MAX_PATH];
	Shavit_GetReplayFilePath(0, 0, "bhop_badges", replayfolder, replayfile);

	frame_cache_t cache;
	LoadReplayCache(cache, 0, 0, replayfile, "bhop_badges");

	File fout = OpenFile("test.replay", "wb");

	int totalframes = cache.iFrameCount+cache.iPreFrames+cache.iPostFrames;

	WriteReplayHeader(fout, 0, 0, cache.fTime, cache.iSteamID, cache.iPreFrames, cache.iPostFrames, view_as<float>({0.0,0.0}), totalframes, cache.fTickrate, "bhop_badges");

	frame_t oldframe;
	cache.aFrames.GetArray(0, oldframe);
	fout.WriteInt16(0x1FF);
	writeframe(fout, -1, oldframe, sizeof(frame_t));

	for (int i = 1; i < totalframes; i++) {
		frame_t newframe;
		cache.aFrames.GetArray(i, newframe);
		writeframediff(fout, oldframe, newframe, sizeof(frame_t));
		oldframe = newframe;
	}

	delete fout;
}
