-- Convert decoded MangaDex API objects into UI-independent models.
local M = {}
local function localized(value)
    if type(value) ~= "table" then return "" end
    if type(value.en)=="string" then return value.en end
    local keys = {}
    for key,entry in pairs(value) do if type(key)=="string" and type(entry)=="string" then keys[#keys + 1] = key end end
    table.sort(keys)
    return value[keys[1]] or ""
end

function M.manga(item)
    if type(item) ~= "table" or type(item.id) ~= "string" then return nil end
    local a = type(item.attributes)=="table" and item.attributes or {}
    local result = { id = item.id, source_id = "mangadex", title = localized(a.title),
        description = localized(a.description), status = type(a.status)=="string" and a.status or "unknown", genres = {},
        url = "https://mangadex.org/title/" .. item.id }
    for _, tag in ipairs(type(a.tags)=="table" and a.tags or {}) do
        local attributes=type(tag)=="table" and type(tag.attributes)=="table" and tag.attributes or {}
        local name = localized(attributes.name)
        if name ~= "" then result.genres[#result.genres + 1] = name end
    end
    for _, relation in ipairs(type(item.relationships)=="table" and item.relationships or {}) do
        relation=type(relation)=="table" and relation or {}
        local attrs = type(relation.attributes)=="table" and relation.attributes or {}
        if relation.type == "author" then result.author = type(attrs.name)=="string" and attrs.name or nil
        elseif relation.type == "artist" then result.artist = type(attrs.name)=="string" and attrs.name or nil
        elseif relation.type == "cover_art" and type(attrs.fileName)=="string" and attrs.fileName:match("^[%w._%-]+$") then
            result.cover_url = "https://uploads.mangadex.org/covers/" .. item.id .. "/" .. attrs.fileName
        end
    end
    return result
end

-- Convert the API's UTC ISO-8601 timestamp without using device timezone.
local function utc_timestamp(value)
    if type(value) ~= "string" or not (value:match("Z$") or value:match("%+00:00$")) then return nil end
    local y,mo,d,h,mi,se=value:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
    y,mo,d,h,mi,se=tonumber(y),tonumber(mo),tonumber(d),tonumber(h),tonumber(mi),tonumber(se)
    if not y or mo<1 or mo>12 or d<1 or d>31 or h>23 or mi>59 or se>60 then return nil end
    if mo<=2 then y=y-1 end
    local era=math.floor(y/400); local yoe=y-era*400
    local mp=mo+(mo>2 and -3 or 9)
    local doy=math.floor((153*mp+2)/5)+d-1
    local doe=yoe*365+math.floor(yoe/4)-math.floor(yoe/100)+doy
    return (era*146097+doe-719468)*86400+h*3600+mi*60+se
end
function M.chapter(item, manga_id)
    if type(item) ~= "table" or type(item.id) ~= "string" then return nil end
    local a = type(item.attributes)=="table" and item.attributes or {}
    -- External chapters can point to restricted sites; do not follow them.
    if type(a.externalUrl)=="string" and a.externalUrl~="" then return nil end
    local number = type(a.chapter)=="string" and a.chapter or nil
    local name = number and ("Chapter " .. number) or "Oneshot"
    if type(a.title)=="string" and a.title ~= "" then name = name .. ": " .. a.title end
    local result = {id = item.id, manga_id = manga_id, name = name,
        chapter_number = tonumber(number), upload_date = utc_timestamp(a.publishAt),
        url = "https://mangadex.org/chapter/" .. item.id}
    for _, relation in ipairs(type(item.relationships)=="table" and item.relationships or {}) do
        if type(relation)=="table" and relation.type == "scanlation_group" then
            result.scanlator = type(relation.attributes)=="table" and type(relation.attributes.name)=="string" and relation.attributes.name or nil
            break
        end
    end
    return result
end

function M.pages(response)
    if type(response) ~= "table" or type(response.baseUrl) ~= "string" or
       type(response.chapter) ~= "table" or type(response.chapter.hash) ~= "string" or
       type(response.chapter.data) ~= "table" then return nil, "Invalid page response" end
    local authority,server_path=response.baseUrl:match("^https://([^/]+)(.*)$")
    if not authority then return nil,"Invalid image server" end
    local host,port=authority:match("^([%w%.%-]+):(%d+)$")
    if not host then host=authority:match("^([%w%.%-]+)$") end
    if not host or not (host=="uploads.mangadex.org" or host=="mangadex.network" or host:match("%.mangadex%.network$")) or (port and (tonumber(port)<1 or tonumber(port)>65535)) then return nil,"Invalid image server" end
    if server_path~="" then
        if not server_path:match("^/[%w/._~%-]+/?$") or server_path:find("//",1,true) then return nil,"Invalid image server path" end
        for segment in server_path:gmatch("[^/]+") do if segment=="." or segment==".." then return nil,"Invalid image server path" end end
        server_path=server_path:gsub("/$","")
    end
    if not response.chapter.hash:match("^[%x]+$") then return nil, "Invalid image server" end
    local base="https://" .. authority .. server_path
    local pages = {}
    for index, filename in ipairs(response.chapter.data) do
        if type(filename) ~= "string" or not filename:match("^[%w._-]+$") then
            return nil, "Invalid image filename"
        end
        pages[index] = {index = index, image_url = base .. "/data/" .. response.chapter.hash .. "/" .. filename, headers = {}, report_mangadex=true}
    end
    if #pages == 0 then return nil, "Chapter has no pages" end
    return pages
end
return M
