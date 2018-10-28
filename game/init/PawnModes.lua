--By SirDust
local Vector = require'lualib/Vector'
local Pawn = require'player/Pawn'


local WalkSpeed = .1
local ClimbSpeed = -.1
local JumpSpeed = -.5

local Acceleration = .1
local function Gravity(up)--Must return an iterator that always returns negative values
	local v = up or 0
	return function()
		v = v + Acceleration
		return v
	end
end


local function Climb_Seek_Up(self,dY)--also initiates climb
	local x = math.floor(self.Origin.X + self.Size.X/2)
	for y = math.floor(self.Origin.Y + dY),math.ceil(self.Origin.Y + self.Size.Y + dY) - 1 do
		if not self.CurLevel:getCell(x,y).IsClimable then return end
	end
	local dX = x + .5 - self.Size.X/2 - self.Origin.X
	if math.abs(dX) < self.WalkSpeed then
		self.newMode = 'Climbing'
		return dX
	else
		return dX > 0 and self.WalkSpeed or -self.WalkSpeed
	end
end
local function Climb_Seek_Down(self,dY)--also initiates climb
	local x = math.floor(self.Origin.X + self.Size.X/2)
	local y0 = math.ceil(self.Origin.Y + dY) - 1
	local cell = self.Pawn.Level:getCell(x,y0)
	if cell.IsClimable then
		local dX = x + .5 - self.Size.X/2 - self.Origin.X
		if math.abs(dX) < self.WalkSpeed then
			if self.curGround[cell] then
				self.newMode = 'Pulling'
			else
				for y = y0 + 1,math.ceil(self.Origin.Y + self.Size.Y + dY) - 1 do
					if not self.CurLevel:getCell(x,y).IsClimable then
						return dX
					end
				end
				self.newMode = 'Climbing'
				self.pullLevel = y0
			end
			return dX
		else
			return dX > 0 and self.WalkSpeed or -self.WalkSpeed
		end
	end
end


local Walking = Pawn.Mode.new'_walking'
local Falling = Pawn.Mode.new'_falling'
local Jumping = Pawn.Mode.new'_jumping'
local Climbing = Pawn.Mode.new'_climbing'
local Pulling = Pawn.Mode.new'_pulling'
local Dropping = Pawn.Mode.new'_dropping'

--[Walking]--
function Walking:EnterMode(ground)
	if self.Pawn.Origin.y%1 == 0 then
		self.y = self.Pawn.Origin.y - 1
		self.ground = {}
		self.entered = {}
		if type(ground) == 'table' then
			for k,v in ipairs(ground) do
				if type(v) == 'number' and v%1 == 0 then
					self.entered[v] = true
				end
			end
		end
	else
		self.Pawn:setMode(Falling)
	end
end
function Walking:ChangeLevel()
	local y = self.Origin.Y - 1
	if y%1 == 0 then
		self.curGround = {}
		for x = math.floor(self.Origin.X),math.ceil(self.Origin.X + self.Size.X) - 1 do
			local cell = self.Pawn.Level:getCell(x,y)
			if cell.IsGround then
				self.curGround[cell] = true
			end
		end
		if not next(self.curGround) then
			self.Pawn:setMode(Falling)
		end
	else
		self.Pawn:setMode(Falling)
	end
end
function Walking:Init()
	if self.Pawn:getControl'jump' then
		self.Pawn:setMode(Jumping)
	elseif self.Pawn:getControl'down' then
		for k,v in pairs(self.curGround) do
			if not k.IsThin then--<--
				return
			end
		end
		self.Pawn:setMode(Dropping)
	end
end
function Walking:Update()
	local dx = 0
	if self.Pawn:getControl'up' then
		dx = Climb_Seek_Up(self,0)
	elseif self.Pawn:getControl'down' then
		dx = Climb_Seek_Down(self,0)
	elseif self.Pawn:getControl'right' then--<--
		dx = WalkSpeed
	elseif self.Pawn:getControl'left' then
		dx = -WalkSpeed
	end
	self.Pawn.Velocity = Vector.new(dx,0)
end
function Walking:EnterCell(coord)
	self.entered[coord.X] = true
	return self.Pawn.Level:getCell(coord).IsSolid
end
function Walking:ExitCell(coord)
	self.ground[coord.X] = nil
	self.entered[coord.X] = nil
end
function Walking:Fin()
	for x,_ in pairs(self.entered) do
		if self.Pawn.Level:getCell(x,self.y).IsGround then
			self.ground[x] = true
		end
		self.entered[x] = nil
	end
	if not next(self.ground) then
		self.Pawn:setMode(Falling)
	end
end

