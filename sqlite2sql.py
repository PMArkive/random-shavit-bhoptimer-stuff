"""
The Don't Ask Me About It License

Copying and distribution of this file, with or without modification, are permitted in any medium provided you do not contact the author about the file or any problems you are having with the file
"""
# INTENDED FOR SOME OLD DBs TO IMPORT TO MYSQL/MARIADB

import sqlite3
import shutil
import os.path

# backup saving/l;oading
if os.path.isfile("shavit - Copy.sq3"):
    shutil.copyfile("shavit - Copy.sq3", "shavit.sq3")
else:
    shutil.copyfile("shavit.sq3", "shavit - Copy.sq3")

con = sqlite3.connect("shavit.sq3")
cur = con.cursor()



print("removing 0s times")
cur.execute("DELETE FROM playertimes WHERE time = 0")



#print("removing dupe in users table")
#cur.execute("DELETE FROM users WHERE auth = '21796'")



print("remove blobs/truncated-utf-8")
con.text_factory = bytes
for row in cur.execute("SELECT auth, name FROM users").fetchall():
    try:
        a = row[1].decode()
    except UnicodeDecodeError:
        auth = row[0].decode()
        print(f"changing {auth}'s name in users table because it's fucked...")
        cur.execute("UPDATE users SET name = ? WHERE auth = ?", (auth, auth))
con.text_factory = str



print("removing times that shouldn't exist with the same track&style&map&auth")
for dupecountrow in cur.execute("SELECT id,style,track,auth,map,COUNT(*) FROM playertimes GROUP BY style,track,auth,map HAVING COUNT(*) > 1").fetchall():
    #for dupes in cur.execute("SELECT 
    print("\t",dupecountrow)
cur.execute("""
DELETE FROM playertimes WHERE id IN (
    SELECT a.id
    FROM playertimes a, playertimes b
    WHERE a.style=b.style AND a.track=b.track AND a.auth=b.auth AND a.map=b.map AND (a.time>b.time OR a.id>b.id)
)
""")



# These aren't needed for exporting to a .sql file...
print("add missing completions column to playertimes table")
cur.execute("ALTER TABLE playertimes ADD COLUMN completions INTEGER DEFAULT 1")



print("add missing mapzones columns")
cur.execute("ALTER TABLE mapzones ADD COLUMN flags INTEGER NOT NULL DEFAULT 0")
cur.execute("ALTER TABLE mapzones ADD COLUMN data INTEGER NOT NULL DEFAULT 0")
cur.execute("ALTER TABLE mapzones ADD COLUMN form INTEGER")
cur.execute("ALTER TABLE mapzones ADD COLUMN target TEXT")



# cancer
def ip_to_int(ip):
    ip_parts = str(row[2]).split('.')
    if len(ip_parts) == 1:
        return row[2]
    ip_int = (int(ip_parts[0]) << 24) + (int(ip_parts[1]) << 16) + (int(ip_parts[2]) << 8) + int(ip_parts[3])
    ip_int &= ((1<<32)-1)
    if ip_int & (1<<31): ip_int -= (1<<32)
    return ip_int

print("writing out shavit.sq3.sql which you import into mysql/mariadb")
with open("shavit.sq3.sql", "w", encoding="utf-8") as f:
    for row in cur.execute("SELECT `auth`,`name`,`ip`,`lastlogin` FROM users").fetchall():
        auth = row[0].replace("[U:1:","").replace("]","")
        slightly_filtered_name = row[1].replace("\\", "\\\\").replace("'", "\\'")
        f.write(f"INSERT INTO users (`auth`,`name`,`ip`,`lastlogin`) VALUES({auth},'{slightly_filtered_name}',{ip_to_int(row[2])},{row[3]});\n")
    for row in cur.execute("SELECT `map`,`type`,`corner1_x`,`corner1_y`,`corner1_z`,`corner2_x`,`corner2_y`,`corner2_z`,`destination_x`,`destination_y`,`destination_z`,`track`,`flags`,`data`,`form`,`target` FROM mapzones").fetchall():
        form = f"{row[14]}" if row[14] is not None else "NULL"
        target = f"'{row[15]}'" if row[15] is not None else "NULL"
        f.write(f"INSERT INTO mapzones (`map`,`type`,`corner1_x`,`corner1_y`,`corner1_z`,`corner2_x`,`corner2_y`,`corner2_z`,`destination_x`,`destination_y`,`destination_z`,`track`,`flags`,`data`,`form`,`target`) VALUES ('{row[0]}',{row[1]},{row[2]},{row[3]},{row[4]},{row[5]},{row[6]},{row[7]},{row[8]},{row[9]},{row[10]},{row[11]},{row[12]},{row[13]},{form},{target});\n")
    for row in cur.execute("SELECT `auth`,`name`,`ccname`,`message`,`ccmessage` FROM chat").fetchall():
        auth = row[0].replace("[U:1:","").replace("]","")
        slightly_filtered_name = row[2].replace("\\", "\\\\").replace("'", "\\'")
        f.write(f"INSERT INTO chat (`auth`,`name`,`ccname`,`message`,`ccmessage`) VALUES ({auth},{row[1]},'{slightly_filtered_name}',{row[3]},'{row[4]}');\n")
    for row in cur.execute("SELECT `style`,`track`,`time`,`auth`,`map`,`jumps`,`points`,`date`,`strafes`,`sync`,`perfs`,`completions` FROM playertimes").fetchall():
        auth = row[3].replace("[U:1:","").replace("]","")
        f.write(f"INSERT INTO playertimes (`style`,`track`,`time`,`auth`,`map`,`jumps`,`points`,`date`,`strafes`,`sync`,`perfs`,`completions`) VALUES ({row[0]},{row[1]},{row[2]},{auth},'{row[4]}',{row[5]},{row[6]},{row[7]},{row[8]},{row[9]},{row[10]},{row[11]});\n")


# write and shit...
con.commit()
con.close()

