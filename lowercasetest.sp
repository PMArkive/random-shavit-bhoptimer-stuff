#include <profiler>

void LowercaseString1(char[] str)
{
	for (int i = 0; str[i] != 0; i++)
	{
		char x = str[i];
		if ('A' <= x <= 'Z')
			x += ('a' - 'A');
		str[i] = x;
	}
}

void LowercaseString2(char[] str)
{
	static char to_lowercase_table[256+1] = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x3E\x3F\x40\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x5B\x5C\x5D\x5E\x5F\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x7B\x7C\x7D\x7E\x7F\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8A\x8B\x8C\x8D\x8E\x8F\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9A\x9B\x9C\x9D\x9E\x9F\xA0\xA1\xA2\xA3\xA4\xA5\xA6\xA7\xA8\xA9\xAA\xAB\xAC\xAD\xAE\xAF\xB0\xB1\xB2\xB3\xB4\xB5\xB6\xB7\xB8\xB9\xBA\xBB\xBC\xBD\xBE\xBF\xC0\xC1\xC2\xC3\xC4\xC5\xC6\xC7\xC8\xC9\xCA\xCB\xCC\xCD\xCE\xCF\xD0\xD1\xD2\xD3\xD4\xD5\xD6\xD7\xD8\xD9\xDA\xDB\xDC\xDD\xDE\xDF\xE0\xE1\xE2\xE3\xE4\xE5\xE6\xE7\xE8\xE9\xEA\xEB\xEC\xED\xEE\xEF\xF0\xF1\xF2\xF3\xF4\xF5\xF6\xF7\xF8\xF9\xFA\xFB\xFC\xFD\xFE\xFF";

	for (int i = 0; str[i] != 0; i++)
	{
		int x = str[i];
		str[i] = to_lowercase_table[x];
	}
}

void LowercaseString3(char[] str)
{
	for (int i = 0; str[i] != 0; i++)
		if ('A' <= str[i] <= 'Z')
			str[i] += ('a' - 'A');
}

void LowercaseString4(char[] str)
{
	int i = 0;
	char x;
	while ((x = str[i]) != 0)
	{
		if ('A' <= x <= 'Z')
			str[i] += ('a' - 'A');
		++i;
	}
}

void LowercaseString5(char[] str)
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
	Profiler profiler = new Profiler();

	profiler.Start();
	for (int i = 1; i <= 5; i++)
	{
		i += i;
	}
	profiler.Stop();

	float t0 = profiler.Time;

	profiler.Start();
	for (int i = 0; i < 500000; i++)
	{
		char s[32] = "1j98Sd9nu189JSQ2SDv2sqqwe";
		LowercaseString1(s);
	}
	profiler.Stop();

	float t1 = profiler.Time;

	profiler.Start();
	for (int i = 0; i < 500000; i++)
	{
		char s[32] = "1j98Sd9nu189JSQ2SDv2sqqwe";
		LowercaseString2(s);
	}
	profiler.Stop();

	float t2 = profiler.Time;

	profiler.Start();
	for (int i = 0; i < 500000; i++)
	{
		char s[32] = "1j98Sd9nu189JSQ2SDv2sqqwe";
		LowercaseString3(s);
	}
	profiler.Stop();

	float t3 = profiler.Time;

	profiler.Start();
	for (int i = 0; i < 500000; i++)
	{
		char s[32] = "1j98Sd9nu189JSQ2SDv2sqqwe";
		LowercaseString4(s);
	}
	profiler.Stop();

	float t4 = profiler.Time;

	profiler.Start();
	for (int i = 0; i < 500000; i++)
	{
		char s[32] = "1j98Sd9nu189JSQ2SDv2sqqwe";
		LowercaseString5(s);
	}
	profiler.Stop();

	float t5 = profiler.Time;

	PrintToServer("%f %f %f %f %f %f", t0, t1, t2, t3, t4, t5);
}
