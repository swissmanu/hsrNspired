-- Global namespace
__fat16 = {}

-- Toolpalette
toolpalette.register({})
toolpalette.enablePaste(true)

-- Constants
__fat16.TITLE					= 'FAT16 Entry Utility'
__fat16.STATE_WRONG_INPUT		= -1
__fat16.STATE_WELCOME    		= 0
__fat16.STATE_CALCULATED  		= 1
__fat16.TOTAL_BYTES_TO_PROCESS	= 32
__fat16.FIELD_LENGTHS = {
	8		-- Filename
	,3		-- Extension
	,1		-- Attribute
	,10		-- Reserved
	,2		-- Time last changed
	,2		-- Date last changed
	,2		-- First cluster
	,4		-- Filesize in bytes
}

-- Namespace variables
__fat16.state	= __fat16.STATE_WELCOME
__fat16.result	= {}



-- FUNCTIONS -------------------------------------------------------------

-- Adds '0x' to a string, mostly a hex byte ;)
function __fat16.prefixHex(hex)
	if string.find(hex, '0x') == nil then hex = '0x'..hex end
	return hex
end

-- Splits a String with hex bytes into an array, each entry with one byte
function __fat16.splitHexBytes(hex_input)
	local bytes = {}
	for i=1, string.len(hex_input)/2, 1 do
		bytes[i] = string.sub(hex_input,i*2-1,i*2)
	end
	return bytes		
end

-- Reverses Hex bytes in a string
function __fat16.reverseHexString(hex_string)
	local bytes = __fat16.splitHexBytes(hex_string)
	local reversed = ''
	
	for i=table.getn(bytes), 1, -1 do
		reversed = reversed..bytes[i]
	end
	
	return reversed
end

-- Converts a string with hex bytes into its ascii representation
function __fat16.toAscii(hex_input)
	local bytes = __fat16.splitHexBytes(hex_input)
	local text = ''
	
	for i=1,table.getn(bytes) do
		text = text .. string.char(tonumber(__fat16.prefixHex(bytes[i])))
	end
	
	return text
end

-- Converts a decimal number to a bit table. By passing ensure_length
-- you can add 0's, if the converted table has not the expected size
function __fat16.toBits(num,ensure_length)
	if ensure_length == nil then ensure_length = 0 end
	
    local t={}
    while num>0 do
        rest=math.fmod(num,2)
        t[#t+1]=rest
        num=(num-rest)/2
    end
	
	if table.getn(t) < ensure_length then
		for i=table.getn(t)+1, ensure_length do
			t[i] = 0
		end
	end

    return t
end

-- Converts a string with bits to a decimal number
function __fat16.bitStringToDec(bitString)
	local value = 0
	local bitString = string.reverse(bitString)
	
	for i=1, string.len(bitString) do
		local bit = tonumber(string.sub(bitString, i, i))
		value = value + bit*2^(i-1)
	end
	
	return value
end

-- Takes a table with field lengths and calculates offset values which can
-- be used to cut out specific fields from a source record.
-- Offsets get returned in a table.
function __fat16.calculateFieldOffsets(field_lengths)
	local prev_offset = 0
	local field_offsets = {}
	
	for i=1, table.getn(field_lengths) do
		local offset = 0
		if i > 1 then
			offset = prev_offset + field_lengths[i-1]
		end

		field_offsets[i] = offset
		prev_offset = offset
	end
	
	return field_offsets
end



function __fat16.convertFilename(hex)
	return __fat16.toAscii(hex)
end

function __fat16.convertExtension(hex)
	return __fat16.toAscii(hex)
end

function __fat16.convertAttribute(hex)
	local hex = __fat16.prefixHex(hex)
	local bits = __fat16.toBits(tonumber(hex))
	local attributes = ''
	
	for i=1,table.getn(bits), 1 do
		if bits[i] == 1 then
			if i == 1 then attributes = attributes..'r '
			elseif i == 2 then attributes = attributes..'h '
			elseif i == 3 then attributes = attributes..'s '
			elseif i == 4 then attributes = attributes..'v '
			elseif i == 5 then attributes = attributes..'d '
			elseif i == 6 then attributes = attributes..'a '
			end
		end
	end
	
	return attributes
end

function __fat16.convertTime(hex)
	local hex = __fat16.reverseHexString(hex)
	local bits = __fat16.toBits(tonumber(__fat16.prefixHex(hex)),16)
	local hourBits = ''
	local minuteBits = ''
	local secondBits = ''
	
	for i=table.getn(bits),1,-1 do
		if i <= 5 then secondBits = secondBits..bits[i]
		elseif i > 5 and i <= 11 then minuteBits = minuteBits..bits[i]
		elseif i > 11 then hourBits = hourBits..bits[i]
		end
	end
	
	local time = __fat16.bitStringToDec(hourBits)..':'..
				 __fat16.bitStringToDec(minuteBits)..':'..
				 __fat16.bitStringToDec(secondBits)*2
	return time
end

function __fat16.convertDate(hex)
	local hex = __fat16.reverseHexString(hex)
	local bits = __fat16.toBits(tonumber(__fat16.prefixHex(hex)),16)
	local dayBits = ''
	local monthBits = ''
	local yearBits = ''
	
	for i=table.getn(bits),1,-1 do
		if i <= 5 then dayBits = dayBits..bits[i]
		elseif i > 5 and i <= 9 then monthBits = monthBits..bits[i]
		elseif i > 9 then yearBits = yearBits..bits[i]
		end
	end
	
	local date = __fat16.bitStringToDec(dayBits)..'.'..
				 __fat16.bitStringToDec(monthBits)..'.'..
				 __fat16.bitStringToDec(yearBits)+1980
	return date
end

function __fat16.convertCluster(hex)
	local reversed = __fat16.prefixHex(__fat16.reverseHexString(hex))
	return reversed..', '..tonumber(reversed)
end

function __fat16.convertFilesize(hex)
	local reversed = __fat16.prefixHex(__fat16.reverseHexString(hex))
	return reversed..', '..tonumber(reversed).. 'byte'
end



function __fat16.handleFieldValue(index, value)
	if index	 == 1 then 	return 'Filename: '..__fat16.convertFilename(value)
	elseif index == 2 then	return 'Extension: '..__fat16.convertExtension(value)
	elseif index == 3 then	return 'Attribute: '..__fat16.convertAttribute(value)
	--elseif index == 4 then  reserved ;-)
	elseif index == 5 then	return 'Time last changed: '..__fat16.convertTime(value)
	elseif index == 6 then	return 'Date last changed: '..__fat16.convertDate(value)
	elseif index == 7 then	return 'First cluster: '..__fat16.convertCluster(value)
	elseif index == 8 then  return 'Actual size: '..__fat16.convertFilesize(value)
	end
	
	return ""
