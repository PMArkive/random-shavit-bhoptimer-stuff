
#include <shavit/maps-folder-stocks>

stock void LowercaseString(char[] str)
{
	int i, x;
	while ((x = str[i]) != 0)
	{
		if ('A' <= x <= 'Z')
			str[i] += ('a' - 'A');
		++i;
	}
}

public void OnPluginStart()
{
	ArrayList maps = new ArrayList(ByteCountToCells(PLATFORM_MAX_PATH));
	ReadMapsFolderArrayList(maps);

	File f = OpenFile("mapsfolder.txt", "w+");

	int length = maps.Length;
	for (int i = 0; i < length; i++)
	{
		char entry[PLATFORM_MAX_PATH];
		maps.GetString(i, entry, sizeof(entry));
		f.WriteLine("%s", entry);
	}

	delete f;
	delete maps;
}