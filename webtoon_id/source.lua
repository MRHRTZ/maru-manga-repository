-- Scrape public, server-rendered WEBTOON pages; never runs site JavaScript.
local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
local Generic=dofile(here.."../generic/source.lua")
local Source=setmetatable({}, {__index=Generic}); Source.__index=Source
local BASE="https://www.webtoons.com"
local function locale_for(profile)
    return profile.locale or (profile.id=="webtoon_id" and "id" or "en")
end
local function next_page(html,body)
    local ok,doc=pcall(html.parse,body,math.min(50000,math.max(5000,math.floor(#body/2))))
    if not ok or not doc then return false end
    local nodes=doc:select(".paginate .pg_next")
    return nodes and nodes[1]~=nil and nodes[1].attributes.class~="pg_next off"
end
function Source.new(profile,parser,transport,html)
    assert((profile.id=="webtoon" or profile.id=="webtoon_id") and profile.base_url==BASE)
    local expected_locale=profile.id=="webtoon_id" and "id" or "en"
    assert(locale_for(profile)==expected_locale)
    -- Keep older installed repository catalogs compatible with the current
    -- episode markup, which nests title, date and likes under one anchor.
    profile.chapter_title_selector=profile.chapter_title_selector or ".subj"
    -- WEBTOON uses different card classes on the ranking and update pages
    -- than on search. Keep all three selectors as data fallbacks so every
    -- public listing can share the profile-based parser.
    profile.list_link_selector=nil
    profile.list_link_selectors={"a._ranking_title_a","a._originals_title_a","a._card_item"}
    local self=Generic.new(profile,parser,transport)
    self.html=assert(html)
    self.locale=expected_locale
    return setmetatable(self,Source)
end
function Source:getChapterList(manga,page,callback,order)
    page=page or 1
    if type(manga)~="table" or type(manga.url)~="string" or not manga.url:match("^https://www%.webtoons%.com/"..self.locale.."/[%w%-_/]+/list%?") then return callback(nil,"Invalid WEBTOON title URL") end
    if type(page)~="number" or page<1 or page%1~=0 or page>1000 then return callback(nil,"Invalid WEBTOON episode page") end
    local url=manga.url..(manga.url:find("?",1,true) and "&" or "?").."page="..page
    self:_get(url,function(body,err)
        if not body then return callback(nil,err) end
        local items,failure=self.parser:chapters(body,url,manga)
        if not items then return callback(nil,failure) end
        for _,item in ipairs(items) do
            -- The lightweight HTML parser can preserve entities in href attributes.
            item.url=item.url:gsub("&amp;","&")
            item.chapter_number=tonumber(item.url:match("[?&]episode_no=(%d+)")) or tonumber(item.url:match("/episode%-(%d+)/viewer")) or item.chapter_number
        end
        table.sort(items,function(a,b)
            local an,bn=a.chapter_number or 0,b.chapter_number or 0
            if order=="asc" then return an<bn end
            return an>bn
        end)
        callback({items=items,page=page,has_next=next_page(self.html,body)})
    end)
end
function Source:getMangaDetails(manga,callback)
    return Generic.getMangaDetails(self,manga,function(detail,err)
        if detail and type(detail.author)=="string" then
            detail.author=detail.author:gsub("[Aa]uthor%s+[Ii]nfo",""):gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
        end
        callback(detail,err)
    end)
end
return Source
