local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
local Generic=dofile(here.."../generic/parser.lua")
local Parser={}
function Parser.new(html,resolve,clean,profile,digest)
    local parser=Generic.new(html,resolve,clean,profile,digest)
    local popular_profile={}
    for k,v in pairs(profile) do popular_profile[k]=v end
    popular_profile.list_selector=".popularslider .bs"
    popular_profile.next_selector=".no-pagination-for-popular-today"
    local popular_parser=Generic.new(html,resolve,clean,popular_profile,digest)
    function parser:popular(body,base) return popular_parser:list(body,base) end
    function parser:chapterBatch(body,base,manga,offset)
        if type(body)~="string" or #body>4*1024*1024 then return nil,"Invalid chapter response" end
        local ok,doc=pcall(html.parse,body,math.min(50000,math.max(5000,math.floor(#body/2))))
        if not ok or not doc then return nil,"Invalid chapter HTML" end
        local nodes=doc:select(".chapter-batch-meta")
        local meta=nodes and nodes[1] and nodes[1].attributes
        if not meta or (meta["data-has-more"]~="true" and meta["data-has-more"]~="false") then return nil,"Missing chapter pagination metadata" end
        local next_offset=tonumber(meta["data-next-offset"])
        if not next_offset or next_offset%1~=0 or next_offset<offset then return nil,"Invalid chapter offset" end
        local items,err=self:chapters(body,base,manga)
        if not items then return nil,err end
        local filtered,seen={},{}
        local slug=base:match("/manga/([%w_-]+)/?$")
        if not slug then return nil,"Invalid manga URL" end
        slug=slug:gsub("([^%w])","%%%1")
        for _,item in ipairs(items) do
            if not item.url:match("^https://mangarock%.one/read/"..slug.."/en/[%w_.%-]+/?$") then return nil,"Chapter outside configured manga or language" end
            if not seen[item.url] then filtered[#filtered+1]=item; seen[item.url]=true end
        end
        local more=meta["data-has-more"]=="true"
        if more and (#filtered==0 or next_offset<=offset) then return nil,"Chapter pagination made no progress" end
        return {items=filtered,has_next=more,next_offset=next_offset}
    end
    return parser
end
return Parser
