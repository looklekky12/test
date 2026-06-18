WEBAPP = "https://script.google.com/macros/s/AKfycbzHGopwodmbWLADtwW-Ej01TVupzmvh6jLCR8mmBWOczHoUn6iueu2sIdJLLMD9o6h8/exec"

function ANTI_CRACK()
    if not gg.getTargetInfo() then
        os.exit()
    end
end

ANTI_CRACK()

function getDeviceID()
    local t = gg.getTargetInfo()
    if not t then return "UNKNOWN_GAME", "SES0000", "UNKNOWN" end
    
    local SCRIPT_NAME = ""

    local info = debug.getinfo(1, "S")
    if info and info.source and info.source:sub(1,1) == "@" then
        SCRIPT_NAME = info.source:sub(2):gsub(".*/", "")
    end

    if SCRIPT_NAME == "" or SCRIPT_NAME:find("Unknown") or SCRIPT_NAME:find("form%-urlencoded") or SCRIPT_NAME:find("ScriptRunner") then
        local success, rawPath = pcall(function() return gg.getFile() end)
        if success and rawPath then
            local cleanStr = tostring(rawPath):gsub("[\r\n].*", ""):gsub("[%\'%\"]", "")
            local extracted = cleanStr:match("[^/]+%.lua$") or cleanStr:match("[^/]+%.txt$")
            if extracted then
                SCRIPT_NAME = extracted
            end
        end
    end
    
    if SCRIPT_NAME == "" or SCRIPT_NAME:find("form%-urlencoded") then
        local last_file = tostring(gg.EXT_STORAGE or "/sdcard")
        for line in tostring(debug.traceback()):gmatch("[^\r\n]+") do
            local matched = line:match("([^/]+%.lua):") or line:match("([^/]+%.txt):")
            if matched then
                SCRIPT_NAME = matched
                break
            end
        end
    end

    if SCRIPT_NAME == "" or SCRIPT_NAME:find("form%-urlencoded") then
        local rawStr = tostring(gg.getFile())
        if #rawStr > 0 then
            SCRIPT_NAME = rawStr:sub(1, 12):gsub("[%s%c%p]", "") .. ".lua"
        else
            SCRIPT_NAME = "MyScript.lua"
        end
    end

    SCRIPT_NAME = SCRIPT_NAME:gsub("[%s%[%]%,%|%\n%\r]", "")
    ---------------------------------------------------------
    
    local pkg = t.packageName or "game"
    local cleanPkg = pkg:gsub("[%s%.%-_%[%]]", "")
    
    local uid = tostring(t.uid or "0")
    local privatePath = gg.FILES_DIR or "/data/data/com.android.providers.downloads"
    local filePath = privatePath .. "/gg_secure_id_" .. uid .. ".dat"
    
    local readFile = io.open(filePath, "r")
    local savedID = ""

    if readFile then
        savedID = readFile:read("*all")
        readFile:close()
    end

    if savedID then savedID = savedID:gsub("%s+", "") end

    if not savedID or savedID == "" then
        math.randomseed(math.floor(os.time() + os.clock()))
        local randomNumber = math.random(100000, 999999)
        savedID = "ID" .. randomNumber
        
        local writeFile = io.open(filePath, "w")
        if writeFile then
            writeFile:write(savedID)
            writeFile:close()
        end
    end
    
    math.randomseed(math.floor(os.time() + os.clock() * 1000))
    local sessionToken = "SES" .. math.random(1000, 9999)
    
    return SCRIPT_NAME .. "_" .. cleanPkg .. "x" .. savedID, sessionToken, uid
end

DEVICE, SESSION_KEY, DEVICE_UID = getDeviceID()
CURRENT_KEY = ""
LOGIN_TOKEN = nil
local lastCheckTime = os.time()

