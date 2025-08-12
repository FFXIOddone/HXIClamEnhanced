-- constants.lua
-- Item display names, moon tables, item index, etc.

local M = {}

M.ItemDisplayNames = {
    ['pebble'] = 'Pebble',
    ['bibiki slug'] = 'B.Slug',
    ['jacknife'] = 'Jacknife',
    ['clump of pamtam kelp'] = 'P.Kelp',
    ['vongola clam'] = 'V.Clam',
    ['shall shell'] = 'S.Shell',
    ['handful of fish scales'] = 'F.Scales',
    ['handful of pugil scales'] = 'P.Scales',
    ['handful of high-quality pugil scales'] = 'HQ P.Scales',
    ['coral fragment'] = 'Coral Frag',
    ['crab shell'] = 'Crab Shell',
    ['high-quality crab shell'] = 'HQ Crab',
    ['sack of white sand'] = 'W.Sand',
    ['seashell'] = 'Seashell',
    ['nebimonite'] = 'Nebimonite',
    ['bibiki urchin'] = 'B.Urchin',
    ['tropical clam'] = 'Tropical Clam',
    ['titanictus shell'] = 'Titan Shell',
    ['turtle shell'] = 'Turtle Shell',
    ['uragnite shell'] = 'Urag Shell',
    ['maple log'] = 'Maple Log',
    ['lacquer tree log'] = 'Lacquer Log',
    ['elm log'] = 'Elm Log',
    ['petrified log'] = 'Petrified Log',
    ['loaf of hobgoblin bread'] = 'HG Bread',
    ['hobgoblin pie'] = 'HG Pie',
    ['goblin mask'] = 'Gob Mask',
    ['suit of goblin armor'] = 'Gob Armor',
    ['suit of goblin mail'] = 'Gob Mail',
    ['broken willow fishing rod'] = 'Broken Rod',
    ['piece of oxblood'] = 'Oxblood',
}

M.MoonPhasePercent = {
    [ 1]= 96,[ 2]= 92,[ 3]= 88,[ 4]= 84,[ 5]= 80,[ 6]= 76,[ 7]= 72,[ 8]= 68,[ 9]= 64,[10]= 60,
    [11]= 56,[12]= 52,[13]= 48,[14]= 44,[15]= 40,[16]= 36,[17]= 32,[18]= 28,[19]= 24,[20]= 20,
    [21]= 16,[22]= 12,[23]=  8,[24]=  4,[25]=  0,[26]=  4,[27]=  8,[28]= 12,[29]= 16,[30]= 20,
    [31]= 24,[32]= 28,[33]= 32,[34]= 36,[35]= 40,[36]= 44,[37]= 48,[38]= 52,[39]= 56,[40]= 60,
    [41]= 64,[42]= 68,[43]= 72,[44]= 76,[45]= 80,[46]= 84,[47]= 88,[48]= 92,[49]= 96,[50]=100,
    [51]=100,[52]=100,[53]= 96,[54]= 92,[55]= 88,[56]= 84,[57]= 80,[58]= 76,[59]= 72,[60]= 68,
    [61]= 64,[62]= 60,[63]= 56,[64]= 52,[65]= 48,[66]= 44,[67]= 40,[68]= 36,[69]= 32,[70]= 28,
    [71]= 24,[72]= 20,[73]= 16,[74]= 12,[75]=  8,[76]=  4,[77]=  0,[78]=  4,[79]=  8,[80]= 12,
    [81]= 16,[82]= 20,[83]= 24,[84]= 28,
}
M.MoonPhase = {
    [ 1]='Waning Gibbous',[ 2]='Waning Gibbous',[ 3]='Waning Gibbous',[ 4]='Waning Gibbous',[ 5]='Waning Gibbous',
    [ 6]='Waning Gibbous',[ 7]='Waning Gibbous',[ 8]='Waning Gibbous',[ 9]='Waning Gibbous',[10]='Waning Gibbous',
    [11]='Last Quarter'  ,[12]='Last Quarter'  ,[13]='Last Quarter'  ,[14]='Last Quarter'  ,[15]='Last Quarter',
    [16]='Waning Crescent',[17]='Waning Crescent',[18]='Waning Crescent',[19]='Waning Crescent',[20]='Waning Crescent',
    [21]='Waning Crescent',[22]='Waning Crescent',[23]='Waning Crescent',[24]='Waning Crescent',[25]='New Moon',
    [26]='New Moon'       ,[27]='New Moon'       ,[28]='New Moon'       ,[29]='New Moon'       ,[30]='Waxing Crescent',
    [31]='Waxing Crescent',[32]='Waxing Crescent',[33]='Waxing Crescent',[34]='Waxing Crescent',[35]='Waxing Crescent',
    [36]='Waxing Crescent',[37]='Waxing Crescent',[38]='Waxing Crescent',[39]='Waxing Crescent',[40]='Waxing Crescent',
    [41]='New Moon'       ,[42]='New Moon'       ,[43]='New Moon'       ,[44]='New Moon'       ,[45]='New Moon',
    [46]='Waxing Crescent',[47]='Waxing Crescent',[48]='Waxing Crescent',[49]='Waxing Crescent',[50]='Waxing Crescent',
    [51]='Waxing Crescent',[52]='Waxing Crescent',[53]='Waxing Crescent',[54]='Waxing Crescent',[55]='Waxing Crescent',
    [56]='Waxing Crescent',[57]='Waxing Crescent',[58]='Waxing Crescent',[59]='First Quarter' ,[60]='First Quarter',
    [61]='First Quarter'  ,[62]='First Quarter'  ,[63]='First Quarter'  ,[64]='First Quarter'  ,[65]='First Quarter',
    [66]='First Quarter'  ,[67]='Waxing Gibbous' ,[68]='Waxing Gibbous' ,[69]='Waxing Gibbous' ,[70]='Waxing Gibbous',
    [71]='Waxing Gibbous' ,[72]='Waxing Gibbous' ,[73]='Waxing Gibbous' ,[74]='Waxing Gibbous' ,[75]='Waxing Gibbous',
    [76]='Waxing Gibbous' ,[77]='Waxing Gibbous' ,[78]='Waxing Gibbous' ,[79]='Waxing Gibbous' ,[80]='Waxing Gibbous',
    [81]='Full Moon'      ,[82]='Full Moon'      ,[83]='Full Moon'      ,[84]='Full Moon',
}

