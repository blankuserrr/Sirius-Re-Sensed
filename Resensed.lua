--!strict
-- services
local runService: RunService = game:GetService("RunService");
local players: Players = game:GetService("Players");
local workspace: Workspace = game:GetService("Workspace");

-- variables
local localPlayer: Player = players.LocalPlayer;
local camera: Camera = workspace.CurrentCamera;
local viewportSize: Vector2 = camera.ViewportSize;
local container: Folder = Instance.new("Folder",
	gethui and gethui() or game:GetService("CoreGui"));

-- locals
local floor = math.floor;
local round = math.round;
local sin = math.sin;
local cos = math.cos;
local clear = table.clear;
local unpack = table.unpack;
local find = table.find;
local create = table.create;
local fromMatrix = CFrame.fromMatrix;

-- methods
local wtvp = camera.WorldToViewportPoint;
local isA = workspace.IsA;
local getPivot = workspace.GetPivot;
local findFirstChild = workspace.FindFirstChild;
local findFirstChildOfClass = workspace.FindFirstChildOfClass;
local getChildren = workspace.GetChildren;
local toOrientation = CFrame.identity.ToOrientation;
local pointToObjectSpace = CFrame.identity.PointToObjectSpace;
local lerpColor = Color3.new().Lerp;
local min2 = Vector2.zero.Min;
local max2 = Vector2.zero.Max;
local lerp2 = Vector2.zero.Lerp;
local min3 = Vector3.zero.Min;
local max3 = Vector3.zero.Max;

-- constants
local HEALTH_BAR_OFFSET = Vector2.new(5, 0);
local HEALTH_TEXT_OFFSET = Vector2.new(3, 0);
local HEALTH_BAR_OUTLINE_OFFSET = Vector2.new(0, 1);
local NAME_OFFSET = Vector2.new(0, 2);
local DISTANCE_OFFSET = Vector2.new(0, 2);

-- constants
local SKELETON_CONNECTIONS_R15 = {
	{"Head", "UpperTorso"},
	{"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"},
	{"UpperTorso", "RightUpperArm"},
	{"LeftUpperArm", "LeftLowerArm"},
	{"RightUpperArm", "RightLowerArm"},
	{"LeftLowerArm", "LeftHand"},
	{"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"},
	{"LowerTorso", "RightUpperLeg"},
	{"LeftUpperLeg", "LeftLowerLeg"},
	{"RightUpperLeg", "RightLowerLeg"},
	{"LeftLowerLeg", "LeftFoot"},
	{"RightLowerLeg", "RightFoot"}
};

local SKELETON_CONNECTIONS_R6 = {
	{"Head", "Torso"},
	{"Torso", "Left Arm"},
	{"Torso", "Right Arm"},
	{"Torso", "Left Leg"},
	{"Torso", "Right Leg"}
};

local VERTICES = {
	Vector3.new(-1, -1, -1),
	Vector3.new(-1, 1, -1),
	Vector3.new(-1, 1, 1),
	Vector3.new(-1, -1, 1),
	Vector3.new(1, -1, -1),
	Vector3.new(1, 1, -1),
	Vector3.new(1, 1, 1),
	Vector3.new(1, -1, 1)
};

-- functions
local function worldToScreen(world: Vector3): (Vector2, boolean, number)
	local screen, inBounds = wtvp(camera, world);
	return Vector2.new(screen.X, screen.Y), inBounds, screen.Z;
end

local function calculateCorners(cframe: CFrame, size: Vector3): ({corners: {Vector2}, topLeft: Vector2, topRight: Vector2, bottomLeft: Vector2, bottomRight: Vector2})
	local corners = create(8);

	for i = 1, #VERTICES do
		corners[i] = worldToScreen((cframe * CFrame.new(VERTICES[i] * size * 0.5)).Position);
	end

	local min = min2(viewportSize, unpack(corners));
	local max = max2(Vector2.zero, unpack(corners));
	return {
		corners = corners,
		topLeft = Vector2.new(floor(min.X), floor(min.Y)),
		topRight = Vector2.new(floor(max.X), floor(min.Y)),
		bottomLeft = Vector2.new(floor(min.X), floor(max.Y)),
		bottomRight = Vector2.new(floor(max.X), floor(max.Y))
	};
