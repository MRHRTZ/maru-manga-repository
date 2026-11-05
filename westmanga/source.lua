-- WestManga's public catalog API plus server-rendered manga and chapter pages.
-- The adapter never evaluates code from the site.
local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
local Generic=dofile(here.."../generic/source.lua")
local Source=setmetatable({}, {__index=Generic}); Source.__index=Source
local BASE="https://www.westmanga.shop"
local API=BASE.."/api/manga"
local LIMIT=60
local function encode(value)
    return tostring(value or ""):gsub("([^%w%-._~])",function(c) return string.format("%%%02X",string.byte(c)) end)
end
local function slug(value)
    return type(value)=="string" and #value>0 and #value<=160 and value:match("^[%w%-_%.]+$")~=nil
end
local function map_manga(raw)
    if type(raw)~="table" or not slug(raw.slug) or type(raw.title)~="string" or raw.title=="" then return nil end
    local cover
    if type(raw.coverUrl)=="string" and raw.coverUrl:match("^https://cdn%.westmanga%.shop/mangas/[%w%-_%.]+/[%w%-_%.]+%.[%w]+$") then cover=raw.coverUrl end
    local genres={}
    if type(raw.genres)=="table" then for _,genre in ipairs(raw.genres) do if type(genre)=="string" and #genre<=80 then genres[#genres+1]=genre end end end
    local latest=type(raw.latestChapter)=="table" and raw.latestChapter or nil
    return {id=raw.slug,slug=raw.slug,title=raw.title,url=BASE.."/manga/"..raw.slug,source_id="westmanga",cover_url=cover,
        description=type(raw.synopsis)=="string" and raw.synopsis or "",author=type(raw.author)=="string" and raw.author or "",
        status=type(raw.status)=="string" and raw.status or "",genres=genres,latest_chapter=latest and latest.title or nil,
        chapters_count=tonumber(raw.totalChapters)}
end
function Source.new(profile,parser,transport)
    assert(type(profile)=="table" and profile.id=="westmanga" and profile.base_url==BASE and profile.api_url==API)
    local self=Generic.new(profile,parser,transport)
    self.json=require("json")
    return setmetatable(self,Source)
end
function Source:_api(query,callback)
    local url=API.."?"..query
    self:_get(url,function(body,err)
        if not body then return callback(nil,err or "WestManga request failed") end
        local ok,payload=pcall(self.json.decode,body)
        if not ok or type(payload)~="table" or payload.success~=true then return callback(nil,"Invalid WestManga response") end
        callback(payload)
    end)
end
function Source:_listing(sort,query,page,callback)
    page=math.floor(tonumber(page) or 1)
    if page<1 or page>10000 then return callback(nil,"Invalid WestManga page") end
    local params="page="..page.."&limit=24&sort="..sort
    if query and query~="" then params=params.."&q="..encode(query) end
    self:_api(params,function(payload,err)
        if not payload then return callback(nil,err) end
        if type(payload.mangas)~="table" or type(payload.totalPages)~="number" then return callback(nil,"Invalid WestManga manga list") end
        local items={}
        for _,raw in ipairs(payload.mangas) do local item=map_manga(raw); if item then items[#items+1]=item end end
        callback({items=items,page=page,has_next=page<payload.totalPages})
    end)
end
function Source:getPopularManga(page,callback) return self:_listing("popular",nil,page,callback) end
function Source:getLatestUpdates(page,callback) return self:_listing("latest",nil,page,callback) end
function Source:searchManga(query,page,callback) return self:_listing("latest",query,page,callback) end
function Source:getMangaDetails(manga,callback)
    local key=type(manga)=="table" and (manga.slug or manga.id)
    if not slug(key) then return callback(nil,"Invalid WestManga title") end
    self:_api("page=1&limit=24&sort=latest&q="..encode(key),function(payload,err)
        if not payload then return callback(nil,err) end
        for _,raw in ipairs(payload.mangas or {}) do
            if raw.slug==key then
                local item=map_manga(raw)
                if item then item.id=manga.id or item.id; item.url=BASE.."/manga/"..raw.slug; return callback(item) end
            end
        end
        callback(nil,"WestManga title was not found")
    end)
end
function Source:getChapterList(manga,page,callback,order)
    local manga_slug=type(manga)=="table" and (manga.slug or manga.id)
    page=math.floor(tonumber(page) or 1)
    if not slug(manga_slug) or type(manga.url)~="string" or manga.url~=BASE.."/manga/"..manga_slug then return callback(nil,"Invalid WestManga title URL") end
    if page<1 or page>10000 then return callback(nil,"Invalid WestManga chapter page") end
    local direction=order=="asc" and "asc" or "desc"
    self:_api("slug="..encode(manga_slug).."&chapterPage="..page.."&chapterLimit="..LIMIT.."&chapterOrder="..direction,function(payload,err)
        if not payload then return callback(nil,err) end
        if type(payload.chapters)~="table" or type(payload.total)~="number" then return callback(nil,"Invalid WestManga chapter list") end
        local items={}
        for _,raw in ipairs(payload.chapters) do
            if type(raw)=="table" and slug(raw.slug) then
                local number=tonumber(raw.number)
                local title=type(raw.title)=="string" and raw.title or (number and ("Chapter "..number))
                if title and title~="" then items[#items+1]={id=raw.slug,manga_id=manga_slug,source_id="westmanga",name=title,chapter_number=number,url=BASE.."/read/"..manga_slug.."/"..raw.slug} end
            end
        end
        callback({items=items,page=page,has_next=page*LIMIT<payload.total})
    end)
end
function Source:getPageList(chapter,callback)
    if type(chapter)~="table" or type(chapter.url)~="string" or not chapter.url:match("^https://www%.westmanga%.shop/read/[%w%-_%.]+/[%w%-_%.]+$") then return callback(nil,"Invalid WestManga chapter URL") end
    self:_get(chapter.url,function(body,err)
        if not body then return callback(nil,err) end
        callback(self.parser:pages(body,chapter.url))
    end)
end
return Source
