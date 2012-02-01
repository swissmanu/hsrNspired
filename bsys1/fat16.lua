__fat16 = {
}

FAT_ENTRY = ''
toolpalette.register({})
toolpalette.enablePaste(true)









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
	local bytes = splitHexBytes(hex_string)
	local reversed = ''
	
	for i=table.getn(bytes), 1, -1 do
		reversed = reversed..bytes[i]
	end
	
	return reversed
end

-- Converts a string with hex bytes into its ascii representation
function __fat16.toAscii(hex_input)
	local bytes = splitHexBytes(hex_input)
	local text = ''
	
	for i=1,table.getn(bytes) do
		text = text .. string.char(tonumber(prefixHex(bytes[i])))
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
	return toAscii(hex)
end

function __fat16.convertExtension(hex)
	return toAscii(hex)
end

function __fat16.convertAttribute(hex)
	local hex = prefixHex(hex)
	local bits = toBits(tonumber(hex))
	local attributes = ''
	
	for i=1,table.getn(bits), 1 do
		if bits[i] == 1 then
			if i == 1 then attributes = attributes..'r(ead only) '
			elseif i == 2 then attributes = attributes..'h(idden) '
			elseif i == 3 then attributes = attributes..'s(ystem) '
			elseif i == 4 then attributes = attributes..'v(olume) '
			elseif i == 5 then attributes = attributes..'d(irectory) '
			elseif i == 6 then attributes = attributes..'a(rchive) '
			end
		end
	end
	
	
	return attributes
end

function __fat16.convertTime(hex)
	local hex = reverseHexString(hex)
	local bits = toBits(tonumber(prefixHex(hex)),16)
	local hourBits = ''
	local minuteBits = ''
	local secondBits = ''
	
	for i=table.getn(bits),1,-1 do
		if i <= 5 then secondBits = secondBits..bits[i]
		elseif i > 5 and i <= 11 then minuteBits = minuteBits..bits[i]
		elseif i > 11 then hourBits = hourBits..bits[i]
		end
	end
	
	local time = bitStringToDec(hourBits)..':'..
				 bitStringToDec(minuteBits)..':'..
				 bitStringToDec(secondBits)*2
	return time
end

function __fat16.convertDate(hex)
	local hex = reverseHexString(hex)
	local bits = toBits(tonumber(prefixHex(hex)),16)
	local dayBits = ''
	local monthBits = ''
	local yearBits = ''
	
	for i=table.getn(bits),1,-1 do
		if i <= 5 then dayBits = dayBits..bits[i]
		elseif i > 5 and i <= 9 then monthBits = monthBits..bits[i]
		elseif i > 9 then yearBits = yearBits..bits[i]
		end
	end
	
	local date = bitStringToDec(dayBits)..'.'..
				 bitStringToDec(monthBits)..'.'..
				 1980+bitStringToDec(yearBits)
	return date
end

function __fat16.convertCluster(hex)
	local reversed = prefixHex(reverseHexString(hex))
	return reversed..', '..tonumber(reversed)
end

function __fat16.convertFilesize(hex)
	local reversed = prefixHex(reverseHexString(hex))
	return reversed..', '..tonumber(reversed).. 'byte'
end

-- HANDLERS --------------------------------------------------------------
function __fat16.handleFieldValue(index, value)
	if index	 == 1 then 	return 'Filename: '..convertFilename(value)
	elseif index == 2 then	return 'Extension: '..convertExtension(value)
	elseif index == 3 then	return 'Attribute: '..convertAttribute(value)
	--elseif index == 4 then  reserved ;-)
	elseif index == 5 then	return 'Time last changed: '..convertTime(value)
	elseif index == 6 then	return 'Date last changed: '..convertDate(value)
	elseif index == 7 then	return 'First cluster: '..convertCluster(value)
	elseif index == 8 then  return 'Actual size: '..convertFilesize(value)
	end
	
	return ""
end


function __fat16.main()
	
	on.paste = function()
		FAT_ENTRY = clipboard.getText()
		platform.window:invalidate()
	end

	function drawOutput(gc, input)
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
			field_offsets = calculateFieldOffsets(field_lengths)

			-- PROCESS FIELDS --------------------------------------------------------
			for i=1, table.getn(field_lengths) do
				offset = field_offsets[i]*2
				length = field_lengths[i]*2
				field_value = string.sub(input, offset+1, offset+length)

				processed_value = handleFieldValue(i, field_value)
				if processed_value ~= "" then
					gc:drawString(processed_value,10,10+18*(i-1),"top")
				end
			end
		end
	end

	function on.paint(gc)
		if FAT_ENTRY ~= '' then
			drawOutput(gc, FAT_ENTRY)
		else
			gc:setFont('sansserif','r',10)
			gc:setColorRGB(255,0,0)
			gc:drawString("Please copy/paste 32 hex bytes", 10,10, "top")
		end
	end
end

__fat16.main()