--[Falling]--
function Falling:EnterMode(n)
	self.gravity = Gravity(type(n) == 'number' and n < 0 and n or 0)
end
function Falling:Update()
	local dy,dx = self.gravity()--<--Make sure never positive
	if self.Pawn:getControl'up' then
		dx = Climb_Seek_Up(dy)
	elseif self.Pawn:getControl'down' then
		dx = Climb_Seek_Down(dy)
	elseif self.Pawn:getControl'right' then
		dx = WalkSpeed
	elseif self.Pawn:getControl'left' then
		dx = -WalkSpeed
	end
	self.Pawn.Velocity = Vector.new(dx,dy)
end
function Falling:Enter(coord,side)
	local cell = self.CurLevel:getCell(coord)
	if side == 'T' then
		if cell.IsGround then
			if self.ground then
				self.ground[#self.ground + 1] = cell
			else
				self.ground = {cell}
			end
			return true
		end
	else
		return cell.IsSolid
	end
end
function Falling:Fin()
	if self.ground then
		self.Pawn:setMode(Walking,self.ground)
		self.ground = nil
	end
end

--[Jumping]--
function Jumping:EnterMode()--<--
	self.gravity = Gravity(JumpSpeed)
end
Jumping.Update = Falling.Update
Jumping.Enter = Falling.Enter
Jumping.Fin = Falling.Fin

--[Climbing]--
function Climbing:Init()
	if self.Pawn:getControl'jump' then
		self.Pawn:setMode(Jumping)
	elseif not self.Pawn:getControl'up' and not self.Pawn:getControl'down' and (self.Pawn:getControl'left' or self.Pawn:getControl'right') then
		self.Pawn:setMode(Falling)
	end
end
function Climbing:Update()
	local dy
	if self.Pawn:getControl'up' then
		dy = ClimbSpeed
	elseif self.Pawn:getControl'down' then
		dy = -ClimbSpeed
	end
	self.Pawn.Velocity = Vector.new(0,dy or 0)
end
function Climbing:EnterCell(coord,side)
	local cell = self.CurLevel:getCell(coord)
	if side == 'T' then
		if cell.IsGround then
			if self.ground then
				self.ground[#self.ground + 1] = cell
			else
				self.ground = {cell}
			end
			return true
		else
			return not cell.IsClimbable
		end
	elseif not cell.IsSolid and self.Pawn.Level:getCell(coord.X,coord.Y - 1).IsGround then
		self.pull = coord.Y - 1
		self.Pawn:setMode(Pulling,coord.Y - 1)
	else
		return not cell.IsClimbable
	end
end
function Climbing:ExitCell(coord)
	if self.pull and coord.Y == self.pull then
		self.pull = nil
		return true
	end
end
Climbing.Fin = Falling.Fin

--[Pulling]--
function Pulling:EnterMode(y)
	if type(y) == 'number' and y%1 == 0 then
		self.y = y
	else--Should never trigger, merely a failsafe
		self.Pawn:setMode(Falling)
	end
end
Pulling.Init = Climbing.Init
function Pulling:Update()
	local dy
	if self.Pawn:getControl'up' then
		dy = math.min(ClimbSpeed,self.y - self.Pawn.Origin.Y)
	elseif self.Pawn:getControl'down' then
		dy = -ClimbSpeed
	end
	self.Pawn.Velocity = Vector.new(0,dy or 0)
end
function Pulling:EnterCell(coord,side)
	local cell = self.CurLevel:getCell(coord)
	if side == 'T' then
		if cell.IsGround then
			if self.ground then
				self.ground[#self.ground + 1] = cell
			else
				self.ground = {cell}
			end
			return true
		else
			return not cell.IsClimbable
		end
	else
		return cell.IsSolid
	end
end
function Pulling:ExitCell(coord,side)
	if side == 'T' then
		if self.y == coord.Y then
			local cell = self.CurLevel:getCell(coord.X,self.y)
			if cell.IsGround then
				if self.ground then
					self.ground[#self.ground + 1] = cell
				else
					self.ground = {cell}
				end
			end
		end
	elseif self.y == coord.Y - 1 and not self.ground then
		self.Pawn:setMode(Climbing)
	end
end
Pulling.Fin = Falling.Fin

--[Dropping]--
function Dropping:EnterMode()
	self.hasDropped = false
end
function Dropping:Update()
	local g = Gravity()()
	self.Pawn:setMode(Falling,g)
	self.Pawn.Velocity = Vector.new(0,g)
end
function Dropping:EnterCell()--Prevent pawn from dropping through more than one cell
	if self.hasDropped then
		return true
	else
		self.hasDropped = true
	end
end
