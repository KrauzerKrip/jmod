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

function ENT:CustomSetupDataTables() 
    self:NetworkVar("String", "CurrentResourceType")
    self:NetworkVar("Int", "CurrentResourceAmount")
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

        if resourceType == JMod.EZ_RESOURCE_TYPES.POWER or resourceType == JMod.EZ_RESOURCE_TYPES.HVPOWER then 
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
                self:SetCurrentResourceType(resourceType)
                amountLoaded = Ent:TryLoadResource(resourceType, resourceAmount)
                self:SetCurrentResourceAmount(amountLoaded)
                return amountLoaded
            end
        end 
        return 0
    end
end

if CLIENT then
	function ENT:Draw()
        local SelfPos, SelfAng, State = self:GetPos(), self:GetAngles(), self:GetState()
		local Up, Right, Forward = SelfAng:Up(), SelfAng:Right(), SelfAng:Forward()
		---
		local BasePos = SelfPos
		local Obscured = util.TraceLine({start = EyePos(), endpos = BasePos, filter = {LocalPlayer(), self}, mask = MASK_OPAQUE}).Hit
		local Closeness = LocalPlayer():GetFOV() * (EyePos():Distance(SelfPos))
		local DetailDraw = Closeness < 120000 -- cutoff point is 400 units when the fov is 90 degrees
		---
		--if((not(DetailDraw)) and (Obscured))then return end -- if player is far and sentry is obscured, draw nothing
		if(Obscured)then DetailDraw = false end -- if obscured, at least disable details
		if(State == STATE_BROKEN)then DetailDraw = false end -- look incomplete to indicate damage, save on gpu comp too
		---
		self:DrawModel()
		---
        if DetailDraw then
			if Closeness < 20000 and State == JMod.EZ_STATE_ON then
				local DisplayAng = SelfAng:GetCopy()
				DisplayAng:RotateAroundAxis(DisplayAng:Right(), -90)
				DisplayAng:RotateAroundAxis(DisplayAng:Up(), 90)
				local Opacity = math.random(50, 150)

                typ = self:GetCurrentResourceType()
                amt = self:GetCurrentResourceAmount()

				local R, G, B = JMod.GoodBadColor(amt / 1000)

				cam.Start3D2D(SelfPos + Forward * 13 + Up * 13, DisplayAng, .08)
				draw.SimpleTextOutlined(typ, "JMod-Display", 0, 0, Color(200, 255, 255, Opacity), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 3, Color(0, 0, 0, Opacity))
				draw.SimpleTextOutlined(tostring(math.Round(amt)) .. "/" .. tostring(math.Round(self.MaxResourceAmount)), "JMod-Display", 0, 30, Color(R, G, B, Opacity), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 3, Color(0, 0, 0, Opacity))
				cam.End3D2D()
			end
		end
	end
end

