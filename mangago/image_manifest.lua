-- Decode Mangago's AES-128-CBC/base64 page URL manifest without running site scripts.
local bit=require("bit")
local mime=require("mime")
local bxor,band,rshift,lshift=bit.bxor,bit.band,bit.rshift,bit.lshift
local function mul(a,b)
    local out=0
    for _=1,8 do
        if band(b,1)~=0 then out=bxor(out,a) end
        local high=band(a,0x80)~=0
        a=band(lshift(a,1),0xff)
        if high then a=bxor(a,0x1b) end
        b=rshift(b,1)
    end
    return band(out,0xff)
end
local function pow(a,n)
    local out=1
    while n>0 do
        if n%2==1 then out=mul(out,a) end
        a=mul(a,a); n=math.floor(n/2)
    end
    return out
end
local function rol8(n,k) return band(bxor(lshift(n,k),rshift(n,8-k)),0xff) end
local sbox,invsbox={},{}
for n=0,255 do
    local inv=n==0 and 0 or pow(n,254)
    local s=bxor(inv,rol8(inv,1),rol8(inv,2),rol8(inv,3),rol8(inv,4),0x63)
    s=band(s,0xff); sbox[n]=s; invsbox[s]=n
end
local function unhex(s)
    local out={}
    for i=1,#s,2 do out[#out+1]=tonumber(s:sub(i,i+1),16) end
    return out
end
local function expand_key(key)
    local out={}; for i=1,16 do out[i]=key[i] end
    local generated=16; local round=1
    while generated<176 do
        local t={out[generated-3],out[generated-2],out[generated-1],out[generated]}
        if generated%16==0 then
            t={t[2],t[3],t[4],t[1]}
            for i=1,4 do t[i]=sbox[t[i]] end
            t[1]=bxor(t[1],round); round=mul(round,2)
        end
        for i=1,4 do generated=generated+1; out[generated]=bxor(out[generated-16],t[i]) end
    end
    return out
end
local function add_round_key(state,keys,round)
    local offset=round*16
    for i=1,16 do state[i]=bxor(state[i],keys[offset+i]) end
end
local function inv_shift_rows(s)
    for row=1,3 do
        local old={s[1+row],s[5+row],s[9+row],s[13+row]}
        for col=0,3 do s[1+4*col+row]=old[((col-row)%4)+1] end
    end
end
local function inv_sub_bytes(s) for i=1,16 do s[i]=invsbox[s[i]] end end
local function inv_mix_columns(s)
    for col=0,3 do
        local i=1+4*col; local a,b,c,d=s[i],s[i+1],s[i+2],s[i+3]
        s[i]=bxor(mul(a,14),mul(b,11),mul(c,13),mul(d,9))
        s[i+1]=bxor(mul(a,9),mul(b,14),mul(c,11),mul(d,13))
        s[i+2]=bxor(mul(a,13),mul(b,9),mul(c,14),mul(d,11))
        s[i+3]=bxor(mul(a,11),mul(b,13),mul(c,9),mul(d,14))
    end
end
local function decrypt_block(block,keys)
    local state={}; for i=1,16 do state[i]=block[i] end
    add_round_key(state,keys,10)
    for round=9,1,-1 do
        inv_shift_rows(state); inv_sub_bytes(state); add_round_key(state,keys,round); inv_mix_columns(state)
    end
    inv_shift_rows(state); inv_sub_bytes(state); add_round_key(state,keys,0)
    return state
end
local KEY=unhex("e11adc3949ba59abbe56e057f20f883e")
local IV=unhex("1234567890abcdef1234567890abcdef")
local function decrypt(cipher)
    local decoded=mime.unb64(cipher)
    if type(decoded)~="string" or #decoded==0 or #decoded%16~=0 then return nil,"Invalid encrypted image manifest" end
    local keys=expand_key(KEY); local previous=IV; local output={}
    for offset=1,#decoded,16 do
        local block={}
        for i=1,16 do block[i]=decoded:byte(offset+i-1) end
        local plain=decrypt_block(block,keys)
        for i=1,16 do plain[i]=bxor(plain[i],previous[i]) end
        for i=1,16 do output[#output+1]=string.char(plain[i]) end
        previous=block
    end
    local text=table.concat(output):gsub("%z+$","")
    local urls={}
    for value in text:gmatch("([^,]+)") do
        value=value:gsub("^%s+",""):gsub("%s+$","")
        if value~="" then
            if #value>8192 or not value:match("^https://[%w%.%-]+/[%w%._~/%-%%?=&]+$") then return nil,"Invalid URL in Mangago image manifest" end
            urls[#urls+1]=value
        end
    end
    if #urls==0 then return nil,"Mangago image manifest is empty" end
    return urls
end
return {decode=decrypt}
