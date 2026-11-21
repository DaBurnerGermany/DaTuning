-- Approximate swatches for the GTA vehicle paint indices. The vehicle preview renders the actual finish.
local rows = {
    'Schwarz|Black|0d1116', 'Graphit|Graphite|1c1d21', 'Schwarzstahl|Black steel|32383d', 'Dunkelstahl|Dark steel|454b4f',
    'Silber|Silver|999da0', 'Blausilber|Bluish silver|c2c4c6', 'Walzstahl|Rolled steel|979a97', 'Schattensilber|Shadow silver|637380',
    'Steinsilber|Stone silver|63625c', 'Mitternachtssilber|Midnight silver|3c3f47', 'Gusseisen|Cast iron|444e54', 'Anthrazit|Anthracite|1d2129',
    'Mattschwarz|Matte black|13181f', 'Mattgrau|Matte gray|26282a', 'Matthellgrau|Matte light gray|515554', 'Tiefschwarz|Jet black|151921',
    'Dunkelgrau|Dark gray|1e2429', 'Eisengrau|Iron gray|333a3c', 'Schiefergrau|Slate gray|8c9095', 'Silbergrau|Silver gray|39434d',
    'Zinkgrau|Zinc gray|506272', 'Kohlegrau|Coal gray|1e232f', 'Aschgrau|Ash gray|363a3f', 'Hellstahl|Light steel|a0a199',
    'Warmgrau|Warm gray|8b8d8a', 'Kühlsilber|Cool silver|c1c4c1', 'Zinngrau|Pewter gray|6c7277', 'Rot|Red|c00e1a',
    'Torinorot|Torino red|da1918', 'Formelrot|Formula red|b6111b', 'Flammenrot|Flame red|a51e23', 'Karminrot|Carmine|7b1a22',
    'Granatrot|Garnet red|8e1b1f', 'Sonnenuntergangsrot|Sunset red|6f1818', 'Cabernetrot|Cabernet red|49111d', 'Candyrot|Candy red|b60f25',
    'Sonnenaufgangsorange|Sunrise orange|d44a17', 'Bernstein|Amber|c28136', 'Orange|Orange|f78616', 'Mattrot|Matte red|cf1f21',
    'Mattdunkelrot|Matte dark red|732021', 'Mattorange|Matte orange|f27d20', 'Mattgelb|Matte yellow|ffc91f', 'Purpurrot|Crimson|9c1016',
    'Feuerrot|Fire red|de0f18', 'Dunkelkarmin|Dark carmine|8f1e17', 'Rubinrot|Ruby red|a7151f', 'Korallenrot|Coral red|c34627',
    'Weinrot|Burgundy|3e0d16', 'Dunkelgrün|Dark green|1b2d27', 'Renngrün|Racing green|183032', 'Seegrün|Sea green|2f4546',
    'Olivgrün|Olive green|59634a', 'Hellgrün|Light green|4b7c3d', 'Petrolgrün|Petrol green|244b4d', 'Mattlimette|Matte lime|6a9d27',
    'Tannengrün|Pine green|22383e', 'Waldgrün|Forest green|1d5a3f', 'Jadegrün|Jade green|2d6660', 'Moosgrün|Moss green|455943',
    'Apfelgrün|Apple green|65867f', 'Galaxieblau|Galaxy blue|222e46', 'Dunkelblau|Dark blue|233155', 'Sachsenblau|Saxon blue|304c7e',
    'Blau|Blue|47578f', 'Marinerblau|Mariner blue|637ba7', 'Hafenblau|Harbor blue|394762', 'Diamantblau|Diamond blue|d6e7f1',
    'Brandungsblau|Surf blue|76afbe', 'Nautikblau|Nautical blue|345e72', 'Ultrablau|Ultra blue|0b57c6', 'Schafterviolett|Schafter purple|3c2e66',
    'Spinnakerviolett|Spinnaker purple|2f2d52', 'Rennblau|Racing blue|2354a1', 'Hellblau|Light blue|6ea3c6', 'Nachtblau|Night blue|112c42',
    'Denimblau|Denim blue|1b3354', 'Dämmerungsblau|Dusk blue|33609f', 'Himmelblau|Sky blue|6b97b6', 'Eisblau|Ice blue|99c4d4',
    'Kobaltblau|Cobalt blue|144e9a', 'Stahlblau|Steel blue|2c4975', 'Mattdunkelblau|Matte dark blue|1a294c', 'Mattblau|Matte blue|2446a8',
    'Mattmitternachtsblau|Matte midnight blue|102239', 'Tintenschwarz|Ink black|25384d', 'Tiefseekobalt|Deep-sea cobalt|2e4369', 'Azurblaumetallic|Metallic azure|3563a7',
    'Gelb|Yellow|f4cf21', 'Renngelb|Race yellow|ffda29', 'Bronze|Bronze|916532', 'Taugelb|Dew yellow|dfd73a',
    'Limettengrün|Lime green|98d223', 'Goldbeige|Gold beige|9b794c', 'Champagner|Champagne|b9a18c', 'Feltzerbraun|Feltzer brown|755c42',
    'Schokoladenbraun|Chocolate brown|4a341b', 'Ahornbraun|Maple brown|854a2e', 'Sattelbraun|Saddle brown|714322', 'Strohbraun|Straw brown|a3825a',
    'Moosbraun|Moss brown|655945', 'Bisonbraun|Bison brown|53382f', 'Buchenbraun|Beechwood brown|a38d68', 'Dunkelbuchenbraun|Dark beechwood brown|6c5640',
    'Sienabraun|Sienna brown|802c19', 'Sandbraun|Sand brown|be9c74', 'Gebleichtes Braun|Bleached brown|d0b995', 'Creme|Cream|ead6b7',
    'Kaffeebraun|Coffee brown|604936', 'Kastanienbraun|Chestnut brown|584338', 'Lederbraun|Leather brown|987356', 'Eisweiß|Ice white|f4f4f6',
    'Frostweiß|Frost white|dce3e7', 'Honigbeige|Honey beige|b9946e', 'Kieselbeige|Pebble beige|999284', 'Elfenbein|Ivory|dfd2b8',
    'Wollweiß|Wool white|ebe9da', 'Gebürsteter Stahl|Brushed steel|6e787c', 'Gebürsteter Schwarzstahl|Brushed black steel|484a4b', 'Gebürstetes Aluminium|Brushed aluminum|9f9e96',
    'Chrom|Chrome|bbc6cb', 'Grauweiß|Gray white|d7d7d7', 'Offwhite|Off-white|e5e5dc', 'Orangekupfer|Orange copper|ac512c',
    'Orangegelb|Orange yellow|f5993f', 'Signalgrün|Signal green|83c566', 'Sonnengelb|Sun yellow|e6cd55', 'Verkehrsblau|Traffic blue|2d5282',
    'Mattgrün|Matte green|4e6443', 'Dunkelbeige|Dark beige|a29571', 'Kürbisorange|Pumpkin orange|f39d54', 'Matteisweiß|Matte ice white|e7e7e7',
    'Reinweiß|Pure white|f3f3f3', 'Dunkeloliv|Dark olive|3f422f', 'Kreideweiß|Chalk white|f2efe6', 'Neonpink|Neon pink|e550a6',
    'Lachsrosa|Salmon pink|f4a0b4', 'Kräftiges Pink|Deep pink|c84791', 'Leuchtorange|Bright orange|f48522', 'Minzgrün|Mint green|a7d9a1',
    'Saphirblau|Sapphire blue|2749a2', 'Mitternachtsblau|Midnight blue|171c30', 'Mitternachtsviolett|Midnight purple|30243e', 'Weinrot metallic|Metallic wine red|4a1724',
    'Jägergrün|Hunter green|283126', 'Hellviolett|Light purple|6c3f94', 'Tiefviolett|Deep purple|271a2a', 'Carbonschwarz|Carbon black|161a1d',
    'Mattschafterviolett|Matte Schafter purple|514a59', 'Mattmitternachtsviolett|Matte midnight purple|302d38', 'Lavarot|Lava red|b42b26', 'Mattfrostgrün|Matte frost green|556157',
    'Mattoliv|Matte olive|5c644e', 'Sturmgrün|Storm green|454a39', 'Mattwüstenbeige|Matte desert tan|9b9073', 'Mattdunkelerde|Matte dark earth|776c55',
    'Salbeigrün|Sage green|526765', 'Perlweiß|Pearl white|e9e5dc', 'Reingold|Pure gold|a58e53', 'Gebürstetes Gold|Brushed gold|9c8754'
}

