-- Mangago website scraper for its public server-rendered manga pages.
-- It does not execute page scripts or submit account data.
local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
local Generic=dofile(here.."../generic/source.lua")
local Source=setmetatable({}, {__index=Generic}); Source.__index=Source
local BASE="https://www.mangago.zone"
local function allowed_image_hosts(profile)
    local hosts={}
    for _,host in ipairs(profile.image_hosts or {}) do hosts[host]=true end
    return hosts
end
function Source.new(profile,parser,transport)
    assert(type(profile)=="table" and profile.id=="mangago" and profile.base_url==BASE)
    return setmetatable(Generic.new(profile,parser,transport),Source)
end
function Source:getChapterList(manga,page,callback,order)
    if type(manga)~="table" or type(manga.url)~="string" or not manga.url:match("^https://www%.mangago%.zone/work/%d+/?$") then
        return callback(nil,"Invalid Mangago title URL")
    end
    return Generic.getChapterList(self,manga,page,callback,order)
end
function Source:getPageList(chapter,callback)
    if type(chapter)~="table" or type(chapter.url)~="string" or not chapter.url:match("^https://www%.mangago%.zone/chapter/%d+/%d+/?$") then
        return callback(nil,"Invalid Mangago chapter URL")
    end
    return self:_get(chapter.url,function(body,err)
        if not body then return callback(nil,err) end
        local pages,failure=self.parser:pages(body,chapter.url)
        if pages then return callback(pages) end
        local encrypted=body:match("var%s+imgsrcs%s*=%s*['\"]([^'\"]+)['\"]")
        if not encrypted then return callback(nil,failure) end
        local manifest=dofile(here.."image_manifest.lua")
        local urls,decode_error=manifest.decode(encrypted)
        if not urls then return callback(nil,decode_error) end
        local allowed=allowed_image_hosts(self.profile); local items={}
        for _,image_url in ipairs(urls) do
            local host=image_url:match("^https://([%w%.%-]+)/")
            if not host or not allowed[host] then return callback(nil,"Mangago image host is not permitted") end
            items[#items+1]={index=#items+1,image_url=image_url,headers={},referer=chapter.url}
        end
        callback(items)
    end)
end
return Source
