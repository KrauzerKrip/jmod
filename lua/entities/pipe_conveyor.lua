AddCSLuaFile()

ENT.Type = "anim"
ENT.Category = "JMod - EZ Machines"
ENT.Base = "ent_jack_gmod_ezmachine_base"
ENT.PrintName="Conveyor"
ENT.Information = "Glory conveyor"
ENT.NoSitAllowed = true
ENT.Spawnable = true
ENT.AdminSpawnable = false
ENT.Model = "models/props_lab/powerbox01a.mdl"
ENT.Mass = 150
ENT.EZconsumes={}
ENT.MaxConnectionRange = 10000
ENT.Durability = 100
ENT.MaxDurability = 100
ENT.EZconnections = {}
ENT.MaxResourceAmount = 10

ENT.StaticPerfSpecs={ 
	MaxDurability = 100,
	Armor = 1.5
}

local function putEveryResourceIntoTable(self) 
    for _, v in pairs(JMod.EZ_RESOURCE_TYPES) do
        table.insert(self.EZconsumes, v)
    end
end

local function removeConnections(self)
    for i in pairs(self.EZconnections) do
        JMod.RemoveConveyorConnection(self, i)
    end
end

local function spawnPlug(self, spawnPos)
    local Plug = ents.Create("ent_jack_gmod_ezhook")
    if not IsValid(Plug) then return end
    Plug:SetPos(spawnPos) -- Adjust the position as needed
    Plug:SetAngles(angle_zero)
    Plug.Model = "models/props_lab/tpplug.mdl"
    Plug.EZconnector = self
    Plug:Spawn()
    Plug:Activate()

    return Plug
end

local function spawnPlugs(self, ply, spawnPos)
    if IsValid(self.EZconnectorInputPlug) then 
        if self.EZconnectorInputPlug:IsPlayerHolding() then return end
        SafeRemoveEntity(self.EZconnectorInputPlug)
    end
    if IsValid(self.EZconnectorOutputPlus) then 
        if self.EZconnectorOutputPlus:IsPlayerHolding() then return end
        SafeRemoveEntity(self.EZconnectorOutputPlus)
    end

    for i in pairs(self.EZconnections) do
        print(i)
    end
    removeConnections(self)

    if not(JMod.ShouldAllowControl(self, ply, true)) then return end
    if not IsValid(ply) then return end

    local PlugInput = spawnPlug(self, spawnPos + Vector(10, 0, 50))
    PlugInput.ConveyorPlugType = "Input"
    PlugInput.EZhookType = "ConveyorIn"
    local PlugOutput = spawnPlug(self, spawnPos + Vector(-10, 0, 50))
    PlugOutput.ConveyorPlugType = "Output"
    PlugOutput.EZhookType = "ConveyorOut"
    self.EZconnectorInputPlug = PlugInput
    self.EZconnectorOutputPlus = PlugOutput

    PlugInput:SetColor(Color(0, 255, 0))
    PlugOutput:SetColor(Color(255, 0, 0))

    local ropeLength = self.MaxConnectionRange or 1000
    local RopeInput = constraint.Rope(self, PlugInput, 0, 0, Vector(0,0,0), Vector(10,0,0), ropeLength, 0, 1000, 2, "cable/cable2", false)
    PlugInput.Chain = RopeInput
    local RopeOutput = constraint.Rope(self, PlugOutput, 0, 0, Vector(0,0,0), Vector(10,0,0), ropeLength, 0, 1000, 2, "cable/cable2", false)
    PlugOutput.Chain = RopeOutput
end

if SERVER then
	function ENT:SpawnFunction(ply, tr)
		local SpawnPos = tr.HitPos + tr.HitNormal * 20
		local Ent = ents.Create(self.ClassName)
		Ent:SetPos(SpawnPos)
		JMod.SetEZowner(Ent, ply)
		Ent:Spawn()
		Ent:Activate()

		-- JMod.Hint(JMod.GetEZowner(ent), "ent_jack_gmod_ezpowerbank")
		return Ent
	end

    function ENT:Think() 
        local Time, State = CurTime(), self:GetState()

        self:NextThink(Time + 1)
		return true
    end

    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetModelScale(1)
        self:PhysicsInit( SOLID_VPHYSICS ) -- Initializes physics for the entity, making it solid and interactable.
        self:SetMoveType( MOVETYPE_VPHYSICS ) -- Sets how the entity moves, using physics.
        self:SetSolid( SOLID_VPHYSICS ) -- Makes the entity solid, allowing for collisions.

        self:DrawShadow(false)
		self:SetUseType(SIMPLE_USE)

        local phys = self:GetPhysicsObject() -- Retrieves the physics object of the entity.
        if phys:IsValid() then -- Checks if the physics object is valid.
            phys:Wake() -- Activates the physics object, making the entity subject to physics (gravity, collisions, etc.).
        end
        
        putEveryResourceIntoTable(self)
    end

    function ENT:Use(activator)
		local State = self:GetState()
		local IsPly = (IsValid(activator) and activator:IsPlayer())
		local Alt = IsPly and activator:KeyDown(JMod.Config.General.AltFunctionKey)
		JMod.SetEZowner(self, activator)

		if State == JMod.EZ_STATE_BROKEN then
			JMod.Hint(activator, "destroyed", self)
		end
		
		if Alt then
            spawnPlugs(self, activator, self:GetPos())
		else
			if State == JMod.EZ_STATE_OFF then
				self:TurnOn(activator)
			elseif State == JMod.EZ_STATE_ON then
				self:TurnOff(activator)
			end
		end
	end

    function ENT:TurnOn(ply)
		if self:GetState() ~= JMod.EZ_STATE_OFF then return end
		self:SetState(JMod.EZ_STATE_ON)
		if IsValid(ply) then
			self.EZstayOn = true
		end

        self:EmitSound("buttons/button24.wav", 75, 100)
	end

	function ENT:TurnOff(ply)
		if self:GetState() ~= JMod.EZ_STATE_ON then return end
		self:SetState(JMod.EZ_STATE_OFF)
		if IsValid(ply) then
			self.EZstayOn = nil
		end

        self:EmitSound("buttons/button9.wav", 75, 100)
	end

    function ENT:TryLoadResource(resourceType, resourceAmount)
        if not ((self:GetState() == JMod.EZ_STATE_ON) and table.Count(self.EZconnections) > 0) then
			return 0
		end

        if resourceAmount > self.MaxResourceAmount then
            resourceAmount = self.MaxResourceAmount
        end
        
        for entID, cableAndType in pairs(self.EZconnections) do
            local Ent, CableAndType = Entity(entID), cableAndType
            local Cable, Type = CableAndType[1], CableAndType[2]
            
            if not Type then error("PIPE CONVEYOR: connection TYPE is nil") end
            
            amountLoaded = 0

            if Type == "Output" and IsValid(Ent) then
                amountLoaded = Ent:TryLoadResource(resourceType, resourceAmount)
                return amountLoaded
            end
        end 
    end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()
	end
end

