import re

with open("kz_bhop_genkai_d - Copy.vmf", "r", encoding="utf-8") as f:
    content = f.read()
origin_re = re.compile(r'"model" "models/props_junk/wood_crate001a.mdl"\s+"origin" "(.+)"', re.MULTILINE)
results = origin_re.findall(content)
#print(results)
with open(r"kz_bhop_genkai_fixes.txt", "w") as f:
    f.write("\n".join(results))
