-- Native Komiku adapter. It consumes HTML only and never executes site scripts.
local Source={}; Source.__index=Source
local API="https://api.komiku.org"
local BASE="https://komiku.org"
local function encode(value)
    return (tostring(value or ""):gsub("([^%w%-._~])",function(c) return string.format("%%%02X",string.byte(c)) end))
end
function Source.new(profile,parser,transport)
    assert(type(profile)=="table" and profile.id=="komiku" and profile.base_url==BASE and profile.api_url==API)
    return setmetatable({profile=profile,parser=assert(parser),transport=assert(transport)},Source)
end
function Source:getName() return self.profile.name or "Komiku" end
function Source:getId() return "komiku" end
function Source:getBaseUrl() return BASE end
function Source:getLanguages() return {"id"} end
function Source:_get(url,callback)
    if type(url)~="string" or (url~=BASE and url:sub(1,#BASE+1)~=BASE.."/" and url~=API and url:sub(1,#API+1)~=API.."/") then return callback(nil,"URL outside Komiku source") end
    self.transport:get(url,callback)
end
function Source:_list(path,query,page,callback)
    page=math.max(1,math.min(1000,math.floor(tonumber(page) or 1)))
    local url=API..path
    if page>1 then url=API..path:gsub("/$","").."/page/"..page.."/" end
    local params={}
    if query and query~="" then params[#params+1]="s="..encode(query) end
    if path:find("/hot/",1,true) then params[#params+1]="orderby=meta_value_num" end
    if path=="/manga/" and not (query and query~="") then params[#params+1]="orderby=modified" end
    if #params>0 then url=url.."?"..table.concat(params,"&") end
    return self:_get(url,function(body,err)
        if not body then return callback(nil,err) end
        local result,failure=self.parser:list(body,url)
        if not result then return callback(nil,failure) end
        result.page=page; callback(result)
    end)
end
function Source:getPopularManga(page,callback) return self:_list("/other/hot/",nil,page,callback) end
function Source:getLatestUpdates(page,callback) return self:_list("/manga/",nil,page,callback) end
function Source:searchManga(query,page,callback) return self:_list("/manga/",query,page,callback) end
function Source:getMangaDetails(manga,callback)
    if type(manga)~="table" or type(manga.url)~="string" or not manga.url:match("^https://komiku%.org/manga/[%w%-_]+/?$") then return callback(nil,"Invalid Komiku manga URL") end
    self:_get(manga.url,function(body,err) if not body then return callback(nil,err) end; callback(self.parser:details(body,manga.url,manga)) end)
end
function Source:getChapterList(manga,page,callback,order)
    if page and page~=1 then return callback(nil,"Komiku chapter pages are listed together") end
    self:_get(manga.url,function(body,err)
        if not body then return callback(nil,err) end
        local items,failure=self.parser:chapters(body,manga.url,manga)
        if not items then return callback(nil,failure) end
        table.sort(items,function(a,b)
            if a.chapter_number and b.chapter_number and a.chapter_number~=b.chapter_number then
                if order=="asc" then return a.chapter_number<b.chapter_number end
                return a.chapter_number>b.chapter_number
            end
            local an,bn=tostring(a.name):lower(),tostring(b.name):lower()
            if an==bn then return tostring(a.id)<tostring(b.id) end
            if order=="asc" then return an<bn end
            return an>bn
        end)
        callback({items=items,page=1,has_next=false})
    end)
end
function Source:getPageList(chapter,callback)
    if type(chapter)~="table" or type(chapter.url)~="string" or not chapter.url:match("^https://komiku%.org/") then return callback(nil,"Invalid Komiku chapter URL") end
    self:_get(chapter.url,function(body,err) if not body then return callback(nil,err) end; callback(self.parser:pages(body,chapter.url)) end)
end
return Source
