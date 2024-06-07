AddCSLuaFile()

ENT.Type = "anim"
ENT.Category = "JMod - EZ Machines"
ENT.PrintName="Funnel"
ENT.Information = "Glory hole"
ENT.NoSitAllowed = true
ENT.Spawnable = true
ENT.AdminSpawnable = false
ENT.Model = "models/xqm/rails/funnel.mdl"
ENT.Mass = 150
ENT.EZconsumes={
	JMod.EZ_RESOURCE_TYPES.BASICPARTS, 
	JMod.EZ_RESOURCE_TYPES.POWER
}
ENT.IsFunnel = true

function ENT:PutEveryResourceIntoTable() 
    for _, v in pairs(JMod.EZ_RESOURCE_TYPES) do
        table.insert(self.EZconsumes, v)
    end
end


if SERVER then
    function ENT:Initialize()
        self:SetModel(self.Model)
        self:SetModelScale(0.5)
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
end

if CLIENT then
	function ENT:Draw()
		self:DrawModel()

        local origin = self:GetPos()
        local angles = self:GetAngles()
        local direction = -angles:Up()
        render.DrawLine( origin, origin + direction * 10000, Color( 255, 255, 255 ), true)
	end
end

function ENT:TryLoadResource(resourceType, resourceAmount) 
    local origin = self:GetPos()
    local angles = self:GetAngles()
    local direction = -angles:Up() * 10000

    amountLoaded = 0

    result = util.QuickTrace(origin, direction, self)

    if (IsValid(result.Entity)) then
        if (result.Entity.EZconsumes and table.HasValue(result.Entity.EZconsumes, resourceType)) then
            amountLoaded = result.Entity:TryLoadResource(resourceType, resourceAmount)
        end
    end
    
    return amountLoaded
end