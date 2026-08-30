-- gggmovespeed: 显示当前移动速度（跑步/坐骑/驭龙/飞行/游泳），支持左键拖拽移动，位置自动保存

-- 可拖拽的框架（覆盖文字区域，用于接收鼠标）
local frame = CreateFrame("Frame", "gggmovespeedFrame", UIParent)
frame:SetSize(400, 32)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")

-- 显示文字，填满整个框架并居中
local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
text:SetAllPoints(frame)
text:SetJustifyH("CENTER")
text:SetTextColor(1, 1, 1) -- 纯白色

-- 读取上次保存的位置（默认屏幕中央偏上 200 像素）
local db = gggmovespeedDB or {}
frame:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 200)

-- 拖拽：开始拖动 / 松手停住并保存位置
frame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local _, _, _, x, y = self:GetPoint(1)
    db.x, db.y = x, y
    gggmovespeedDB = db
end)

-- 德鲁伊形态名称表（spellID）
local DRUID_FORMS = {
    [5487] = "熊形态",      -- 熊形态
    [1068998] = "巨熊形态", -- 巨熊形态
    [768] = "猫形态",       -- 猎豹形态
    [783] = "旅行形态",     -- 旅行形态
    [1066] = "水栖形态",    -- 水栖形态
    [33943] = "飞行形态",   -- 飞行形态
    [401020] = "苍穹形态",  -- 苍穹形态
}

local function GetDruidFormLabel()
    if GetShapeshiftFormID then
        local formID = GetShapeshiftFormID()
        if formID then
            return DRUID_FORMS[formID] or "变形"
        end
    end
    return nil
end

-- 100% 基础跑动速度 = 7 码/秒
local BASE_RUN_SPEED = 7
local updateTimer = 0

-- 刷新并显示速度（战斗/副本内 GetUnitSpeed 返回「秘密数值」无法运算，由 pcall 兜底）
local function UpdateDisplay()
    -- 驭龙术时 GetUnitSpeed 返回 0，需改用 GetGlidingInfo（该值非秘密值，可正常运算）
    local gliding = false
    local speed
    local GetGliding = (C_PlayerInfo and C_PlayerInfo.GetGlidingInfo) or GetGlidingInfo
    if GetGliding then
        local isGliding, _, forwardSpeed = GetGliding()
        gliding = isGliding
        if forwardSpeed and forwardSpeed > 0 then
            speed = forwardSpeed
        end
    end

    if not speed then
        -- cur: 实时速度；run/fly/swim: 各模式理论速度（含天赋、装备、条件加速如 Trailblazer +30%）
        local cur, run, fly, swim = GetUnitSpeed("player")
        if cur then
            local theoretical = run
            if IsFlying() then
                theoretical = fly and fly > 0 and fly or run
            elseif IsSwimming() then
                theoretical = swim and swim > 0 and swim or run
            end
            -- 取理论速度与实时速度的较大值：
            -- 理论速度覆盖脱战加速等条件加成，实时速度覆盖急奔/猛虎冲刺等瞬时爆发
            speed = math.max(cur, theoretical or cur)
        end
    end

    if not speed then
        text:SetText("") -- 玩家不在世界中（如登出/过场）时清空
        return
    end

    local percent = speed / BASE_RUN_SPEED * 100

    -- 判断当前移动模式（德鲁伊变形形态优先识别）
    local label
    if gliding then
        label = "驭龙"
    else
        local formLabel = GetDruidFormLabel()
        if formLabel then
            label = formLabel
        elseif IsFlying() then
            label = "飞行"
        elseif IsSwimming() then
            label = "游泳"
        elseif IsMounted() then
            label = "坐骑"
        else
            label = "移动"
        end
    end

    text:SetText(string.format("%s: %.1f%%", label, percent))
end

frame:SetScript("OnUpdate", function(self, elapsed)
    updateTimer = updateTimer - elapsed
    if updateTimer <= 0 then
        updateTimer = 0.1 -- 每 0.1 秒刷新一次

        -- 战斗中 GetUnitSpeed 返回「秘密数值」，无法做算术，跳过刷新以保持上次显示
        if not InCombatLockdown() then
            -- pcall 兜底：副本内等边缘情况仍可能返回秘密数值，捕获后静默跳过
            pcall(UpdateDisplay)
        end
    end
end)
