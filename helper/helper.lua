-----------------------------------------------------------------------------
-- lootName2Copper()
--
-- Turns a lootname like 1 Gold 3 Silver 40 Copper to total copper 10340
-----------------------------------------------------------------------------
function lootName2Copper(item)
	local i = 0
	local g,s,c = 0
	local money = 0

	i = string.find(item, MI_TXT_GOLD )
	if i then
		g = tonumber( string.sub(item,0,i-1) )
		item = string.sub(item,i+5,string.len(item))
		money = money + ((g or 0) * COPPER_PER_GOLD)
	end
	i = string.find(item, MI_TXT_SILVER )
	if i then
		s = tonumber( string.sub(item,0,i-1) )
		item = string.sub(item,i+7,string.len(item))
		money = money + ((s or 0) * COPPER_PER_SILVER)
	end
	i = string.find(item, MI_TXT_COPPER )
	if i then
		c = tonumber( string.sub(item,0,i-1) )
		money = money + (c or 0)
	end

	return money
end -- lootName2Copper()

-----------------------------------------------------------------------------
-- copper2text()
--
-- Turns a full copper amount to a readable string, eg. 10340 = 1g 3s 40c
-----------------------------------------------------------------------------
function copper2text(copper)
	local g,s,c

	g = floor(copper / COPPER_PER_GOLD)
	s = floor(copper / COPPER_PER_SILVER) - g * SILVER_PER_GOLD
	c = copper - g * COPPER_PER_GOLD - s * COPPER_PER_SILVER

	if g > 0 then
  		return mifontWhite..g..mifontYellow..'g '..mifontWhite..s ..mifontSubWhite..'s '..mifontWhite..c..mifontGold..'c'
	end

	if s > 0 then
  		return mifontWhite..s ..mifontSubWhite..'s '..mifontWhite..c..mifontGold..'c'
	end

	return mifontWhite..c..mifontGold..'c'
end


function split(str, sep)
    if sep == nil then
        sep = '%s'
    end

    local res = {}
    local func = function(w)
        table.insert(res, w)
    end

    string.gsub(str, '[^'..sep..']+', func)
    return res
end