end

-- Processes a valid hex input string and returns the results as table with
-- strings.
function __fat16.processInput(input)
	local field_offsets = __fat16.calculateFieldOffsets(__fat16.FIELD_LENGTHS)
	local result = {}
	
	for i=1, table.getn(__fat16.FIELD_LENGTHS) do
		offset = field_offsets[i]*2
		length = __fat16.FIELD_LENGTHS[i]*2
		field_value = string.sub(input, offset+1, offset+length)

		processed_value = __fat16.handleFieldValue(i, field_value)
		if processed_value ~= "" then
			result[i] = processed_value
		end
	end
	
	return result
end

-- Checks an input value if it is valid and returns the result as boolean.
function __fat16.validateInput(input)
	local valid = true
	
	if string.len(input) ~= __fat16.TOTAL_BYTES_TO_PROCESS*2 then
		valid = false
	end
	
	return valid
end

-- Draws a message. You can pass a title which gets drawn bigger, but this
-- is optional (pass '' if you dont need a title)
function __fat16.drawMessage(title, text, r,g,b, gc)
	local y = 10
	gc:setColorRGB(r,g,b)
	
	if(title ~= '') then
		gc:setFont('sansserif','r',12)
		gc:drawString(title, 10,y, 'top')
		y = y + 23
	end
	gc:setFont('sansserif','r',10)
	gc:drawString(text, 10,y, 'top')
end

-- Draws each item of a table on its own line.
function __fat16.drawTable(tab, r,g,b, gc)
	gc:setFont('sansserif','r',10)
	gc:setColorRGB(r,g,b)
	for i=1, table.getn(tab) do
		local line = tab[i]
		if line ~= nil then gc:drawString(tab[i], 10,10+17*(i-1), 'top') end
	end
end





-- Setup the event handlers
function __fat16.main()
	-- Picks the pasted value from clipboard and validates it.
	-- If valid, the value gets processed and the state changes to STATE_CALCULATED.
	-- Otherwise to STATE_WRONG_INPUT.
	-- After all, a new rendering of the view is triggered.
	on.paste = function()
		local input = clipboard.getText()
		
		if __fat16.validateInput(input) then
			__fat16.result = __fat16.processInput(input)
			__fat16.state = __fat16.STATE_CALCULATED
		else
			__fat16.state = __fat16.STATE_WRONG_INPUT
		end
		
		platform.window:invalidate()
	end

	-- Renders the view
	on.paint = function(gc)
		if __fat16.state == __fat16.STATE_WELCOME then
			__fat16.drawMessage(__fat16.TITLE,'Paste a valid, 32 byte hex string to display\nall contained values.', 0,0,0,gc)
		elseif __fat16.state == __fat16.STATE_CALCULATED then
			__fat16.drawTable(__fat16.result, 0,0,0,gc)
		elseif __fat16.state == __fat16.STATE_WRONG_INPUT then
			__fat16.drawMessage('Invalid input!','Please paste a valid, 32 byte hex value.', 255,0,0,gc)
		end
	end
end


-- Start
__fat16.main()