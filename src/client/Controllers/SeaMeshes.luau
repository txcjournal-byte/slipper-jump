--!strict
-- Realistické modely mořských tvorů (meshe z Creator Store, veřejné a zdarma):
--  žralok bílý (mesh 430072846), plejtvák obrovský (28 dílů), chobotnice (mesh 12375662872).
-- Data jsou převedená do souřadnic rigu: tvor pluje ve směru -Z, střed v počátku,
-- Pos/Scale v měřítku 1 (rig je pak ještě násobí svým Scale). Rot = Euler XYZ v radiánech.
-- Díly se staví jako Part + SpecialMesh (MeshId jde nastavit za běhu, MeshPart ne).

export type MeshEntry = {
	Mesh: string,
	Texture: string,
	Scale: Vector3,
	Pos: Vector3,
	Rot: Vector3,
	Color: Color3,
	Material: string,
}

local SeaMeshes: { [string]: { MeshEntry } } = {
	-- délka 13 studů, hřbetní ploutev čouhá nad hladinu
	Shark = {
		{ Mesh = "rbxassetid://430072846", Texture = "rbxassetid://430072921", Scale = Vector3.new(0.056, 0.056, 0.056), Pos = Vector3.new(0, -1.6, 0), Rot = Vector3.new(-3.142, 0, -3.142), Color = Color3.fromRGB(163, 162, 165), Material = "SmoothPlastic" },
	},
	-- délka 40 studů (rig ji zmenší), hlava na -Z
	Whale = {
		{ Mesh = "rbxassetid://2911466710", Texture = "", Scale = Vector3.new(0.795, 1.844, 3.721), Pos = Vector3.new(0, -2.87, 14.453), Rot = Vector3.new(-3.142, 0, -3.142), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2915041274", Texture = "", Scale = Vector3.new(5.188, 4.6, 5.976), Pos = Vector3.new(0, -2.438, -5.956), Rot = Vector3.new(0, 0, 0), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2911594849", Texture = "", Scale = Vector3.new(1.187, 1.276, 1.484), Pos = Vector3.new(-2.1, -2.959, 17.4), Rot = Vector3.new(0, 0.175, 1.571), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(1.5, -1.502, -12.617), Rot = Vector3.new(3.054, 1.571, 0), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://2911568571", Texture = "", Scale = Vector3.new(1.675, 1.259, 1.259), Pos = Vector3.new(-4.363, -4.757, -7.22), Rot = Vector3.new(0, 0, 2.182), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2911466710", Texture = "", Scale = Vector3.new(1.565, 2.913, 5.596), Pos = Vector3.new(0, -2.705, 9.788), Rot = Vector3.new(-3.142, 0, -3.142), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2915041274", Texture = "", Scale = Vector3.new(4.779, 4.339, 5.891), Pos = Vector3.new(0, -2.511, -4.66), Rot = Vector3.new(0, 0, 0), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2911557998", Texture = "", Scale = Vector3.new(0.61, 0.174, 0.243), Pos = Vector3.new(0, -0.599, 7.964), Rot = Vector3.new(0, 0, 0), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2911568571", Texture = "", Scale = Vector3.new(1.675, 1.259, 1.259), Pos = Vector3.new(4.362, -4.757, -7.22), Rot = Vector3.new(0, 0, -2.182), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2911466710", Texture = "", Scale = Vector3.new(3.393, 4.031, 7.248), Pos = Vector3.new(0, -2.543, 3.688), Rot = Vector3.new(-3.142, 0, -3.142), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2911594849", Texture = "", Scale = Vector3.new(1.187, 1.276, 1.484), Pos = Vector3.new(2.1, -2.959, 17.4), Rot = Vector3.new(0, -0.175, -1.571), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2910352226", Texture = "", Scale = Vector3.new(4.755, 5.499, 7.391), Pos = Vector3.new(0, -2.42, -0.517), Rot = Vector3.new(-3.142, 0, -3.142), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2911466710", Texture = "", Scale = Vector3.new(2.328, 3.322, 4.959), Pos = Vector3.new(0, -2.706, 7.182), Rot = Vector3.new(-3.142, 0, -3.142), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(-0.7, -2.016, -18.491), Rot = Vector3.new(-0.087, 1.222, 3.142), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(1.287, -1.829, -16.354), Rot = Vector3.new(3.054, 1.396, 0), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(1.456, -1.718, -15.083), Rot = Vector3.new(3.054, 1.484, 0), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(-0.994, -1.946, -17.687), Rot = Vector3.new(-0.087, 1.309, 3.142), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(1.5, -1.587, -13.585), Rot = Vector3.new(3.054, 1.571, 0), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(-1.438, -1.715, -15.046), Rot = Vector3.new(-0.087, 1.484, 3.142), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(-1.475, -1.584, -13.548), Rot = Vector3.new(3.054, 1.571, 0), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(-1.263, -1.826, -16.317), Rot = Vector3.new(-0.087, 1.396, 3.142), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://2915117180", Texture = "", Scale = Vector3.new(3.633, 5.207, 4.615), Pos = Vector3.new(0, -2.032, -12.253), Rot = Vector3.new(0, 0, 0), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://2915073129", Texture = "", Scale = Vector3.new(3.439, 5.668, 5.096), Pos = Vector3.new(0, -3.055, -14.172), Rot = Vector3.new(0.087, 0, 0), Color = Color3.fromRGB(140, 88, 89), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(0.725, -2.02, -18.528), Rot = Vector3.new(3.054, 1.222, 0), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://2915073129", Texture = "", Scale = Vector3.new(3.933, 5.972, 5.144), Pos = Vector3.new(0, -3.133, -14.178), Rot = Vector3.new(0.087, 0, 0), Color = Color3.fromRGB(110, 153, 202), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(-1.475, -1.499, -12.58), Rot = Vector3.new(3.054, 1.571, 0), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://760766662", Texture = "", Scale = Vector3.new(0.008, 0.019, 0.001), Pos = Vector3.new(1.019, -1.949, -17.724), Rot = Vector3.new(3.054, 1.309, 0), Color = Color3.fromRGB(175, 159, 130), Material = "Slate" },
		{ Mesh = "rbxassetid://2915117180", Texture = "", Scale = Vector3.new(2.542, 4.597, 4.018), Pos = Vector3.new(0, -2.158, -13.044), Rot = Vector3.new(0, 0, 0), Color = Color3.fromRGB(140, 88, 89), Material = "Slate" },
	},
	-- kreslené verze (vygenerované v Roblox Studiu podle předlohy hry): žralok a velryba
	CartoonShark = {
		{ Mesh = "rbxassetid://122827703841845", Texture = "rbxassetid://89448781710408", Scale = Vector3.new(3.08, 3.08, 3.08), Pos = Vector3.new(0, -0.9, 0), Rot = Vector3.new(0, 1.571, 0), Color = Color3.fromRGB(255, 255, 255), Material = "SmoothPlastic" },
	},
	CartoonWhale = {
		{ Mesh = "rbxassetid://126703249719336", Texture = "rbxassetid://137174416524990", Scale = Vector3.new(2.98, 2.98, 2.98), Pos = Vector3.new(0, -3.6, 0), Rot = Vector3.new(0, 3.142, 0), Color = Color3.fromRGB(255, 255, 255), Material = "SmoothPlastic" },
	},
	-- rozpětí chapadel 14 studů, hlava kousek pod hladinou
	Octopus = {
		{ Mesh = "rbxassetid://12375662872", Texture = "rbxassetid://12375663361", Scale = Vector3.new(25.711, 25.703, 25.711), Pos = Vector3.new(0, -1.5, 0), Rot = Vector3.new(-3.142, 0, -3.142), Color = Color3.fromRGB(163, 162, 165), Material = "SmoothPlastic" },
	},
}

return SeaMeshes
