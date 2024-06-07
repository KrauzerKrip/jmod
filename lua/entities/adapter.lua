AddCSLuaFile()

ENT.Type = "anim"
ENT.Category = "JMod - EZ Machines"
ENT.PrintName="Adapter"
ENT.Information = "Glory adapter"
ENT.NoSitAllowed = true
ENT.Spawnable = true
ENT.AdminSpawnable = false
ENT.Model = "models/props_lab/powerbox02d.mdl"
ENT.Mass = 150
ENT.EZconsumes={}
ENT.IsAdapter = true

function ENT:PutEveryResourceIntoTable() 
    for _, v in pairs(JMod.EZ_RESOURCE_TYPES) do
        table.insert(self.EZconsumes, v)
    end
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "ResourceAmount")
	self:NetworkVar("String", 0, "ResourceType")
end

if SERVER then
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
        
        self:PutEveryResourceIntoTable()
    end

    function ENT:Think()
        local Origin = self:GetPos()
        local Angles = self:GetAngles()
        local Direction = -Angles:Forward() * 50
        Result = util.QuickTrace(Origin, Direction, self)
        
        if Result.Entity then 
            if self.EZconnections then
                for entID, cableAndType in pairs(self.EZconnections) do
                    local Ent, CableAndType = Entity(entID), cableAndType
                    local Cable, Type = CableAndType[1], CableAndType[2]

                    if not Type then error("ADAPTER: connection TYPE is nil") end
                
                    -- load into conveyor
                    if Type == "Input" then
                        if Result.Entity.IsJackyEZcrate && IsValid(Ent) then
                            crate = Result.Entity
                            resourceType = crate:GetResourceType()
                            resourceAmount = crate:GetResource()
                        
                            amountLoaded = Ent:TryLoadResource(resourceType, resourceAmount)
                            
                            crate:SetResource(resourceAmount - amountLoaded)
                        end          
                    -- load into machine
                    elseif Type == "Output" then
                        if Result.Entity.EZconsumes and table.HasValue(Result.Entity.EZconsumes, resourceType) then
                            Machine = Result.Entity
                            amountLoaded = Machine:TryLoadResource(self:GetResourceType(), self:GetResourceAmount())
                            self:SetResourceAmount(self:GetResourceAmount() - amountLoaded)
                        end
                    end
                end 
            end
        end
        
        self:NextThink(CurTime() + 1)
        return true
    end

    function ENT:TryLoadResource(resoureType, resourceAmount)
        if self:GetResourceType() ~= resourceType and self:GetResourceAmount() > 0 then
            return 0
        end

        self:SetResourceType(resourceType)
        self:SetResourceAmount(self:GetResourceAmount() + resourceAmount)

        return resourceAmount
    end
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()

        local origin = self:GetPos()
        local angles = self:GetAngles()
        local direction = -angles:Forward()
        render.DrawLine( origin, origin + direction * 50, Color( 255, 255, 255 ), true)
	end
end
