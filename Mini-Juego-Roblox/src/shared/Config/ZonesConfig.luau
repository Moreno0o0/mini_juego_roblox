--!strict
local Types = require(script.Parent.Parent.Types)

export type ZoneDef = {
	Id: Types.ZoneId,
	Index: number,
	Name: string,
	Tier: number,
	MaxZoneDamage: number,
	AssociatedMachineId: Types.MachineId,
	Center: Vector3,
	Size: Vector3,
	GateId: string?,
	SpawnPosition: Vector3,
	PadPosition: Vector3,
	MachinePosition: Vector3,
	ChamberPosition: Vector3,
}

local ZonesConfig: { [string]: ZoneDef } = {
	Zone_1 = {
		Id = "Zone_1",
		Index = 1,
		Name = "Zona 1: Novatos",
		Tier = 1,
		MaxZoneDamage = 15,
		AssociatedMachineId = 1,
		Center = Vector3.new(0, 5, 0),
		Size = Vector3.new(120, 26, 140),
		GateId = "Gate_1_2",
		SpawnPosition = Vector3.new(-35, 3, -40),
		PadPosition = Vector3.new(0, 1, -15),
		MachinePosition = Vector3.new(0, 5, 35),
		ChamberPosition = Vector3.new(0, -180, 0),
	},
	Zone_2 = {
		Id = "Zone_2",
		Index = 2,
		Name = "Zona 2: Intermedio",
		Tier = 2,
		MaxZoneDamage = 25,
		AssociatedMachineId = 2,
		Center = Vector3.new(170, 5, 0),
		Size = Vector3.new(120, 26, 140),
		GateId = "Gate_2_3",
		SpawnPosition = Vector3.new(135, 3, -40),
		PadPosition = Vector3.new(170, 1, -15),
		MachinePosition = Vector3.new(170, 5, 35),
		ChamberPosition = Vector3.new(170, -180, 0),
	},
	Zone_3 = {
		Id = "Zone_3",
		Index = 3,
		Name = "Zona 3: Avanzado",
		Tier = 3,
		MaxZoneDamage = 40,
		AssociatedMachineId = 3,
		Center = Vector3.new(340, 5, 0),
		Size = Vector3.new(120, 26, 140),
		GateId = "Gate_3_4",
		SpawnPosition = Vector3.new(305, 3, -40),
		PadPosition = Vector3.new(340, 1, -15),
		MachinePosition = Vector3.new(340, 5, 35),
		ChamberPosition = Vector3.new(340, -180, 0),
	},
	Zone_4 = {
		Id = "Zone_4",
		Index = 4,
		Name = "Zona 4: Experto",
		Tier = 4,
		MaxZoneDamage = 65,
		AssociatedMachineId = 4,
		Center = Vector3.new(510, 5, 0),
		Size = Vector3.new(120, 26, 140),
		GateId = "Gate_4_5",
		SpawnPosition = Vector3.new(475, 3, -40),
		PadPosition = Vector3.new(510, 1, -15),
		MachinePosition = Vector3.new(510, 5, 35),
		ChamberPosition = Vector3.new(510, -180, 0),
	},
	Zone_5 = {
		Id = "Zone_5",
		Index = 5,
		Name = "Zona 5: Cumbre / Coliseo",
		Tier = 5,
		MaxZoneDamage = 100,
		AssociatedMachineId = 5,
		Center = Vector3.new(700, 5, 0),
		Size = Vector3.new(160, 32, 170),
		GateId = nil,
		SpawnPosition = Vector3.new(650, 3, -45),
		PadPosition = Vector3.new(700, 1, -20),
		MachinePosition = Vector3.new(700, 5, 45),
		ChamberPosition = Vector3.new(700, -180, 0),
	},
}

local ZonesOrdered: { ZoneDef } = {
	ZonesConfig["Zone_1"],
	ZonesConfig["Zone_2"],
	ZonesConfig["Zone_3"],
	ZonesConfig["Zone_4"],
	ZonesConfig["Zone_5"],
}

local Module = {
	Zones = ZonesConfig,
	Ordered = ZonesOrdered,
}

function Module.GetByIndex(index: number): ZoneDef?
	return ZonesOrdered[index]
end

function Module.GetById(id: Types.ZoneId): ZoneDef?
	return ZonesConfig[id]
end

function Module.GetByMachineId(machineId: Types.MachineId): ZoneDef?
	return ZonesOrdered[machineId]
end

function Module.GetZoneFromPosition(pos: Vector3): Types.ZoneId
	if pos.X < 85 then
		return "Zone_1"
	elseif pos.X < 255 then
		return "Zone_2"
	elseif pos.X < 425 then
		return "Zone_3"
	elseif pos.X < 595 then
		return "Zone_4"
	else
		return "Zone_5"
	end
end

function Module.GetPlayerZone(player: Player): Types.ZoneId?
	local ok, char = pcall(function()
		return player.Character
	end)
	if not ok or typeof(char) ~= "Instance" or not char:IsA("Model") then
		return nil
	end

	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	return Module.GetZoneFromPosition(root.Position)
end

return Module
