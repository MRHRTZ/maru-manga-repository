-- Scrape public, server-rendered WEBTOON pages; never runs site JavaScript.
local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
local Generic=dofile(here.."../generic/source.lua")
local Source=setmetatable({}, {__index=Generic}); Source.__index=Source
local BASE="https://www.webtoons.com"
local function next_page(html,body)
    local ok,doc=pcall(html.parse,body,math.min(50000,math.max(5000,math.floor(#body/2))))
    if not ok or not doc then return false end
    local nodes=doc:select(".paginate .pg_next")
    return nodes and nodes[1]~=nil and nodes[1].attributes.class~="pg_next off"
end
function Source.new(profile,parser,transport,html)
    assert(profile.id=="webtoon" and profile.base_url==BASE)
    local self=Generic.new(profile,parser,transport)
    self.html=assert(html)
    return setmetatable(self,Source)
end
function Source:getChapterList(manga,page,callback,order)
    page=page or 1
    if type(manga)~="table" or type(manga.url)~="string" or not manga.url:match("^https://www%.webtoons%.com/en/[%w%-_/]+/list%?") then return callback(nil,"Invalid WEBTOON title URL") end
    if type(page)~="number" or page<1 or page%1~=0 or page>1000 then return callback(nil,"Invalid WEBTOON episode page") end
    local url=manga.url..(manga.url:find("?",1,true) and "&" or "?").."page="..page
    self:_get(url,function(body,err)
        if not body then return callback(nil,err) end
        local items,failure=self.parser:chapters(body,url,manga)
        if not items then return callback(nil,failure) end
        for _,item in ipairs(items) do item.chapter_number=tonumber(item.url:match("/episode%-(%d+)/viewer")) end
        table.sort(items,function(a,b)
            local an,bn=a.chapter_number or 0,b.chapter_number or 0
            if order=="asc" then return an<bn end
            return an>bn
        end)
        callback({items=items,page=page,has_next=next_page(self.html,body)})
    end)
end
return Source
