bit32 = require("bit32")

-- Credits to CrazedProgrammer for this function (and init code for the function)
local hex = {"F0F0F0", "F2B233", "E57FD8", "99B2F2", "DEDE6C", "7FCC19", "F2B2CC",
            "4C4C4C", "999999", "4C99B2", "B266E5", "3366CC", "7F664C", "57A64E",
	    "CC4C4C", "191919"}
local rgb = {}
for i=1,16,1 do
  rgb[i] = {tonumber(hex[i]:sub(1, 2), 16), tonumber(hex[i]:sub(3, 4), 16), tonumber(hex[i]:sub(5, 6), 16)}
end
local rgb2 = {}
for i=1,16,1 do
  rgb2[i] = {}
  for j=1,16,1 do
    rgb2[i][j] = {(rgb[i][1] * 34 + rgb[j][1] * 20) / 54,
    (rgb[i][2] * 34 + rgb[j][2] * 20) / 54, (rgb[i][3] * 34 + rgb[j][3] * 20) / 54}
  end
end
colors.fromRGB2 = function (r, g, b)
  local dist = 1e100
  local d = 1e100
  local color1 = -1
  local color2 = -1
  for i=1,16,1 do
    for j=1,16,1 do
      d = math.sqrt((math.max(rgb2[i][j][1], r) - math.min(rgb2[i][j][1], r)) ^ 2 +
      (math.max(rgb2[i][j][2], g) - math.min(rgb2[i][j][2], g)) ^ 2 +
      (math.max(rgb2[i][j][3], b) - math.min(rgb2[i][j][3], b)) ^ 2)
      if d < dist then
        dist = d
        color1 = i - 1
        color2 = j - 1
      end
    end
  end
  return 2 ^ color1, 2 ^ color2
end

-- Convenience function to convert from RGB555 to RGB888
function rgb555torgb888(r, g, b)
	r = bit32.bor(bit32.lshift(r, 3), bit32.rshift(r, 2))
	g = bit32.bor(bit32.lshift(g, 3), bit32.rshift(g, 2))
	b = bit32.bor(bit32.lshift(b, 3), bit32.rshift(b, 2))
	return r, g, b
end
 
colors.toRGB = function(color)
  return unpack(rgb[math.floor(math.log(color) / math.log(2) + 1)])
end

--[ This section opens the file if it's specified, and checks if it's valid ]--
if arg[1] == nil then
	print("Error: No file was specified")
	return 1
end

f = assert(io.open(arg[1], "rb"))
bitmap = f:read("*all")
assert(f:close())

if string.sub(bitmap, 1, 2) ~= "BM" then
	print("Error: The specified image is not a bitmap file")
	return 1
end

--[ This section gets information from the bitmap file header ]--
-- Get file size
filesize = 0
i = 3
while i >= 0 do
	filesize = bit32.bor(filesize, bit32.lshift(string.byte(bitmap, i+3, i+3), 8*i))
	i=i-1
end

-- Check if the filesize is correct
if string.len(bitmap) ~= filesize then
	print("Error: Filesize is not correct! The file may be corrupt.")
	return 1
end

-- Get offset
offset = 0
i=3
while i >= 0 do
	offset = bit32.bor(offset, bit32.lshift(string.byte(bitmap, i+11, i+11), 8*i))
	i=i-1
end

--[ This section gets information from the DIB header ]--
dib_size = 0
i=3
while i >= 0 do
	dib_size = bit32.bor(dib_size, bit32.lshift(string.byte(bitmap, i+15, i+15), 8*i))
	i=i-1
end

-- Get width of bitmap
bmp_width = 0
i=3
while i >= 0 do
	bmp_width = bit32.bor(bmp_width, bit32.lshift(string.byte(bitmap, i+19, i+19), 8*i))
	i=i-1
end

-- Get height of bitmap
bmp_height = 0
i=3
while i >= 0 do
	bmp_height = bit32.bor(bmp_height, bit32.lshift(string.byte(bitmap, i+23, i+23), 8*i))
	i=i-1
end

-- Get amount of planes
bmp_planes = 0
i=1
while i >= 0 do
	bmp_planes = bit32.bor(bmp_planes, bit32.lshift(string.byte(bitmap, i+27, i+27), 8*i))
	i=i-1
end
-- Apparently the planes thing is supposed to be 1 so quit if it isn't
if bmp_planes ~= 1 then
	print("Error: bV5Planes is not 1")
	return 1
end

-- Get bit depth
bmp_bpp = 0
i=1
while i >= 0 do
	bmp_bpp = bit32.bor(bmp_bpp, bit32.lshift(string.byte(bitmap, i+29, i+29), 8*i))
	i=i-1
end
-- Give up if bit depth isn't 16, i can't be bothered to deal with this
if bmp_bpp ~= 16 then
	print("Error: Bit depths other than 16 bpp are not supported")
	return 1
end


-- Get compression method
bmp_compression = 0
i=1
while i >= 0 do
	bmp_compression = bit32.bor(bmp_compression, bit32.lshift(string.byte(bitmap, i+33, i+33), 8*i))
	i=i-1
end
-- Can't be bothered to support anything other than BI_RGB
if bmp_compression ~= 0 then
	print("Error: Only BI_RGB bitmaps are supported.")
	return 1
end

--[ This section initializes the monitor and draws the image ]--
monitor = peripheral.find("monitor")
if monitor == nil then
	print("Error: No monitor detected.")
	return 1
end
monitor.clear()
monitor.setTextColor(1)
x = bmp_width
y = 1
monitor.setCursorPos(x,y)

-- Draw the image
i=filesize
while i > offset do
	-- Get a pixel
	pixel = bit32.bor(bit32.lshift(string.byte(string.sub(bitmap, i, i)), 8),
			  string.byte(string.sub(bitmap, i-1, i-1)))
	
	-- Get the color in RGB555 and convert it to RGB888 then to a ComputerCraft color
	r = bit32.band(bit32.rshift(pixel, 10), 31)
	g = bit32.band(bit32.rshift(pixel, 5), 31)
	b = bit32.band(pixel, 31)
	r, g, b = rgb555torgb888(r,g,b)
	color = colors.fromRGB2(r, g, b)

	monitor.setTextColor(color)
	monitor.write(string.char(143, 143))
	x=x-1
	if x == 0 then
		x = bmp_width
		y=y+1
	end
	if y % bmp_height*2 == 0 then
		break
	end
	monitor.setCursorPos(x,y)
	i=i-2
	if i % 200 == 0 then
		sleep(0)
	end
end

-- Cleanup
monitor.setCursorPos(1,1)
monitor.setTextColor(1)

