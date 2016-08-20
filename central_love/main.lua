local bit = require("bit")

local bnot = bit.bnot
local band, bor, bxor = bit.band, bit.bor, bit.bxor
local lshift, rshift, rol = bit.lshift, bit.rshift, bit.rol
local tohex = bit.tohex
local floor = math.floor

local adresse = "F5:48:6D:6F:3E:56" -- peripheral adresse

local roll, pitch, yaw, gaz = 0, 0, 0, 0
local aux1, aux2, aux3 = 0, 0, 0
local data = {}

local font = nil
local fontY = 0

function love.load(arg)

	update_timer = 0

	love.joystick.loadGamepadMappings("gamecontrollerdb.map")
	love.graphics.setNewFont(50)
	font = love.graphics.getFont()
	fontY = font:getHeight()

	gatt = io.popen("gatttool -t random -b "..adresse.." -I > /dev/null", "w") -- run gatttool
	gatt:write("connect\n"); -- connect to ble peripheral

end


function love.update(dt)

	update_timer = update_timer + dt

	if update_timer > 0.025 then -- ( 40Hz = 0.025)

		update_timer = 0

		if joy then
			gaz   = 511 * joy:getGamepadAxis( "lefty" ) + 512
			yaw   = 511 * joy:getGamepadAxis( "leftx" ) + 512
			roll  = 511 * joy:getGamepadAxis( "rightx" ) + 512
			pitch = 511 * joy:getGamepadAxis( "righty" ) + 512
		else
			gaz, yaw, roll, pitch = 42, 42, 42, 42
		end

		for i=1,6 do data[i-1] = 0 end            -- memset(data, 0, sizeof(data))

		data[0] = bor(data[0], rshift(gaz, 2))    -- data[0] |= gaz >> 2;
		data[1] = bor(data[1], lshift(gaz, 6))    -- data[1] |= gaz << 6;

		data[1] = bor(data[1], rshift(yaw, 4));   -- data[1] |= yaw >> 4;
		data[2] = bor(data[2], lshift(yaw, 4));   -- data[2] |= yaw << 4;

		data[2] = bor(data[2], rshift(roll, 6));  -- data[2] |= roll >> 6;
		data[3] = bor(data[3], lshift(roll, 2));  -- data[3] |= roll << 2;

		data[3] = bor(data[3], rshift(pitch, 8)); -- data[3] |= pitch >> 8;
		data[4] = bor(data[4], lshift(pitch, 0)); -- data[4] |= pitch << 0;

		data[5] = bor(data[5], lshift(aux1%4,4))  -- data[5] |= aux[0] << 4;
		data[5] = bor(data[5], lshift(aux2%4,2))  -- data[5] |= aux[1] << 2;
		data[5] = bor(data[5], lshift(aux3%4,0))  -- data[5] |= aux[2] << 0;

		-- write data to handle 0x29
		gatt:write(
			"char-write-cmd 29 "..
			tohex(data[0],2)..
			tohex(data[1],2)..
			tohex(data[2],2)..
			tohex(data[3],2)..
			tohex(data[4],2)..
			tohex(data[5],2)..
			"\n"
		)
		gatt:flush()
	end

end


function love.draw()
	love.graphics.print("gaz: "..floor(gaz),     10, fontY * 0)
	love.graphics.print("yaw: "..floor(yaw),     10, fontY * 1)
	love.graphics.print("roll: "..floor(roll) ,  10, fontY * 2)
	love.graphics.print("pitch: "..floor(pitch), 10, fontY * 3)

	love.graphics.print("aux1: "..floor(aux1), 10, fontY * 4)
	love.graphics.print("aux2: "..floor(aux2), 10, fontY * 5)
	love.graphics.print("aux3: "..floor(aux3), 10, fontY * 6)
end


function love.keypressed(key, scancode, isrepeat)
	print(key)
	if key == "escape" then love.event.quit() end
end


function love.gamepadpressed( joystick, button )
	print("button",button)
	if button == "a" then
		aux1 = (aux1 + 1) % 4
	end
	if button == "b" then
		aux2 = (aux2 + 1) % 4
	end
	if button == "x" then
		aux3 = (aux3 + 1) % 4
	end
end


function love.joystickadded(joystick)
	joy = joystick
end


function love.quit()
	--serial:close()
	print("quit")
	gatt:write("quit\n")
	gatt:flush()
	os.execute("killall gatttool")
end
