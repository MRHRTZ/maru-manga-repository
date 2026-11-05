-- Native adapter for the MangaMost app's public JSON API.
local Source={}; Source.__index=Source
local API="https://mangamost.com/api/v1"
local HOST="https://mangamost.com"
local LIMIT=30
function Source.new(profile,_,transport)
    assert(type(profile)=="table" and profile.id=="mangamost" and profile.base_url==HOST and profile.api_url==API)
    return setmetatable({profile=profile,transport=assert(transport),json=require("json"),chapter_offsets={}},Source)
end
function Source:getName() return self.profile.name or "MangaMost" end
function Source:getId() return "mangamost" end
function Source:getBaseUrl() return HOST end
function Source:getLanguages() return {"en"} end
function Source:_get(url,callback)
    if type(url)~="string" or (url~=API and url:sub(1,#API+1)~=API.."/") or url:find("..",1,true) then return callback(nil,"URL outside MangaMost API") end
    self.transport:get(url,function(body,err)
        if not body then return callback(nil,err or "MangaMost request failed") end
        local ok,payload=pcall(self.json.decode,body)
        if not ok or type(payload)~="table" or type(payload.data)~="table" then return callback(nil,"Invalid MangaMost response") end
        callback(payload.data)
    end)
end
local function safe_id(value)
    if type(value)=="number" and value>=1 and value%1==0 then return tostring(value) end
    if type(value)=="string" and value:match("^%d+$") then return value end
end
local function map_manga(raw)
    if type(raw)~="table" or not safe_id(raw.id) or type(raw.title)~="string" or raw.title=="" then return nil end
    local id=safe_id(raw.id)
    return {id=id,title=raw.title,url=HOST.."/comics/"..id,source_id="mangamost",cover_url=type(raw.cover_url)=="string" and raw.cover_url or nil,
        description=raw.description or "",author=raw.author_text or "",artist="",status=raw.status_text or "",genres=type(raw.genres)=="table" and raw.genres or {}}
end
function Source:_listing(path,page,callback)
    page=math.max(1,math.min(10000,math.floor(tonumber(page) or 1)))
    local offset=(page-1)*LIMIT
    self:_get(API..path..(path:find("?",1,true) and "&" or "?").."limit="..LIMIT.."&offset="..offset,function(data,err)
        if not data then return callback(nil,err) end
        local rows=data
        if #data==0 and type(data.series)=="table" then rows=data.series end
        local items={}; for _,raw in ipairs(rows) do local item=map_manga(raw); if item then items[#items+1]=item end end
        callback({items=items,page=page,has_next=#rows>=LIMIT})
    end)
end
function Source:getPopularManga(page,callback) return self:_listing("/comics/trending",page,callback) end
function Source:getLatestUpdates(page,callback) return self:_listing("/comics/new-releases",page,callback) end
function Source:searchManga(query,page,callback)
    page=math.max(1,math.floor(tonumber(page) or 1))
    if page>1 then return callback({items={},page=page,has_next=false}) end
    local encoded=tostring(query or ""):gsub("([^%w%-._~])",function(c) return string.format("%%%02X",string.byte(c)) end)
    self:_get(API.."/search/suggestions?q="..encoded,function(data,err)
        if not data then return callback(nil,err) end
        local items={}; for _,raw in ipairs(data.series or {}) do local item=map_manga(raw); if item then items[#items+1]=item end end
        callback({items=items,page=1,has_next=false})
    end)
end
function Source:getMangaDetails(manga,callback)
    local id=type(manga)=="table" and safe_id(manga.id)
    if not id then return callback(nil,"Invalid MangaMost title ID") end
    self:_get(API.."/comics/"..id,function(raw,err)
        if not raw then return callback(nil,err) end
        local item=map_manga(raw)
        if not item then return callback(nil,"Invalid MangaMost title") end
        item.id=manga.id; item.url=manga.url or item.url; item.latest_chapter=raw.latest_chapter; item.chapters_count=raw.chapters_count or raw.source_episode_count
        callback(item)
    end)
end
function Source:getChapterList(manga,page,callback,order)
    local id=type(manga)=="table" and safe_id(manga.id); page=page or 1
    if not id then return callback(nil,"Invalid MangaMost title ID") end
    if type(page)~="number" or page<1 or page%1~=0 or page>10000 then return callback(nil,"Invalid chapter page") end
    local key=tostring(id); if page==1 then self.chapter_offsets[key]={[1]=0} end
    local offset=self.chapter_offsets[key] and self.chapter_offsets[key][page]
    if offset==nil then return callback(nil,"Load MangaMost chapter pages sequentially") end
    self:_get(API.."/comics/"..id.."/chapters?limit="..LIMIT.."&offset="..offset,function(rows,err)
        if not rows then return callback(nil,err) end
        if type(rows)~="table" then return callback(nil,"Invalid MangaMost chapter list") end
        local items={}; for _,raw in ipairs(rows) do
            local chapter_id=safe_id(raw.id); local number=tonumber(raw.chapter_number or raw.chapter_no)
            if chapter_id and type(raw.chapter_label)=="string" then items[#items+1]={id=chapter_id,manga_id=tostring(id),source_id="mangamost",name=raw.chapter_label,chapter_number=number,url=HOST.."/comics/"..id.."/chapters/"..chapter_id,upload_date=raw.published_at} end
        end
        local has_next=#rows>=LIMIT
        if has_next then self.chapter_offsets[key][page+1]=offset+LIMIT end
        if order=="asc" then table.sort(items,function(a,b) return (a.chapter_number or 0)<(b.chapter_number or 0) end) end
        callback({items=items,page=page,has_next=has_next})
    end)
end
function Source:getPageList(chapter,callback)
    local manga_id=type(chapter)=="table" and safe_id(chapter.manga_id)
    local chapter_id=type(chapter)=="table" and safe_id(chapter.id)
    if not manga_id or not chapter_id then return callback(nil,"Invalid MangaMost chapter") end
    self:_get(API.."/comics/"..manga_id.."/chapters/"..chapter_id,function(data,err)
        if not data then return callback(nil,err) end
        local pages={}; for _,raw in ipairs(data.pages or {}) do
            if type(raw.image_url)=="string" and raw.image_url:match("^https://mangamost%.com/storage/[%w%._~/%-]+$") then
                pages[#pages+1]={index=tonumber(raw.page_order) or (#pages+1),image_url=raw.image_url,headers={},referer=raw.referer or HOST.."/comics/"..manga_id.."/chapters/"..chapter_id}
            end
        end
        if #pages==0 then return callback(nil,"Chapter has no available page images") end
        callback(pages)
    end)
end
return Source