PaintPalette = {}
for i, row in ipairs(rows) do
    local german, english, hex = row:match('^([^|]+)|([^|]+)|(%x%x%x%x%x%x)$')
    PaintPalette[i - 1] = { name = TuningLocale() == 'en' and english or german, swatch = '#' .. hex }
end

local families = {
    { 'Schwarz & Grau', 0, 1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
        21, 22, 23, 24, 26, 85, 147 },
    { 'Weiß & Creme', 107, 111, 112, 115, 116, 121, 122, 131, 132, 134, 157 },
    { 'Rot & Rosa', 27, 28, 29, 30, 31, 32, 33, 34, 35, 39, 40, 43, 44, 45, 46, 47, 48, 135,
        136, 137, 143, 150 },
    { 'Orange & Gelb', 36, 37, 38, 41, 42, 88, 89, 91, 123, 124, 126, 130, 138 },
    { 'Grün', 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 92, 125, 128, 133, 139, 144, 151,
        152, 153, 156 },
    { 'Blau & Violett', 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78,
        79, 80, 81, 82, 83, 84, 86, 87, 127, 140, 141, 142, 145, 146, 148, 149 },
    { 'Braun & Beige', 93, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 108, 109,
        110, 113, 114, 129, 154, 155 },
    { 'Silber, Gold & Metall', 4, 5, 25, 90, 117, 118, 119, 120, 158, 159 }
}
for order, family in ipairs(families) do
    for i = 2, #family do
        local paint = PaintPalette[family[i]]
        paint.group, paint.groupOrder = TuningText(family[1]), order
    end
end

-- The finish is part of the GTA paint index.
local matte = { 12, 13, 14, 39, 40, 41, 42, 55, 82, 83, 84, 128, 131, 148, 149, 151, 152, 154, 155 }
local metal = { 117, 118, 119, 120, 158, 159 }
for _, paint in pairs(PaintPalette) do paint.finish = 'standard' end
for _, index in ipairs(matte) do PaintPalette[index].finish = 'matte' end
for _, index in ipairs(metal) do PaintPalette[index].finish = 'metal' end