end

local function rotateVector(vector: Vector2, radians: number): Vector2
	-- https://stackoverflow.com/questions/28112315/how-do-i-rotate-a-vector
	local x, y = vector.X, vector.Y;
	local c, s = cos(radians), sin(radians);
	return Vector2.new(x*c - y*s, x*s + y*c);
end

local function parseColor(self: any, color: any, isOutline: boolean?): Color3
	if color == "Team Color" or (self.interface.sharedSettings.useTeamColor and not isOutline) then
		return self.interface.getTeamColor(self.player) or Color3.new(1,1,1);
	end
	return color;
end

-- esp object
local EspObject = {};
EspObject.__index = EspObject;
export type EspObject = typeof(setmetatable({} :: any, EspObject))

function EspObject.new(player: Player, interface: any): EspObject
	local self = setmetatable({}, EspObject);
	self.player = assert(player, "Missing argument #1 (Player expected)");
	self.interface = assert(interface, "Missing argument #2 (table expected)");
	self:Construct();
	return self;
end

function EspObject:_create(class: string, properties: {[string]: any}): Drawing
	local drawing = Drawing.new(class);
	for property, value in next, properties do
		pcall(function() drawing[property] = value; end);
	end
	table.insert(self.bin, drawing)
	return drawing;
end

function EspObject:Construct()
	self.charCache = {};
	self.childCount = 0;
	self.bin = {};
	self.skeletonConnections = SKELETON_CONNECTIONS_R15;

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Name = "InfoGui"
	billboardGui.Adornee = nil
	billboardGui.AlwaysOnTop = true
	billboardGui.Size = UDim2.new(0, 200, 0, 100)
	billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
	billboardGui.Parent = container
	self.bin[#self.bin + 1] = billboardGui

	local function createTextLabel(name, yAnchor)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Text = ""
		label.Font = Enum.Font.SourceSans
		label.TextSize = 16
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Visible = false
		label.Size = UDim2.new(1, 0, 0, 20)
		label.Position = UDim2.new(0.5, 0, yAnchor, 0)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Parent = billboardGui

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Color = Color3.new(0,0,0)
		stroke.Parent = label

		return label, stroke
	end

	self.drawings = {
		box3d = (function()
			local box = Instance.new("BoxHandleAdornment")
			box.Name = "Box3D"
			box.Parent = container
			box.Visible = false
			self.bin[#self.bin + 1] = box
			return box
		end)(),
		visible = {
			tracerOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			tracer = self:_create("Line", { Thickness = 1, Visible = false }),
			boxFill = self:_create("Square", { Filled = true, Visible = false }),
			boxOutline = self:_create("Square", { Thickness = 3, Visible = false }),
			box = self:_create("Square", { Thickness = 1, Visible = false }),
			healthBarOutline = self:_create("Line", { Thickness = 3, Visible = false }),
			healthBar = self:_create("Line", { Thickness = 1, Visible = false }),
			billboard = billboardGui,
			skeleton = {}
		},
		hidden = {
			arrowOutline = self:_create("Triangle", { Thickness = 3, Visible = false }),
			arrow = self:_create("Triangle", { Filled = true, Visible = false })
		}
	};

	self.drawings.visible.name, self.drawings.visible.nameStroke = createTextLabel("Name", 0.1)
	self.drawings.visible.distance, self.drawings.visible.distanceStroke = createTextLabel("Distance", 0.9)
	self.drawings.visible.weapon, self.drawings.visible.weaponStroke = createTextLabel("Weapon", 0.7)
	self.drawings.visible.healthText, self.drawings.visible.healthTextStroke = createTextLabel("Health", 0.3)

	-- Preallocate enough lines for the largest skeleton (R15)
	for i = 1, #SKELETON_CONNECTIONS_R15 do
		self.drawings.visible.skeleton[i] = self:_create("Line", { Thickness = 1, Visible = false })
	end

	self.renderConnection = runService.RenderStepped:Connect(function(deltaTime: number)
		self:Update(deltaTime);
		self:Render(deltaTime);
	end);
end

function EspObject:Destruct()
	self.renderConnection:Disconnect();

	for i = 1, #self.bin do
		local object = self.bin[i]
		if typeof(object) == "Instance" then
			object:Destroy()
		else
			object:Remove()
		end
	end

	clear(self);
end

function EspObject:Update(deltaTime: number)
	local interface = self.interface;

	self.options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"];
	self.character = interface.getCharacter(self.player);
	self.health, self.maxHealth = interface.getHealth(self.player);
	self.weapon = interface.getWeapon(self.player);
	self.enabled = self.options.enabled and self.character and not
		(#interface.whitelist > 0 and not find(interface.whitelist, self.player.UserId));
	self.isVisible = false

	local head = self.enabled and findFirstChild(self.character, "Head");
	if not head then
		self.onScreen = false;
		clear(self.charCache)
		return;
	end

	-- Detect rig type and choose skeleton connections
	if self.character:FindFirstChild("UpperTorso") then
		self.skeletonConnections = SKELETON_CONNECTIONS_R15;
	else
		self.skeletonConnections = SKELETON_CONNECTIONS_R6;
	end

	local _, onScreen, depth = worldToScreen(head.Position);
	self.onScreen = onScreen;
	self.distance = depth;

	if interface.sharedSettings.limitDistance and depth > interface.sharedSettings.maxDistance then
		self.onScreen = false;
	end

	-- Cache only the parts needed for the current skeleton connections
	if self.character and (not next(self.charCache) or self.childCount ~= #self.character:GetChildren()) then
		clear(self.charCache)
		for _, connection in ipairs(self.skeletonConnections) do
			for _, partName in ipairs(connection) do
				if not self.charCache[partName] then
					local part = self.character:FindFirstChild(partName)
					if part and part:IsA("BasePart") then
						self.charCache[partName] = part
					end
				end
			end
		end
		self.childCount = #self.character:GetChildren()
	end

	if self.onScreen then
		local cframe, size = self.character:GetBoundingBox();
		self.boundingBoxCFrame = cframe;
		self.boundingBoxSize = size;
		self.corners = calculateCorners(cframe, size);
	elseif self.options.offScreenArrow then
		local cframe = camera.CFrame;
		local flat = fromMatrix(cframe.Position, cframe.RightVector, Vector3.yAxis);
		local objectSpace = pointToObjectSpace(flat, head.Position);
		self.direction = Vector2.new(objectSpace.X, objectSpace.Z).Unit;
	end

	if self.character then
		local origin = camera.CFrame.Position
		local targetPart = self.character:FindFirstChild("Head") or self.character:FindFirstChild("HumanoidRootPart")
		if targetPart then
			local direction = (targetPart.Position - origin)

			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { localPlayer.Character }

			local result = workspace:Raycast(origin, direction, params)

			self.isVisible = (not result) or (result.Instance:IsDescendantOf(self.character))
		end
	end
end

function EspObject:Render(deltaTime: number)
	local onScreen = self.onScreen or false;
	local enabled = self.enabled or false;
	local visible = self.drawings.visible;
	local hidden = self.drawings.hidden;
	local box3dAdornment = self.drawings.box3d;
	local interface = self.interface;
	local options = self.options;
	local corners = self.corners;

	visible.box.Visible = enabled and onScreen and options.box;
	visible.boxOutline.Visible = visible.box.Visible and options.boxOutline;
	if visible.box.Visible then
		local box = visible.box;
		box.Position = corners.topLeft;
		box.Size = corners.bottomRight - corners.topLeft;

		local boxColor = (self.isVisible and options.visibleBoxColor) or options.boxColor
		box.Color = parseColor(self, boxColor[1]);
		box.Transparency = boxColor[2];

		local boxOutline = visible.boxOutline;
		boxOutline.Position = box.Position;
		boxOutline.Size = box.Size;

		local boxOutlineColor = (self.isVisible and options.visibleBoxOutlineColor) or options.boxOutlineColor
		boxOutline.Color = parseColor(self, boxOutlineColor[1], true);
		boxOutline.Transparency = boxOutlineColor[2];
	end

	visible.boxFill.Visible = enabled and onScreen and options.boxFill;
	if visible.boxFill.Visible then
		local boxFill = visible.boxFill;
		boxFill.Position = corners.topLeft;
		boxFill.Size = corners.bottomRight - corners.topLeft;

		local boxFillColor = (self.isVisible and options.visibleBoxFillColor) or options.boxFillColor
		boxFill.Color = parseColor(self, boxFillColor[1]);
		boxFill.Transparency = boxFillColor[2];
	end

	visible.healthBar.Visible = enabled and onScreen and options.healthBar;
	visible.healthBarOutline.Visible = visible.healthBar.Visible and options.healthBarOutline;
	if visible.healthBar.Visible then
		local barFrom = corners.topLeft - HEALTH_BAR_OFFSET;
		local barTo = corners.bottomLeft - HEALTH_BAR_OFFSET;

		local healthBar = visible.healthBar;
		healthBar.To = barTo;
		healthBar.From = lerp2(barTo, barFrom, self.health/self.maxHealth);
		healthBar.Color = lerpColor(options.dyingColor, options.healthyColor, self.health/self.maxHealth);

		local healthBarOutline = visible.healthBarOutline;
		healthBarOutline.To = barTo + HEALTH_BAR_OUTLINE_OFFSET;
		healthBarOutline.From = barFrom - HEALTH_BAR_OUTLINE_OFFSET;
		healthBarOutline.Color = parseColor(self, options.healthBarOutlineColor[1], true);
		healthBarOutline.Transparency = options.healthBarOutlineColor[2];
	end

	local head = self.character and self.character:FindFirstChild("Head")
	local billboard = visible.billboard
	billboard.Enabled = enabled and onScreen and head and (options.healthText or options.name or options.distance or options.weapon)

	if billboard.Enabled then
		billboard.Adornee = head
		
		local healthText = visible.healthText
		healthText.Visible = options.healthText;
		if healthText.Visible then
			healthText.Text = round(self.health) .. "hp";
			healthText.TextColor3 = parseColor(self, options.healthTextColor[1]);
			healthText.TextTransparency = options.healthTextColor[2];
			visible.healthTextStroke.Enabled = options.healthTextOutline;
			visible.healthTextStroke.Color = parseColor(self, options.healthTextOutlineColor, true);
		end

		local name = visible.name
		name.Visible = options.name;
		if name.Visible then
			name.Text = self.player.DisplayName;
			name.TextColor3 = parseColor(self, options.nameColor[1]);
			name.TextTransparency = options.nameColor[2];
			visible.nameStroke.Enabled = options.nameOutline;
			visible.nameStroke.Color = parseColor(self, options.nameOutlineColor, true);
		end

		local distance = visible.distance
		distance.Visible = options.distance;
		if distance.Visible then
			distance.Text = round(self.distance) .. " studs";
			distance.TextColor3 = parseColor(self, options.distanceColor[1]);
			distance.TextTransparency = options.distanceColor[2];
			visible.distanceStroke.Enabled = options.distanceOutline;
			visible.distanceStroke.Color = parseColor(self, options.distanceOutlineColor, true);
		end

		local weapon = visible.weapon
		weapon.Visible = options.weapon;
		if weapon.Visible then
			weapon.Text = self.weapon;
			weapon.TextColor3 = parseColor(self, options.weaponColor[1]);
			weapon.TextTransparency = options.weaponColor[2];
			visible.weaponStroke.Enabled = options.weaponOutline;
			visible.weaponStroke.Color = parseColor(self, options.weaponOutlineColor, true);
		end
	end

	local skeletonEnabled = enabled and onScreen and options.skeleton
	for i, line in ipairs(self.drawings.visible.skeleton) do
		local connection = self.skeletonConnections[i]
		line.Visible = skeletonEnabled and connection ~= nil
		if skeletonEnabled and connection then
			local p1 = self.charCache[connection[1]]
			local p2 = self.charCache[connection[2]]

			if p1 and p2 then
				local pos1, vis1 = worldToScreen(p1.Position)
				local pos2, vis2 = worldToScreen(p2.Position)

				if vis1 or vis2 then
					line.From = pos1
					line.To = pos2
					local color = (self.isVisible and options.visibleSkeletonColor) or options.skeletonColor
					line.Color = parseColor(self, color[1])
					line.Transparency = color[2]
				else
					line.Visible = false
				end
			else
				line.Visible = false
			end
		end
	end

	visible.tracer.Visible = enabled and onScreen and options.tracer;
	visible.tracerOutline.Visible = visible.tracer.Visible and options.tracerOutline;
	if visible.tracer.Visible then
		local tracer = visible.tracer;
		local tracerColor = (self.isVisible and options.visibleTracerColor) or options.tracerColor
		tracer.Color = parseColor(self, tracerColor[1]);
		tracer.Transparency = tracerColor[2];
		tracer.To = (corners.bottomLeft + corners.bottomRight)*0.5;
		tracer.From =
			options.tracerOrigin == "Middle" and viewportSize*0.5 or
			options.tracerOrigin == "Top" and viewportSize*Vector2.new(0.5, 0) or
			options.tracerOrigin == "Bottom" and viewportSize*Vector2.new(0.5, 1);

		local tracerOutline = visible.tracerOutline;
		tracerOutline.Color = parseColor(self, options.tracerOutlineColor[1], true);
		tracerOutline.Transparency = options.tracerOutlineColor[2];
		tracerOutline.To = tracer.To;
		tracerOutline.From = tracer.From;
	end

	hidden.arrow.Visible = enabled and (not onScreen) and options.offScreenArrow;
	hidden.arrowOutline.Visible = hidden.arrow.Visible and options.offScreenArrowOutline;
	if hidden.arrow.Visible and self.direction then
		local arrow = hidden.arrow;
		arrow.PointA = min2(max2(viewportSize*0.5 + self.direction*options.offScreenArrowRadius, Vector2.one*25), viewportSize - Vector2.one*25);
		arrow.PointB = arrow.PointA - rotateVector(self.direction, 0.45)*options.offScreenArrowSize;
		arrow.PointC = arrow.PointA - rotateVector(self.direction, -0.45)*options.offScreenArrowSize;
		arrow.Color = parseColor(self, options.offScreenArrowColor[1]);
		arrow.Transparency = options.offScreenArrowColor[2];

		local arrowOutline = hidden.arrowOutline;
		arrowOutline.PointA = arrow.PointA;
		arrowOutline.PointB = arrow.PointB;
		arrowOutline.PointC = arrow.PointC;
		arrowOutline.Color = parseColor(self, options.offScreenArrowOutlineColor[1], true);
		arrowOutline.Transparency = options.offScreenArrowOutlineColor[2];
	end

	local box3dEnabled = enabled and onScreen and options.box3d
	box3dAdornment.Visible = box3dEnabled

	if box3dEnabled and self.character and self.character.PrimaryPart then
		box3dAdornment.Adornee = self.character.PrimaryPart
		box3dAdornment.CFrame = self.character.PrimaryPart.CFrame:ToObjectSpace(self.boundingBoxCFrame)
		box3dAdornment.Size = self.boundingBoxSize
		local box3dColor = (self.isVisible and options.visibleBox3dColor) or options.box3dColor
		box3dAdornment.Color3 = parseColor(self, box3dColor[1])
		box3dAdornment.Transparency = box3dColor[2]
	else
		box3dAdornment.Adornee = nil
	end
end

-- cham object
local ChamObject = {};
ChamObject.__index = ChamObject;
export type ChamObject = typeof(setmetatable({} :: any, ChamObject))

function ChamObject.new(player: Player, interface: any, espObject: EspObject): ChamObject
	local self = setmetatable({}, ChamObject);
	self.player = assert(player, "Missing argument #1 (Player expected)");
	self.interface = assert(interface, "Missing argument #2 (table expected)");
	self.espObject = espObject
	self:Construct();
	return self;
end

function ChamObject:Construct()
	self.highlight = Instance.new("Highlight", container);
	self.updateConnection = runService.RenderStepped:Connect(function()
		self:Update();
	end);
end

function ChamObject:Destruct()
	self.updateConnection:Disconnect();
	self.highlight:Destroy();

	clear(self);
end

function ChamObject:Update()
	local highlight: Highlight = self.highlight;
	local interface = self.interface;
	local character = interface.getCharacter(self.player);
	local options = interface.teamSettings[interface.isFriendly(self.player) and "friendly" or "enemy"];
	local enabled = options.enabled and character and not
		(#interface.whitelist > 0 and not find(interface.whitelist, self.player.UserId));

	highlight.Enabled = enabled and options.chams;
	if highlight.Enabled then
		local isVisible = self.espObject.isVisible

		highlight.Adornee = character;
		local fill = (isVisible and options.visibleChamsFillColor) or options.chamsFillColor
		highlight.FillColor = parseColor(self, fill[1]);
		highlight.FillTransparency = fill[2];

		local outline = (isVisible and options.visibleChamsOutlineColor) or options.chamsOutlineColor
		highlight.OutlineColor = parseColor(self, outline[1], true);
		highlight.OutlineTransparency = outline[2];
		highlight.DepthMode = options.chamsVisibleOnly and "Occluded" or "AlwaysOnTop";
	end
end

-- interface
local EspInterface = {
	_hasLoaded = false,
	_objectCache = {},
	whitelist = {},
	sharedSettings = {
		textSize = 13,
		textFont = 2,
		limitDistance = false,
		maxDistance = 150,
		useTeamColor = false
	},
	teamSettings = {
		enemy = {
			enabled = false,
			box = false,
			boxColor = { Color3.new(1,0,0), 1 },
			visibleBoxColor = { Color3.new(1,1,0), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			visibleBoxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(1,0,0), 0.5 },
			visibleBoxFillColor = { Color3.new(1,1,0), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1,1,1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(1,0,0), 1 },
			visibleBox3dColor = { Color3.new(1,1,0), 1 },
			name = false,
			nameColor = { Color3.new(1,1,1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1,1,1), 1 },
			weaponOutline = true,
			weaponOutlineColor = Color3.new(),
			distance = false,
			distanceColor = { Color3.new(1,1,1), 1 },
			distanceOutline = true,
			distanceOutlineColor = Color3.new(),
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(1,0,0), 1 },
			visibleTracerColor = { Color3.new(1,1,0), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1,1,1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			visibleChamsFillColor = { Color3.new(1,1,0), 0.5 },
			chamsOutlineColor = { Color3.new(1,0,0), 0 },
			visibleChamsOutlineColor = { Color3.new(1,1,0), 0 },
			skeleton = false,
			skeletonColor = { Color3.new(1,1,1), 1 },
			visibleSkeletonColor = { Color3.new(1,1,0), 1 },
		},
		friendly = {
			enabled = false,
			box = false,
			boxColor = { Color3.new(0,1,0), 1 },
			visibleBoxColor = { Color3.new(0,1,1), 1 },
			boxOutline = true,
			boxOutlineColor = { Color3.new(), 1 },
			visibleBoxOutlineColor = { Color3.new(), 1 },
			boxFill = false,
			boxFillColor = { Color3.new(0,1,0), 0.5 },
			visibleBoxFillColor = { Color3.new(0,1,1), 0.5 },
			healthBar = false,
			healthyColor = Color3.new(0,1,0),
			dyingColor = Color3.new(1,0,0),
			healthBarOutline = true,
			healthBarOutlineColor = { Color3.new(), 0.5 },
			healthText = false,
			healthTextColor = { Color3.new(1,1,1), 1 },
			healthTextOutline = true,
			healthTextOutlineColor = Color3.new(),
			box3d = false,
			box3dColor = { Color3.new(0,1,0), 1 },
			visibleBox3dColor = { Color3.new(0,1,1), 1 },
			name = false,
			nameColor = { Color3.new(1,1,1), 1 },
			nameOutline = true,
			nameOutlineColor = Color3.new(),
			weapon = false,
			weaponColor = { Color3.new(1,1,1), 1 },
			weaponOutline = true,
			weaponOutlineColor = Color3.new(),
			distance = false,
			distanceColor = { Color3.new(1,1,1), 1 },
			distanceOutline = true,
			distanceOutlineColor = Color3.new(),
			tracer = false,
			tracerOrigin = "Bottom",
			tracerColor = { Color3.new(0,1,0), 1 },
			visibleTracerColor = { Color3.new(0,1,1), 1 },
			tracerOutline = true,
			tracerOutlineColor = { Color3.new(), 1 },
			offScreenArrow = false,
			offScreenArrowColor = { Color3.new(1,1,1), 1 },
			offScreenArrowSize = 15,
			offScreenArrowRadius = 150,
			offScreenArrowOutline = true,
			offScreenArrowOutlineColor = { Color3.new(), 1 },
			chams = false,
			chamsVisibleOnly = false,
			chamsFillColor = { Color3.new(0.2, 0.2, 0.2), 0.5 },
			visibleChamsFillColor = { Color3.new(0,1,1), 0.5 },
			chamsOutlineColor = { Color3.new(0,1,0), 0 },
			visibleChamsOutlineColor = { Color3.new(0,1,1), 0 },
			skeleton = false,
			skeletonColor = { Color3.new(1,1,1), 1 },
			visibleSkeletonColor = { Color3.new(0,1,1), 1 },
		}
	}
};

function EspInterface.RegisterCallbacks(callbacks: {[string]: any})
	for name, func in pairs(callbacks) do
		if EspInterface[name] and type(func) == "function" then
			EspInterface[name] = func
		end
	end
end

function EspInterface.Load()
	assert(not EspInterface._hasLoaded, "Esp has already been loaded.");

	local function createObject(player: Player)
		local espObj = EspObject.new(player, EspInterface)
		EspInterface._objectCache[player] = {
			espObj,
			ChamObject.new(player, EspInterface, espObj)
		};
	end

	local function removeObject(player: Player)
		local object = EspInterface._objectCache[player];
		if object then
			for i = 1, #object do
				object[i]:Destruct();
			end
			EspInterface._objectCache[player] = nil;
		end
	end

	local plrs = players:GetPlayers();
	for i = 2, #plrs do
		createObject(plrs[i]);
	end

	EspInterface.playerAdded = players.PlayerAdded:Connect(createObject);
	EspInterface.playerRemoving = players.PlayerRemoving:Connect(removeObject);
	EspInterface._hasLoaded = true;
end

function EspInterface.Unload()
	assert(EspInterface._hasLoaded, "Esp has not been loaded yet.");

	for index, object in next, EspInterface._objectCache do
		for i = 1, #object do
			object[i]:Destruct();
		end
		EspInterface._objectCache[index] = nil;
	end

	EspInterface.playerAdded:Disconnect();
	EspInterface.playerRemoving:Disconnect();
	EspInterface._hasLoaded = false;
end

-- game specific functions
function EspInterface.getWeapon(player: Player): string
	return "Unknown";
end

function EspInterface.isFriendly(player: Player): boolean
	return player.Team and player.Team == localPlayer.Team;
end

function EspInterface.getTeamColor(player: Player): Color3?
	return player.Team and player.Team.TeamColor and player.Team.TeamColor.Color;
end

function EspInterface.getCharacter(player: Player): Model?
	return player.Character;
end

function EspInterface.getHealth(player: Player): (number, number)
	local character = player and EspInterface.getCharacter(player);
	local humanoid = character and findFirstChildOfClass(character, "Humanoid");
	if humanoid then
		return humanoid.Health, humanoid.MaxHealth;
	end
	return 100, 100;
end

return EspInterface;
