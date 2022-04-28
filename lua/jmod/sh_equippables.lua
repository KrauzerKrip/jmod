-- these are custom things that can be "put on" a player, separate from armor
local Slots={
    "glowsticks" -- slot for glowsticky things
}
JMod.Equippables={
    ["one_glowstick"]={
        slot="glowsticks",
        mdls={
            {
                mdl="models/props/army/glowstick.mdl",
                mat="models/props/army/jlowstick_on",
                scl=1,
                bon="ValveBiped.Bip01_Spine4",
                pos=Vector(-12,-10,-3),
                ang=Angle(-70,0,90)
            }
        },
        thinkFunc=function(ply,col,timeLeft)
            if(CLIENT)then
                local Mult,Col=(timeLeft>30 and 1) or .5
                local R,G,B=math.Clamp(col.r+20,0,255),math.Clamp(col.g+20,0,255),math.Clamp(col.b+20,0,255)
                local DLight=DynamicLight(ply:EntIndex())
                if(DLight)then
                    DLight.Pos=ply:GetShootPos()+ply:GetAimVector()*10-ply:GetUp()*20
                    DLight.r=R
                    DLight.g=G
                    DLight.b=B
                    DLight.Brightness=.8*Mult^2
                    DLight.Size=180*Mult^2
                    DLight.Decay=15000
                    DLight.DieTime=CurTime()+.3
                    DLight.Style=0
                end
            end
        end
    },
    ["rave_glowsticks"]={
        slot="glowsticks",
        mdls={
            {
                mdl="models/xqm/coastertrack/special_full_loop_4.mdl",
                mat="models/props/army/jlowstick_on",
                scl=.015,
                bon="ValveBiped.Bip01_Spine4",
                col=Color(200,50,50),
                pos=Vector(-4,4,0),
                ang=Angle(0,100,0)
            },
            {
                mdl="models/xqm/coastertrack/special_full_loop_4.mdl",
                mat="models/props/army/jlowstick_on",
                scl=.0075,
                bon="ValveBiped.Bip01_R_Hand",
                col=Color(50,200,50),
                pos=Vector(0,0,0),
                ang=Angle(0,120,0)
            },
            {
                mdl="models/xqm/coastertrack/special_full_loop_4.mdl",
                mat="models/props/army/jlowstick_on",
                scl=.0075,
                bon="ValveBiped.Bip01_L_Hand",
                col=Color(50,50,200),
                pos=Vector(0,0,0),
                ang=Angle(0,120,0)
            }
        },
        thinkFunc=function(ply,col,timeLeft)
            if(CLIENT)then
                local Mult,Col=(timeLeft>30 and 1) or .5
                local R,G,B=math.Clamp(col.r+20,0,255),math.Clamp(col.g+20,0,255),math.Clamp(col.b+20,0,255)
                local DLight=DynamicLight(ply:EntIndex())
                if(DLight)then
                    DLight.Pos=ply:GetShootPos()+ply:GetAimVector()*20-ply:GetUp()*20
                    DLight.r=R
                    DLight.g=G
                    DLight.b=B
                    DLight.Brightness=.8*Mult^2
                    DLight.Size=220*Mult^2
                    DLight.Decay=15000
                    DLight.DieTime=CurTime()+.3
                    DLight.Style=0
                end
            end
        end
    }
}
local NextServerThink=0
hook.Add("Think","JModEquippableThink",function()
    local Time=CurTime()
    if((CLIENT)or(NextServerThink<Time))then
        NextServerThink=Time+.1
        for k,ply in pairs(player.GetAll())do
            if((ply:Alive())and(ply.EZequippables))then
                for slot,info in pairs(ply.EZequippables)do
                    local EquippableSpecs,TimeLeft=JMod.Equippables[info.nam],info.tim-Time
                    if(TimeLeft<=0)then
                        if(SERVER)then JMod.SetEquippable(ply,slot,nil) end
                    else
                        if(EquippableSpecs.thinkFunc)then EquippableSpecs.thinkFunc(ply,info.col,TimeLeft) end
                    end
                end
            end
        end
    end
end)
if(CLIENT)then
    hook.Add("PostPlayerDraw","JModEquippablePlayerDraw",function(ply)
        if(ply.EZequippables)then
            if not(ply.EZequippableModels)then ply.EZequippableModels={} end
            for slot,info in pairs(ply.EZequippables)do
                local EquippableSpecs=JMod.Equippables[info.nam]
                local CustomColor=Vector(info.col.r/255,info.col.g/255,info.col.b/255)
                for k,mdlInfo in pairs(EquippableSpecs.mdls)do
                    local StaticColor=mdlInfo.col and Vector(mdlInfo.col.r/255,mdlInfo.col.g/255,mdlInfo.col.b/255)
                    local MdlKey=info.nam..tostring(k)
                    local cModel=ply.EZequippableModels[MdlKey]
                    if(cModel)then
                        local BoneIndex=ply:LookupBone(mdlInfo.bon)
                        if(BoneIndex)then
                            local Pos,Ang=ply:GetBonePosition(BoneIndex)
                            if((Pos)and(Ang))then
                                local Up,Right,Forward=Ang:Up(),Ang:Right(),Ang:Forward()
                                Pos=Pos+Right*mdlInfo.pos.x+Forward*mdlInfo.pos.y+Up*mdlInfo.pos.z
                                Ang:RotateAroundAxis(Right,mdlInfo.ang.p)
                                Ang:RotateAroundAxis(Up,mdlInfo.ang.y)
                                Ang:RotateAroundAxis(Forward,mdlInfo.ang.r)
                                JMod.RenderModel(cModel,Pos,Ang,nil,StaticColor or CustomColor,nil,mdlInfo.fb)
                            end
                        end
                    else
                        ply.EZequippableModels[MdlKey]=JMod.MakeModel(ply,mdlInfo.mdl,mdlInfo.mat,mdlInfo.scl)
                    end
                end
            end
        end
    end)
    net.Receive("JMod_EquippableSync",function()
        local ply=net.ReadEntity()
        if(IsValid(ply))then
            ply.EZequippables=net.ReadTable()
            ply.EZequippableModels=nil
        end
    end)
elseif(SERVER)then
    local function SyncEquippables(ply)
        net.Start("JMod_EquippableSync")
        net.WriteEntity(ply)
        net.WriteTable(ply.EZequippables)
        net.Broadcast()
    end
    function JMod.SetEquippable(ply,slot,name,color,endTime)
        ply.EZequippables=ply.EZequippables or {}
        if(name)then
            ply.EZequippables[slot]={
                nam=name,
                col=color,
                tim=endTime
            }
        else
            ply.EZequippables[slot]=nil
        end
        SyncEquippables(ply)
    end
    hook.Add("DoPlayerDeath","JModEquippablesDeath",function(ply)
        ply.EZequippables={}
        SyncEquippables(ply)
    end)
end