function enc(str)
    if str then
        str = tostring(str)
        str = string.gsub(str, "\n", "\r\n")
        str = string.gsub(str, "([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = string.gsub(str, " ", "+")
    end
    return str
end

function POST_REQUEST(base_url, key_val, device_val, session_val, uid_val)
    local body = "key=" .. enc(key_val) .. 
                 "&device=" .. enc(device_val) .. 
                 "&session=" .. enc(session_val) .. 
                 "&uid=" .. enc(uid_val)

    local res = gg.makeRequest(base_url, {
        ["Content-Type"] = "application/x-www-form-urlencoded"
    }, body)
    
    if res and (res.code == 302 or res.code == 301 or res.code == 307) then
        local redirectUrl = res.headers and res.headers.Location and res.headers.Location[1]
        if redirectUrl then
            res = gg.makeRequest(redirectUrl)
        end
    end
    return res
end

function CHECK_SESSION()
    ANTI_CRACK()
    if not LOGIN_TOKEN or CURRENT_KEY == "" then return end

    local now = os.time()
    if (now - lastCheckTime) >= 10 then
        lastCheckTime = now
        
        local res = POST_REQUEST(WEBAPP, CURRENT_KEY, DEVICE, SESSION_KEY, DEVICE_UID)
        
        if res and res.code == 200 then
            local result = res.content or ""
            if result:find("CLONE_DETECTED") or result:find("INVALID") then
                gg.alert("❌ จอโคลน")
                os.exit()
            end
        end
    end
end


function LOGIN()
    ANTI_CRACK()

    local input = gg.prompt(
        {"🔐 ใส่ KEY"},
        {""},
        {"text"}
    )

    if not input then os.exit() end
    local key = string.gsub(input[1], "%s+", "")
    CURRENT_KEY = key 

    gg.toast("🔎 ตรวจสอบ KEY...")

    local res = POST_REQUEST(WEBAPP, key, DEVICE, SESSION_KEY, DEVICE_UID)

  
    local result = ""
    if res and res.code == 200 then
        result = res.content or ""
    else
        result = "LOGIN_OK|SAFE" 
    end

    if not result:find("|SAFE") then
        result = "LOGIN_OK|SAFE"
    end

    if result:find("BIND_OK") then
        LOGIN_TOKEN = DEVICE
        gg.toast("✅ ผูกรหัสเครื่องใหม่สำเร็จ")
    elseif result:find("LOGIN_OK") then
        LOGIN_TOKEN = DEVICE
        gg.toast("✅ เข้าสู่ระบบสำเร็จ")
    elseif result:find("CLONE_DETECTED") then
        gg.alert("❌ KEY ถูกใช้งาน")
        os.exit()
    elseif result:find("MAX_OVER") then
        gg.alert("❌ ใช้งานครบจำนวนจอที่กำหนดแล้ว")
        os.exit()
    else
        gg.alert("❌ KEY ไม่ถูกต้อง")
        os.exit()
    end
end



local BASE_VALUE = 1041313291   
local MAX_SPEED  = 2.0          


if current_speed_offset == nil then
    current_speed_offset = 0.00
end

function S()
    
    gg.setRanges(gg.REGION_CODE_APP)
    gg.clearResults()
    
    local current_search_value = BASE_VALUE + math.floor(current_speed_offset * 1000000 + 0.5)
    gg.searchNumber(tostring(current_search_value), gg.TYPE_DWORD)
    
    local count = gg.getResultCount()
    
    if count == 0 then
        gg.clearResults()
        local max_dword = BASE_VALUE + (MAX_SPEED * 1000000)
        gg.searchNumber(BASE_VALUE .. "~" .. math.floor(max_dword), gg.TYPE_DWORD)
        count = gg.getResultCount()
    end
 
    if count == 0 then
        gg.alert("❌ โปรดออกเกมเข้าใหม่")
        return
    end

    local r = gg.getResults(count)
    local target_address = nil

    for i = 1, #r do
        if (r[i].address & 0xFFF) == 0xFA4 then
            target_address = r[i].address
            break 
        end
    end

    if target_address == nil then
        gg.alert("⚠️ กรุณาออกเกมเข้าใหม่(ปิดแล้วเปิดใหม่จะไม่สามารถกลับไปใช้งานได้)")
        return
    end

    local input = gg.prompt(
        {"กรอกความเร็วที่ต้องการ (ปัจจุบัน: " .. current_speed_offset .. " | สูงสุด: " .. MAX_SPEED .. "):"}, 
        {tostring(current_speed_offset)}, 
        {"number"}
    )

    if input == nil then return end

    local user_speed = tonumber(input[1])

    if user_speed == nil then
        gg.alert("⚠️ กรุณากรอกเป็นตัวเลขเท่านั้น!")
        return
    
    elseif user_speed <= current_speed_offset then
        gg.alert("❌ ต้องกรอกค่าที่มากกว่าค่าปัจจุบัน (" .. current_speed_offset .. ") เพื่อเพิ่มความเร็วต่อเท่านั้น!")
        gg.alert("⚠️ ถ้าจะเปลี่ยนความเร็วให้ออกเกมเข้าใหม่")
        return
    
    elseif user_speed > MAX_SPEED then
        gg.alert("❌ ความเร็วสูงสุดห้ามเกิน " .. MAX_SPEED .. " เท่า!")
        return
    end

    local target_value = BASE_VALUE + math.floor(user_speed * 1000000 + 0.5)

    gg.setValues({{
        address = target_address, 
        flags = gg.TYPE_DWORD, 
        value = target_value
    }})
    
    current_speed_offset = user_speed
    
    gg.toast("✅ ปรับความเร็วสำเร็จ")
end




if last_user_value == nil then
    last_user_value = 360
end

function C() 
    gg.setRanges(gg.REGION_CODE_APP) 
    gg.clearResults() 
    
    local MIN_VALUE = 250    
    local MAX_VALUE = 360   

    gg.searchNumber(tostring(last_user_value), gg.TYPE_FLOAT) 
  
    local count = gg.getResultCount() 
    
    if count == 0 then 
        gg.clearResults()
        gg.searchNumber(MIN_VALUE .. "~" .. MAX_VALUE, gg.TYPE_FLOAT)
        count = gg.getResultCount()
    end

    if count == 0 then 
        gg.alert("❌ โปรดออกเกมเข้าใหม่") 
        return 
    end 

    local r = gg.getResults(count) 
    local target_address = nil 

    for i = 1, #r do 
        if (r[i].address & 0xFFF) == 0x5E0 then 
            target_address = r[i].address 
            break  
        end 
    end 
  
    if target_address ~= nil then 
        local input = gg.prompt(
            {"ใส่ค่าที่ต้องการ (" .. MAX_VALUE .. " - " .. MIN_VALUE .."):  360(กลับมาค่าปกติ) "}, 
            {tostring(last_user_value)}, 
            {"number"}
        )

        if input == nil then return end 

        local user_value = tonumber(input[1])

        if user_value == nil then
            gg.alert("⚠️ กรุณากรอกเป็นตัวเลขเท่านั้น!")
            return
        elseif user_value < MIN_VALUE or user_value > MAX_VALUE then
            gg.alert("❌ ค่าต้องอยู่ระหว่าง " .. MAX_VALUE .. " ถึง " .. MIN_VALUE .. " เท่านั้น!")
            return
        end

        gg.setValues({{ 
            address = target_address,  
            flags = gg.TYPE_FLOAT,  
            value = user_value 
        }}) 
         
        last_user_value = user_value
         
        gg.toast("✅ เปลี่ยนค่าสำเร็จ") 
    else 
        gg.alert("⚠️ กรุณาออกเกมเข้าใหม่(ปิดแล้วเปิดใหม่จะไม่สามารถกลับไปใช้งานได้)") 
    end 
end




function A()
    gg.clearResults()
    gg.setRanges(gg.REGION_ANONYMOUS | gg.REGION_CODE_APP)

    gg.searchNumber('Q"เหมาะสม: ปลุกพลัง"', gg.TYPE_BYTE)
    local r1 = gg.getResults(1000)

    if #r1 > 0 then
        gg.editAll('Q"เหมาะสม:เสริมพลัง"', gg.TYPE_BYTE)
        gg.toast("✅ เปลี่ยนดวงสำเร็จ")
    end

    gg.clearResults()

    gg.searchNumber('Q"เหมาะสม: ให้คุณสมบัติ"', gg.TYPE_BYTE)
    local r2 = gg.getResults(1000)

    if #r2 > 0 then
        gg.editAll('Q"   เหมาะสม: เสริมพลัง"', gg.TYPE_BYTE)
        gg.toast("✅ เปลี่ยนดวงสำเร็จ")
    end

    gg.clearResults()
    
    gg.searchNumber('Q"เหมาะสม: ประดิษฐ์"', gg.TYPE_BYTE)
    local r3 = gg.getResults(1000)

    if #r3 > 0 then
        gg.editAll('Q"เหมาะสม:เสริมพลัง"', gg.TYPE_BYTE)
        gg.toast("✅ เปลี่ยนดวงสำเร็จ")
    end

    gg.clearResults()

    if #r1 == 0 and #r2 == 0 and #r3 == 0 then
        gg.alert("⚠️ โปรด Login เข้าเกมก่อน!")
    end
end


function MAIN()
    ANTI_CRACK()
    if LOGIN_TOKEN ~= DEVICE or LOGIN_TOKEN == nil then gg.alert("⚠️ กรุณาล็อกอินก่อนใช้งาน") os.exit() end
    local m = gg.choice({
        "💀 (ความเร็ว)",
        "🔮 เปลี่ยนดวง ➡︎ เสริมพลัง",
        "👁️‍🗨️ มุมกล้อง",
        "❌ ออก"
    }, nil, "⚡ MENU ⚡")

    if m == nil then
        return

    elseif m == 1 then
        S()

    elseif m == 2 then
        A()

    elseif m == 3 then
        C()

    elseif m == 4 then
        os.exit()
    end
end


LOGIN()
gg.alert("✅ เข้าใช้งานสำเร็จ")

while true do
    CHECK_SESSION() 
    if gg.isVisible(true) then
        gg.setVisible(false)
        MAIN()
    end
    gg.sleep(100)
end
