-- Called AFTER the original civic screen includes TechAndCivicSupport.
-- Only the parade's foreground icon changes; all other unlocks keep stock data.
local basePopulate=PopulateUnlockablesForCivic
if not basePopulate then
    print('[ParadeV38][CIVIC] ERROR: PopulateUnlockablesForCivic unavailable')
    return
end
local function ColorIcon(real)
    return setmetatable({}, {__index=function(_,key)
        if key=='SetIcon' then
            return function(_,name,...)
                if name=='ICON_PROJECT_MILITARY_PARADE' then
                    name='ICON_PROJECT_MILITARY_PARADE_COLOR'
                end
                return real:SetIcon(name,...)
            end
        end
        local value=real[key]
        if type(value)=='function' then
            return function(_,...) return value(real,...) end
        end
        return value
    end})
end
function PopulateUnlockablesForCivic(playerID,civicID,itemIM,governmentIM,...)
    if not itemIM then return basePopulate(playerID,civicID,itemIM,governmentIM,...) end
    local proxy=setmetatable({GetInstance=function()
        local instance=itemIM:GetInstance()
        return setmetatable({Icon=ColorIcon(instance.Icon)}, {__index=instance})
    end}, {__index=itemIM})
    return basePopulate(playerID,civicID,proxy,governmentIM,...)
end
print('[ParadeV38][CIVIC] READY: explicit colour parade icon')
