-- Komiku-specific normalization around the shared, non-executing HTML parser.
local Parser={}; Parser.__index=Parser
function Parser.new(html,resolve,clean,profile,digest)
    local generic=dofile((debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or "") .. "../generic/parser.lua")
    -- Keep older/default profiles working when they were installed without
    -- the Komiku listing selectors from repository metadata.
    profile.list_selector=profile.list_selector or "div.bge"
    profile.list_link_selector=profile.list_link_selector or "a"
    profile.list_title_selector=profile.list_title_selector or "h3"
    profile.list_cover_selector=profile.list_cover_selector or "img"
    -- Komiku's current server-rendered markup exposes author/status in
    -- microdata and table rows. These selectors override old installed
    -- catalogs that used unsupported CSS :contains() pseudo-selectors.
    profile.title_selector="h1 span[itemprop=\"name\"]"
    profile.description_selector="p.desc"
    profile.author_selector="span[itemprop=\"author\"] meta[itemprop=\"name\"]"
    profile.artist_selector="span[itemprop=\"artist\"] meta[itemprop=\"name\"]"
    profile.status_selector="meta[itemprop=\"creativeWorkStatus\"]"
    profile.genre_selector="ul.genre li.genre a span"
    profile.cover_selector=".ims img"
    profile.cover_attribute="src"
    profile.list_cover_selector="img"
    profile.latest_selector=".new1 a"
    profile.latest_label="terbaru"
    profile.metadata_row_selector="table.inftable tr"
    local wrapped=generic.new(html,resolve,clean,profile,digest)
    return setmetatable({html=wrapped},Parser)
end
function Parser:list(body,base)
    local result,err=self.html:list(body,base)
    if not result then return nil,err end
    -- The API host serves markup but manga pages live on komiku.org.
    for _,item in ipairs(result.items) do
        local slug=item.url:match("/manga/([^/?#]+)")
        if slug then
            item.url="https://komiku.org/manga/"..slug.."/"
            -- Keep filesystem/library identity separate from the source URL.
            item.id=slug
        end
    end
    result.has_next=result.has_next or #result.items>=10
    return result
end
function Parser:details(...) return self.html:details(...) end
function Parser:chapters(body,base,manga)
    local chapters,err=self.html:chapters(body,base,manga)
    if not chapters then return nil,err end
    for _,chapter in ipairs(chapters) do
        local number=chapter.name:lower():match("chapter%s*(%d+%.?%d*)") or chapter.name:lower():match("episode%s*(%d+%.?%d*)") or chapter.name:lower():match("eps?%.?%s*(%d+%.?%d*)")
        chapter.chapter_number=tonumber(number)
    end
    return chapters
end
function Parser:pages(body,base)
    local pages,err=self.html:pages(body,base)
    if not pages then return nil,err end
    local clean={}
    for _,page in ipairs(pages) do
        if not page.image_url:lower():find("komiku-promosi",1,true) then
            page.headers={ ["Accept-Language"]="id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" }
            page.index=#clean+1; clean[#clean+1]=page
        end
    end
    if #clean==0 then return nil,"Chapter has no readable images" end
    return clean
end
return Parser
