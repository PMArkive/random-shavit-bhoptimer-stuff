#!/usr/bin/python3
import argparse
import os
import sys
import struct

class CBSPFile:
	def __init__(self, path):
		self.Path = path
		self.BSPFile = None
		self.BSPHeader = None
		self.BSPLumps = dict()

		if not os.path.isfile(self.Path) or not os.access(self.Path, os.R_OK):
			print("Could not open BSP file ({0})!".format(self.Path))
			sys.exit(1)

		self.BSPFile = open(self.Path, "rb")
		self.BSPHeader = self.ReadBSPHeader()

	def __del__(self):
		if self.BSPFile:
			self.BSPFile.close()

	def GetShort(self):
		return struct.unpack("i", self.BSPFile.read(2))[0]

	def GetInt(self):
		return struct.unpack("i", self.BSPFile.read(4))[0]

	def ReadBSPHeader(self):
		# BSP Header https://developer.valvesoftware.com/wiki/Source_BSP_File_Format#BSP_file_header
		Ident = self.GetInt()
		Version = self.GetInt()

		if(Ident != 1347633750):
			print("Faulty BSP file ({0}) version number ({1})!".format(self.Path, Version), file = sys.stderr)
			sys.exit(1)

		# Lump Headers https://developer.valvesoftware.com/wiki/Source_BSP_File_Format#Lump_structure
		Lumps = dict()
		for i in range(64): #define	HEADER_LUMPS 64
			LumpOffset = self.GetInt()
			LumpLength = self.GetInt()
			LumpVersion = self.GetInt()
			LumpIdent = self.GetInt() # char[4]

			Lump = dict({"fileofs": LumpOffset, "filelen": LumpLength, "version": LumpVersion, "fourCC": LumpIdent})
			Lumps[i] = Lump

		Revision = self.GetInt()

		return dict({"ident": Ident, "version": Version, "lumps": Lumps, "mapRevision": Revision})

	def ReadLump(self, lump):
		if lump < 0 or lump >= 64:
			return None

		if lump in self.BSPLumps:
			return self.BSPLumps[lump]

		Offset = self.BSPHeader["lumps"][lump]["fileofs"]
		Length = self.BSPHeader["lumps"][lump]["filelen"]

		self.BSPFile.seek(Offset, 0)
		self.BSPLumps[lump] = memoryview(self.BSPFile.read(Length))
		return self.BSPLumps[lump]

if __name__ == "__main__":
	parser = argparse.ArgumentParser()
	parser.add_argument("bsp", metavar="bsp", help="bsp file", type=str)
	args = parser.parse_args()

	# Original BSP
	BSPFile = CBSPFile(args.bsp)
	EntityLump = BSPFile.ReadLump(0)

	print(EntityLump.tobytes().decode("ascii"))