M.ItemIndex = {
    [1]="bibiki slug:11",[2]="bibiki urchin:768",[3]="broken willow fishing rod:0",[4]="coral fragment:1793",
    [5]="crab shell:380",[6]="high-quality crab shell:3203",[7]="elm log:3800",
    [8]="handful of fish scales:26",[9]="suit of goblin armor:0",[10]="suit of goblin mail:0",
    [11]="goblin mask:0",[12]="loaf of hobgoblin bread:100",[13]="hobgoblin pie:165",[14]="jacknife:58",
    [15]="lacquer tree log:6000",[16]="maple log:16",[17]="nebimonite:300",[18]="piece of oxblood:13581",
    [19]="clump of pamtam kelp:8",[20]="pebble:1",[21]="petrified log:3400",
    [22]="handful of pugil scales:25",[23]="handful of high-quality pugil scales:266",
    [24]="seashell:33",[25]="shall shell:307",[26]="titanictus shell:358",[27]="tropical clam:5227",
    [28]="turtle shell:1254",[29]="uragnite shell:1455",[30]="vongola clam:196",[31]="sack of white sand:256",
}
M.ItemWeightIndex = {
    [1]="bibiki slug:3",[2]="bibiki urchin:6",[3]="broken willow fishing rod:6",[4]="coral fragment:6",
    [5]="crab shell:6",[6]="high-quality crab shell:6",[7]="elm log:6",
    [8]="handful of fish scales:1",[9]="suit of goblin armor:6",[10]="suit of goblin mail:6",
    [11]="goblin mask:6",[12]="loaf of hobgoblin bread:6",[13]="hobgoblin pie:6",[14]="jacknife:3",
    [15]="lacquer tree log:6",[16]="maple log:6",[17]="nebimonite:6",[18]="piece of oxblood:1",
    [19]="clump of pamtam kelp:1",[20]="pebble:1",[21]="petrified log:6",
    [22]="handful of pugil scales:1",[23]="handful of high-quality pugil scales:1",
    [24]="seashell:1",[25]="shall shell:6",[26]="titanictus shell:6",[27]="tropical clam:6",
    [28]="turtle shell:6",[29]="uragnite shell:6",[30]="vongola clam:6",[31]="sack of white sand:6",
}

return M
