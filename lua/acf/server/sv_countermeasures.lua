--[[
SV fn ACF_CreateFlare(pos: Vector3, dir: Vector3, params: {
    Lifetime: number,
    Temp: number,
    RadarSig: number
}) -> Entity | nil
]]

local FLARE_TAG = Color(0,0,1,1) --Blue set to 1 for flare

function ACF_CreateFlare(pos, vel, owner, params)
	local ent = ents.Create( "ace_flare" )
    if not IsValid(ent) then return end

    ent:SetPos(pos)
    ent:SetAngles(vel:Angle())
    ent.Life = params.Lifetime / (0.4 * ACFM.FlareBurnMultiplier)

    ent:Spawn()
    ent:SetOwner(owner)
    ent:CPPISetOwner(owner:CPPIGetOwner())

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetVelocity(vel)
    end

    ent:SetColor(FLARE_TAG)
    ent.Thermal = params.Temp
    ent.FirstThermal = params.Temp
    ent.RadarSig = params.RadarSig

    return ent
end

