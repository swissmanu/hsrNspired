__fat16 = {}

toolpalette.register({})
toolpalette.enablePaste(true)

__fat16.input_hex_value = ''

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


-- OUTPUT CONVERTERS -----------------------------------------------------
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

-- HANDLERS --------------------------------------------------------------
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

function __fat16.drawOutput(gc, input)
	gc:setFont('sansserif','r',10)

	-- FAT16 Entry Definition:
	local entry_byte_length = 32
	local field_lengths = {
		8		-- Filename
		,3		-- Extension
		,1		-- Attribute
		,10		-- Reserved
		,2		-- Time last changed
		,2		-- Date last changed
		,2		-- First cluster
		,4		-- Filesize in bytes
	}

	--======================================================================--
	-- MAIN
	--======================================================================--
	--input = '47494D504F52542048202020184DF8A9383E383E0000D18C683C0400AD200000'
	if string.len(input) ~= entry_byte_length*2 then
		gc:setColorRGB(255,0,0)
		gc:drawString("Please paste a value with "..entry_byte_length.." hex bytes!",10,10,"top")
	else
		-- CALCULATE FIELD OFFSETS -----------------------------------------------
		field_offsets = __fat16.calculateFieldOffsets(field_lengths)

		-- PROCESS FIELDS --------------------------------------------------------
		for i=1, table.getn(field_lengths) do
			offset = field_offsets[i]*2
			length = field_lengths[i]*2
			field_value = string.sub(input, offset+1, offset+length)

			processed_value = __fat16.handleFieldValue(i, field_value)
			if processed_value ~= "" then
				gc:drawString(processed_value,10,10+18*(i-1),"top")
			end
		end
	end
end


function __fat16.main()
	
	on.paste = function()
		__fat16.input_hex_value = clipboard.getText()
		platform.window:invalidate()
	end

	on.paint = function(gc)
		if __fat16.input_hex_value ~= '' then
			__fat16.drawOutput(gc, __fat16.input_hex_value)
		else
			gc:setFont('sansserif','r',10)
			gc:setColorRGB(255,0,0)
			gc:drawString("Please copy/paste 32 hex bytes", 10,10, "top")
		end
	end
end

__fat16.main()