-- Public server-rendered MangaRock pages; no site JavaScript is executed.
local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
local Generic=dofile(here.."../generic/source.lua")
local Source=setmetatable({}, {__index=Generic}); Source.__index=Source
local BASE="https://mangarock.one"
function Source.new(profile,parser,transport)
    assert(profile.id=="mangarock" and profile.base_url==BASE)
    local self=Generic.new(profile,parser,transport)
    self.chapter_offsets={}
    return setmetatable(self,Source)
end
function Source:getPopularManga(page,callback)
    if page and page~=1 then return callback({items={},page=page,has_next=false}) end
    return self:_get(BASE.."/",function(body,err)
        if not body then return callback(nil,err) end
        local result,failure=self.parser:popular(body,BASE.."/")
        if not result then return callback(nil,failure) end
        result.page=1
        callback(result)
    end)
end
function Source:getChapterList(manga,page,callback,order)
    page=page or 1
    if type(manga)~="table" or type(manga.url)~="string" or not manga.url:match("^https://mangarock%.one/manga/[%w_-]+/?$") then return callback(nil,"Invalid MangaRock manga URL") end
    if type(page)~="number" or page<1 or page%1~=0 or page>10000 then return callback(nil,"Invalid chapter page") end
    local key=manga.url
    if page==1 then self.chapter_offsets[key]={[1]=0} end
    local offsets=self.chapter_offsets[key]
    local offset=offsets and offsets[page]
    if offset==nil then return callback(nil,"Load MangaRock chapter pages sequentially") end
    local endpoint=key:gsub("/$","").."/chapters?lang=EN&offset="..offset
    return self:_get(endpoint,function(body,err)
        if not body then return callback(nil,err) end
        local result,failure=self.parser:chapterBatch(body,key,manga,offset)
        if not result then return callback(nil,failure) end
        offsets[page+1]=result.has_next and result.next_offset or nil
        if order=="asc" then
            table.sort(result.items,function(a,b)
                if a.chapter_number and b.chapter_number and a.chapter_number~=b.chapter_number then return a.chapter_number<b.chapter_number end
                return a.url<b.url
            end)
        end
        result.page=page
        callback(result)
    end)
end
return Source
