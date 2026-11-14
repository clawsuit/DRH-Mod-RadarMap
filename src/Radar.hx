package mods.radarmap;

import distributedObjects.DistributedDungeonFloor;
import mods.api.Context;
import mods.api.dungeon.Floor;
import mods.api.dungeon.Hero;
import mods.api.dungeon.Tile;
import openfl.display.Graphics;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Vector3D;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.Lib;

/**
 * The radar itself: a disc in the corner of the screen with the floor under the hero.
 *
 * The camera does not turn, so the map does not either: north is always up and the hero's arrow
 * points the way he faces. The rooms come from the tiles the server laid out, read as the api gives
 * them, cut to the disc.
 */
class Radar extends Sprite {
	/** The side of a tile, in world units. */
	static inline final TILE_SIZE = 900.0;

	/** How thick a wall is, in world units. */
	static inline final WALL = 130.0;

	/** How wide a passage is, in world units. */
	static inline final CORRIDOR = 300.0;

	/** How far a corridor reaches into the rooms it joins, in world units. */
	static inline final CORRIDOR_OVERLAP = 45.0;

	/** The zoom steps, over the scale that fits the whole floor. */
	static inline final ZOOM_STEPS = [1.0, 1.5, 2.2, 3.2, 4.6, 6.6];

	/** How often the enemy dots are redrawn, in frames. Reading them walks the whole floor. */
	static inline final MONSTER_EVERY = 6;

	/** How often the state of the gates is read again, in frames: a gate opens while it is played. */
	static inline final GATE_EVERY = 30;

	/** How far the hero may walk, in pixels, before the disc is cut again. */
	static inline final RECUT_PIXELS = 3.0;

	/** The margin between the disc and the edge of the view, in pixels. */
	static inline final MARGIN = 28.0;

	/** How far the disc hangs from the top of the view, in pixels. It clears the hud of the game. */
	static inline final TOP = 170.0;

	// Gate colors, as the minimap shows them
	static inline final GATE_OPEN = 0x3FB950;
	static inline final GATE_PLATE = 0xF0A030;
	static inline final GATE_KILLS = 0x9B59D0;
	static inline final GATE_BREAK = 0x2EC4D6;
	static inline final GATE_CLOSED = 0xD93636;
	static inline final GATE_UNKNOWN = 0x8A8F98;

	// The six treasures of the game, each with its own look
	static inline final CHEST_WOOD = 0;
	static inline final CHEST_SILVER = 1;
	static inline final CHEST_GOLD = 2;
	static inline final CHEST_DRAGON = 3;
	static inline final CHEST_SMALL = 4;
	static inline final CHEST_ROYAL = 5;

	static inline final CHEST_WOOD_BODY = 0x7A4B24;
	static inline final CHEST_WOOD_LID = 0x9A6633;
	static inline final CHEST_WOOD_TRIM = 0xC08A3E;

	static inline final CHEST_SILVER_BODY = 0x8E97A3;
	static inline final CHEST_SILVER_LID = 0xB6C0CC;
	static inline final CHEST_SILVER_TRIM = 0xEDF3FA;

	static inline final CHEST_GOLD_BODY = 0xC79A20;
	static inline final CHEST_GOLD_LID = 0xEFC64B;
	static inline final CHEST_GOLD_TRIM = 0xFFF3B0;

	static inline final CHEST_DRAGON_BODY = 0x7A1F1F;
	static inline final CHEST_DRAGON_LID = 0xB03830;
	static inline final CHEST_DRAGON_TRIM = 0xFF9A3C;

	static inline final CHEST_SMALL_BODY = 0x2F6E8F;
	static inline final CHEST_SMALL_LID = 0x5FC6EA;
	static inline final CHEST_SMALL_TRIM = 0xFFFFFF;

	static inline final CHEST_ROYAL_BODY = 0x5B3A8C;
	static inline final CHEST_ROYAL_LID = 0x9B6BD0;
	static inline final CHEST_ROYAL_TRIM = 0xFFD24D;

	// Floor colors, one per theme, and a shade for each place of it
	static inline final FLOOR_CASTLE = 0x6B4F35;
	static inline final FLOOR_CASTLE_ARENA = 0x7C5138;
	static inline final FLOOR_CASTLE_CRYPT = 0x55452F;
	static inline final FLOOR_JUNGLE = 0x3E6B3A;
	static inline final FLOOR_JUNGLE_AZTEC = 0x55703A;
	static inline final FLOOR_JUNGLE_TRIBAL = 0x33603F;
	static inline final FLOOR_NORDIC = 0x3A5570;
	static inline final FLOOR_NORDIC_TEMPLE = 0x415F84;
	static inline final FLOOR_NORDIC_VILLAGE = 0x46688E;
	static inline final FLOOR_OTHER = 0x4A4A52;

	var ctx:Context;
	var refs:Refs;

	/** The radius of the disc, in pixels. It changes with the setting, so the disc is drawn again. */
	var radius(get, never):Float;

	var radiusValue = 120.0;

	var zoomIndex = 2;

	var showChests = true;
	var showMonsters = true;
	var showParty = true;
	var showExits = true;
	var showHud = true;

	var dungeonStart = -1;
	var goldBase = 0;

	// The layers, back to front
	var back = new Sprite();
	var map = new Sprite();
	var rim = new Sprite();
	var markers = new Sprite();
	var hud = new Sprite();

	// The floor, read once per floor
	var tiles:Array<Tile> = [];
	var tilesFloorId = -1;
	var exits:Array<Tile> = [];
	var exitColors:Map<String, Int> = new Map();
	var tilesByPosition:Map<String, Tile> = new Map();

	// The drawn map
	var dirty = true;
	var baseScale = 0.03;
	var scale = 0.03;

	// Where the hero was when the disc was cut, in world units
	var cutX = 0.0;
	var cutY = 0.0;

	// Where the hero is now, in world units
	var heroX = 0.0;
	var heroY = 0.0;

	// The markers
	var monsterLayer = new Sprite();
	var arrowSprite = new Sprite();
	var northSprite = new Sprite();
	var exitArrows = new Sprite();
	var chestSprites:Array<Sprite> = [];
	var chestKinds:Array<Int> = [];
	var portraitSprites:Map<Int, Sprite> = new Map();
	var monsterFrames = 0;
	var gateFrames = 0;
	var lastChests = -1;
	var seenKinds:Map<Int, Bool> = new Map();

	// The text
	var floorLabel:TextField;
	var timerLabel:TextField;
	var goldLabel:TextField;
	var expLabel:TextField;
	var floorFmt:TextFormat;
	var timerFmt:TextFormat;
	var goldFmt:TextFormat;
	var expFmt:TextFormat;

	/** The experience the hero had when the dungeon started, to show the one it made. */
	public var expBase:Int = -1;

	public function new(ctx:Context, refs:Refs) {
		super();
		this.ctx = ctx;
		this.refs = refs;

		mouseEnabled = false;
		mouseChildren = false;

		addChild(back);
		addChild(map);
		addChild(rim);
		addChild(markers);
		addChild(hud);

		markers.addChild(monsterLayer);
		markers.addChild(arrowSprite);
		markers.addChild(northSprite);
		markers.addChild(exitArrows);

		drawArrow();
		drawNorth();
		drawBack();
		drawRim();

		floorFmt = textFormat(11, 0xFFFFFF, true);
		timerFmt = textFormat(11, 0xFFFFFF, true);
		goldFmt = textFormat(11, 0xFFD700, true);
		expFmt = textFormat(11, 0x7FD1FF, true);
		floorLabel = label(floorFmt);
		timerLabel = label(timerFmt);
		goldLabel = label(goldFmt);
		expLabel = label(expFmt);

		addEventListener(Event.ENTER_FRAME, onFrame);
	}

	function get_radius():Float
		return radiusValue;

	/** A format for the lines under the disc, centered on it. */
	function textFormat(size:Int, color:Int, bold:Bool):TextFormat {
		var fmt = new TextFormat("Arial", size, color, bold);
		// The alignment lives in the format: a text field has no textAlign of its own
		fmt.align = "center";
		return fmt;
	}

	function label(fmt:TextFormat):TextField {
		var t = new TextField();
		t.defaultTextFormat = fmt;
		t.selectable = false;
		t.mouseEnabled = false;
		t.width = radius * 2;
		t.height = 16;
		t.x = -radius;
		hud.addChild(t);
		return t;
	}

	/** Writes a line, keeping it centered under the disc. */
	function write(t:TextField, fmt:TextFormat, text:String):Void {
		if (t.text != text) {
			t.text = text;
			if (text.length > 0)
				t.setTextFormat(fmt, 0, text.length);
		}
		center(t);
	}

	/**
	 * Puts a line in the middle of the disc.
	 *
	 * The alignment of the format does not hold in this runtime, so the line is moved by its own
	 * width instead. A rough width is used when the field has not measured itself yet.
	 */
	function center(t:TextField):Void {
		var w = 0.0;
		try {
			w = t.textWidth;
		} catch (error:Dynamic) {
			w = 0;
		}
		if (w <= 0)
			w = t.text.length * 6.4;
		t.x = -w * 0.5;
	}

	// ------------------------------------------------------------------ the disc

	/** The dark disc the map sits on. */
	function drawBack():Void {
		var g = back.graphics;
		g.clear();
		g.beginFill(0x08090B, 0.9);
		g.drawCircle(0, 0, radius);
		g.endFill();
	}

	/** The rim and its marks, drawn over the map so the cut edge stays hidden. */
	function drawRim():Void {
		var g = rim.graphics;
		g.clear();
		g.lineStyle(2.5, 0xFFD24D, 0.95);
		g.drawCircle(0, 0, radius);
		g.lineStyle(1, 0x8A8F98, 0.85);
		for (i in 0...12) {
			var a = i * 30 * Math.PI / 180;
			var inner = radius - (i % 3 == 0 ? 10 : 5);
			g.moveTo(Math.cos(a) * inner, Math.sin(a) * inner);
			g.lineTo(Math.cos(a) * radius, Math.sin(a) * radius);
		}
	}

	/**
	 * The experience the hero has gathered in the map, the same way the gold is counted.
	 *
	 * The first time the hero is seen, the experience it has is the base: what comes after it is
	 * what the map gave.
	 */
	function drawExp():Void {
		var hero = refs.localHero;
		if (hero == null) {
			write(expLabel, expFmt, "");
			return;
		}
		var xp = -1;
		try {
			xp = Std.int(hero.experiencePoints);
		} catch (error:Dynamic) {
			xp = -1;
		}
		if (xp < 0) {
			write(expLabel, expFmt, "");
			return;
		}
		if (expBase < 0)
			expBase = xp;
		write(expLabel, expFmt, "EXP " + (xp - expBase));
	}

	/** Changes the size of the disc, and draws it again. */
	public function setRadius(value:Float):Void {
		if (value == radiusValue)
			return;
		radiusValue = value;
		drawBack();
		drawRim();
		// The cut of the disc is made for the old size
		dirty = true;
	}

	// ------------------------------------------------------------------ per frame

	function onFrame(_:Event):Void {
		if (!ctx.core.alive)
			return;
		if (!visible)
			return;

		place();

		var hero = localHero();
		if (hero == null)
			return;

		heroX = hero.x;
		heroY = hero.y;

		readFloor();
		updateZoom();

		// The disc is cut around the hero, so it has to be cut again as he walks
		var walked = Math.sqrt((heroX - cutX) * (heroX - cutX) + (heroY - cutY) * (heroY - cutY));
		if (dirty || walked * scale > RECUT_PIXELS)
			drawMap();

		// The map does not turn: north is up, and the hero stays in the middle of the disc
		map.scaleX = scale;
		map.scaleY = scale;
		map.rotation = 0;
		map.x = -scale * heroX;
		map.y = -scale * heroY;

		drawMarkers();
		drawHud();
	}

	/** The hero of the local player, from the api. */
	function localHero():Hero {
		for (hero in ctx.state.heroes)
			if (hero.local)
				return hero;
		return null;
	}

	/** Puts the disc in the corner, with the text under it. */
	function place():Void {
		var w = ctx.viewWidth;
		var h = ctx.viewHeight;
		if (w <= 0 || h <= 0)
			return;
		// The disc hangs from the top right corner, and never leaves the view
		x = Math.max(radius, w - radius - MARGIN);
		y = Math.max(radius, Math.min(radius + TOP, h - radius - 120));
		// The lines are centered on the disc by their own width: see center()
		center(floorLabel);
		center(timerLabel);
		center(goldLabel);
		center(expLabel);
		floorLabel.y = radius + 6;
		timerLabel.y = radius + 20;
		goldLabel.y = radius + 34;
		expLabel.y = radius + 48;
	}

	/** The scale of the map: the floor fits the disc, times the zoom step. */
	function updateZoom():Void {
		scale = baseScale * ZOOM_STEPS[zoomIndex];
	}

	/** The scale at which the whole floor fits the disc. */
	function computeBaseScale():Void {
		var first = true;
		var minX = 0.0, minY = 0.0, maxX = 0.0, maxY = 0.0;
		for (t in tiles) {
			if (t.category == "FILLER_TILE")
				continue;
			if (first) {
				minX = t.x;
				minY = t.y;
				maxX = t.x + TILE_SIZE;
				maxY = t.y + TILE_SIZE;
				first = false;
				continue;
			}
			minX = Math.min(minX, t.x);
			minY = Math.min(minY, t.y);
			maxX = Math.max(maxX, t.x + TILE_SIZE);
			maxY = Math.max(maxY, t.y + TILE_SIZE);
		}
		if (first) {
			baseScale = 0.03;
			return;
		}
		var span = Math.max(maxX - minX, maxY - minY);
		baseScale = (radius * 1.72) / span;
	}

	// ------------------------------------------------------------------ the floor

	/** Reads the tiles of the floor, once per floor. */
	function readFloor():Void {
		var floor = ctx.state.floor;
		if (floor == null)
			return;
		if (floor.id == tilesFloorId && tiles.length > 0)
			return;
		tilesFloorId = floor.id;
		tiles = floor.tiles;
		exits = [];
		exitColors = new Map();
		tilesByPosition = new Map();
		seenKinds = new Map();
		for (t in tiles) {
			if (t.category == "FILLER_TILE")
				continue;
			tilesByPosition.set(key(t.x, t.y), t);
			if (t.category == "EXIT_TILE")
				exits.push(t);
		}
		computeBaseScale();
		readExitColors();
		dirty = true;
		Log.write("floor " + floor.id + " map=" + floor.map + " tiles=" + tiles.length + " exits=" + exits.length
			+ " theme=" + themeColor() + " doobers=" + refs.doobers.length + " baseScale=" + baseScale);
	}

	/** The color of every exit: what it takes to open it, and whether it is open now. */
	function readExitColors():Void {
		for (t in exits) {
			var k = key(t.x, t.y);
			var color = gateColor(t);
			if (exitColors.get(k) != color) {
				exitColors.set(k, color);
				// The tile of the exit is painted with this color
				dirty = true;
			}
		}
	}

	/**
	 * The color of an exit tile.
	 *
	 * The library says what the gate is: a plate to step on, or monsters to kill. The tile says
	 * whether it stands open now.
	 */
	function gateColor(tile:Tile):Int {
		var mode = GATE_UNKNOWN;
		try {
			var objects = libraryObjects(tile.id);
			if (objects != null) {
				var kills = false;
				var plate = false;
				for (o in objects) {
					var type = Std.string(o.type);
					var constant = Std.string(o.constant);
					if (type == "LENPCGeneratorWithAllSpawnsDeadTrigger")
						kills = true;
					else if (type == "LETrigger" && constant == "PROXIMITY_TRIGGER")
						plate = true;
				}
				if (kills)
					mode = GATE_KILLS;
				else if (plate)
					mode = GATE_PLATE;
			}
		} catch (error:Dynamic) {
			Log.write("gate mode of " + tile.id + ": " + Std.string(error));
		}

		var state = GATE_UNKNOWN;
		try {
			var floor = liveFloor();
			if (floor != null && floor.tileGrid != null) {
				var gameTile:Dynamic = floor.tileGrid.getTileAtPosition(new Vector3D(tile.x, tile.y));
				if (gameTile != null) {
					var found = false;
					var closed = false;
					var breakable = false;
					for (npc in toArray(Reflect.getProperty(gameTile, "NPCGameObjects"))) {
						var type:Int = Std.int(Reflect.getProperty(npc, "type"));
						if (type < 2000000 || type >= 3000000)
							continue;
						var suffix = type % 10000;
						if (suffix != 101 && suffix != 201)
							continue;
						found = true;
						if (Reflect.getProperty(npc, "triggerState") == true)
							continue;
						closed = true;
						if (Reflect.getProperty(npc, "isAttackable") == true)
							breakable = true;
					}
					if (found) {
						if (!closed)
							state = GATE_OPEN;
						else if (breakable)
							state = GATE_BREAK;
						else
							state = GATE_CLOSED;
					}
				}
			}
		} catch (error:Dynamic) {
			Log.write("gate state of " + tile.id + ": " + Std.string(error));
		}

		if (state == GATE_OPEN)
			return GATE_OPEN;
		if (state == GATE_BREAK)
			return GATE_BREAK;
		if (state == GATE_CLOSED)
			return mode == GATE_UNKNOWN ? GATE_CLOSED : mode;
		if (mode != GATE_UNKNOWN)
			return mode;
		return GATE_UNKNOWN;
	}

	/** The floor of the game, the one the hero walks on. */
	function liveFloor():DistributedDungeonFloor {
		if (refs.localHero != null)
			return refs.localHero.distributedDungeonFloor;
		return refs.floor;
	}

	/**
	 * The objects of a tile, as the library holds them.
	 *
	 * The library is a plain dynamic object, so its lists are read without casting them to a Haxe
	 * array: they are not one, and a tile with a single object holds it alone, not in a list.
	 */
	function libraryObjects(tileId:String):Array<Dynamic> {
		return libraryList(tileId, "LEObjects");
	}

	/** The background of a tile, as the library holds it. */
	function libraryBackground(tileId:String):Array<Dynamic> {
		return libraryList(tileId, "LEBackground");
	}

	/** One of the lists of a tile of the library, a single object read as a list of one. */
	function libraryList(tileId:String, field:String):Array<Dynamic> {
		var floor = liveFloor();
		if (floor == null || floor.dungeonFloorFactory == null || floor.dungeonFloorFactory.tileFactory == null)
			return [];
		var map:Dynamic = @:privateAccess floor.dungeonFloorFactory.tileFactory.mTileMap;
		if (map == null)
			return [];
		var json:Dynamic = map.itemFor(tileId);
		if (json == null)
			return [];
		var list:Dynamic = Reflect.field(json, field);
		if (list == null)
			return [];
		// A single object is not a list: it has a type and no length
		if (Reflect.field(list, "length") == null && Reflect.field(list, "type") != null)
			return [list];
		return toArray(list);
	}

	// ------------------------------------------------------------------ drawing the map

	/**
	 * Draws the floor, cut to the disc.
	 *
	 * The map is drawn in world coordinates and the disc is cut around the hero, so the map only
	 * has to be drawn again when he walks out of the cut.
	 */
	function drawMap():Void {
		map.graphics.clear();
		cutX = heroX;
		cutY = heroY;
		dirty = false;
		if (tiles.length == 0)
			return;

		var r = radius / scale;
		var strip = 2.0 / Math.max(scale, 0.0001);
		var floorColor = themeColor();

		// The rooms
		for (t in tiles) {
			if (t.category == "FILLER_TILE")
				continue;
			var color = floorColor;
			if (t.category == "EXIT_TILE")
				color = exitColors.get(key(t.x, t.y));
			if (color == null)
				color = floorColor;
			drawClipped(map.graphics, t.x + WALL, t.y + WALL, TILE_SIZE - WALL * 2, TILE_SIZE - WALL * 2, color, 0.96, strip, r);
		}

		// The passages
		for (t in tiles) {
			if (t.category == "FILLER_TILE")
				continue;
			var half = CORRIDOR * 0.5;
			if (joined(t, 1))
				drawClipped(map.graphics, t.x + TILE_SIZE - WALL - CORRIDOR_OVERLAP, t.y + TILE_SIZE * 0.5 - half,
					WALL * 2 + CORRIDOR_OVERLAP * 2, CORRIDOR, floorColor, 0.96, strip, r);
			if (joined(t, 2))
				drawClipped(map.graphics, t.x + TILE_SIZE * 0.5 - half, t.y + TILE_SIZE - WALL - CORRIDOR_OVERLAP,
					CORRIDOR, WALL * 2 + CORRIDOR_OVERLAP * 2, floorColor, 0.96, strip, r);
		}
	}

	/**
	 * Draws a rectangle, cut to the circle around the hero.
	 *
	 * The circle is cut in vertical strips: each strip takes the part of its column that falls
	 * inside the circle, so the edge of the disc stays smooth.
	 */
	function drawClipped(g:Graphics, x:Float, y:Float, w:Float, h:Float, color:Int, alpha:Float, strip:Float, r:Float):Void {
		if (w <= 0 || h <= 0)
			return;
		// A room well inside the circle is drawn whole: no strips needed
		if (insideCircle(x, y, w, h, r)) {
			g.beginFill(color, alpha);
			g.drawRect(x, y, w, h);
			g.endFill();
			return;
		}
		var count = Math.ceil(w / strip);
		if (count < 1)
			count = 1;
		var step = w / count;
		g.beginFill(color, alpha);
		for (i in 0...count) {
			var sx = x + i * step;
			// How far the middle of this column is from the hero, sideways
			var offX = sx + step * 0.5 - cutX;
			if (Math.abs(offX) >= r)
				continue;
			// How far the circle reaches up and down, in this column
			var reach = Math.sqrt(r * r - offX * offX);
			var top = Math.max(y, cutY - reach);
			var bottom = Math.min(y + h, cutY + reach);
			if (bottom <= top)
				continue;
			g.drawRect(sx, top, step, bottom - top);
		}
		g.endFill();
	}

	/** Whether the whole rectangle falls inside the circle around the hero. */
	function insideCircle(x:Float, y:Float, w:Float, h:Float, r:Float):Bool {
		var cx = x + w * 0.5 - cutX;
		var cy = y + h * 0.5 - cutY;
		var far = Math.sqrt(w * w + h * h) * 0.5;
		return far + Math.sqrt(cx * cx + cy * cy) <= r;
	}

	/** Whether the tile is joined to its neighbor on that side: both sides open. */
	function joined(tile:Tile, side:Int):Bool {
		if (tile.exits == null || side >= tile.exits.length)
			return false;
		if (tile.exits[side] != true)
			return false;
		var neighbor = neighborOf(tile, side);
		if (neighbor == null)
			return false;
		var other = side == 0 ? 2 : (side == 1 ? 3 : (side == 2 ? 0 : 1));
		if (neighbor.exits == null || other >= neighbor.exits.length)
			return false;
		return neighbor.exits[other] == true;
	}

	/** The tile on that side, when there is one. */
	function neighborOf(tile:Tile, side:Int):Tile {
		var nx = tile.x;
		var ny = tile.y;
		if (side == 0)
			ny -= TILE_SIZE;
		else if (side == 1)
			nx += TILE_SIZE;
		else if (side == 2)
			ny += TILE_SIZE;
		else
			nx -= TILE_SIZE;
		return tilesByPosition.get(key(nx, ny));
	}

	/**
	 * The color of the floor.
	 *
	 * The background of the tiles says which of the three worlds the floor belongs to: CASTLE_,
	 * JURASSIC_ or NORDIC_. The name of the map says it too, and is the fallback. Inside a world,
	 * the name gives each place a shade of its own.
	 */
	function themeColor():Int {
		var world = themeWorld();
		var floor = ctx.state.floor;
		var name = floor == null ? "" : floor.map;
		var upper = name.toUpperCase();
		if (world == FLOOR_CASTLE) {
			if (hasAny(upper, ["ARENA"]))
				return FLOOR_CASTLE_ARENA;
			if (hasAny(upper, ["CATACOMB", "CRYPT", "TOMB"]))
				return FLOOR_CASTLE_CRYPT;
			return FLOOR_CASTLE;
		}
		if (world == FLOOR_JUNGLE) {
			if (hasAny(upper, ["AZTEC"]))
				return FLOOR_JUNGLE_AZTEC;
			if (hasAny(upper, ["TRIBAL"]))
				return FLOOR_JUNGLE_TRIBAL;
			return FLOOR_JUNGLE;
		}
		if (world == FLOOR_NORDIC) {
			if (hasAny(upper, ["TEMPLE"]))
				return FLOOR_NORDIC_TEMPLE;
			if (hasAny(upper, ["VILLAGE"]))
				return FLOOR_NORDIC_VILLAGE;
			return FLOOR_NORDIC;
		}
		return FLOOR_OTHER;
	}

	/** Which of the three worlds the floor belongs to. */
	function themeWorld():Int {
		// Any tile of the floor says it: the first that carries a background of a world
		var checked = 0;
		for (t in tiles) {
			if (t.category == "FILLER_TILE")
				continue;
			if (checked++ > 24)
				break;
			try {
				for (b in libraryBackground(t.id)) {
					var constant = Std.string(b.constant);
					if (constant.indexOf("CASTLE_") == 0)
						return FLOOR_CASTLE;
					if (constant.indexOf("JURASSIC_") == 0)
						return FLOOR_JUNGLE;
					if (constant.indexOf("NORDIC_") == 0)
						return FLOOR_NORDIC;
				}
			} catch (error:Dynamic) {}
		}

		var floor = ctx.state.floor;
		var name = floor == null ? "" : floor.map;
		var upper = name.toUpperCase();
		if (hasAny(upper, ["DINO", "AZTEC", "TRIBAL", "JUNGLE", "JURASSIC", "SWAMP", "FOREST", "MUSHROOM"]))
			return FLOOR_JUNGLE;
		if (hasAny(upper, ["PRISON", "ARENA", "CATACOMB", "CASTLE", "CRYPT", "TOMB", "DUNGEON", "KEEP", "MAZE"]))
			return FLOOR_CASTLE;
		if (hasAny(upper, ["NORDIC", "CAVE", "TEMPLE", "VILLAGE", "FROST", "ICE", "SNOW", "WINTER", "FROZEN", "GLACIER"]))
			return FLOOR_NORDIC;
		return FLOOR_OTHER;
	}

	/** Whether the name has one of the words. */
	function hasAny(name:String, words:Array<String>):Bool {
		for (w in words)
			if (name.indexOf(w) >= 0)
				return true;
		return false;
	}

	// ------------------------------------------------------------------ the markers

	function drawMarkers():Void {
		monsterLayer.visible = showMonsters;
		if (showMonsters && monsterFrames++ % MONSTER_EVERY == 0)
			drawMonsters();

		// A gate opens while the floor is played, so its color is read again now and then
		if (gateFrames++ % GATE_EVERY == 0)
			readExitColors();

		drawChests();
		drawParty();

		// The hero: an arrow that points the way he faces
		arrowSprite.x = 0;
		arrowSprite.y = 0;
		arrowSprite.rotation = refs.localHero == null ? 0 : refs.localHero.heading + 90;

		// North is up, the map does not turn
		northSprite.x = 0;
		northSprite.y = -(radius + 9);

		drawExitArrows();
	}

	/** The hero: a gold arrow in the middle of the disc. */
	function drawArrow():Void {
		var g = arrowSprite.graphics;
		g.clear();
		g.beginFill(0xFFDF4D);
		g.lineStyle(2.5, 0x1A1400, 0.95);
		// The tip, the two wings and the notch: no closePath, the host graphics may not have it
		g.moveTo(0, -10);
		g.lineTo(8, 5);
		g.lineTo(0, 2);
		g.lineTo(-8, 5);
		g.lineTo(0, -10);
		g.endFill();
	}

	/** The north pointer, on the rim. */
	function drawNorth():Void {
		var g = northSprite.graphics;
		g.clear();
		g.beginFill(0xFF5555);
		g.lineStyle(1, 0x000000, 0.7);
		g.drawCircle(0, 0, 4);
		g.endFill();
	}

	function drawMonsters():Void {
		var g = monsterLayer.graphics;
		g.clear();
		var floor = ctx.state.floor;
		if (floor == null)
			return;
		g.beginFill(0xFF4444, 0.9);
		for (m in floor.monsters) {
			var p = radarPoint(m.x, m.y);
			if (p == null)
				continue;
			g.drawCircle(p.x, p.y, m.healthBar ? 3.4 : 2.2);
		}
		g.endFill();
	}

	/** The chests of the level, as blips on the disc, each drawn as the chest it is. */
	function drawChests():Void {
		if (!showChests) {
			for (s in chestSprites)
				s.visible = false;
			return;
		}
		// Only the chests that are really on the floor: the ones the server dropped. A tile of the
		// library may hold a treasure its layout never places.
		var seen = 0;
		for (doober in refs.doobers) {
			if (doober == null || doober.isDestroyed)
				continue;
			var data = doober.mDooberData;
			if (data == null || data.DooberType != "TREASURE")
				continue;
			var pos = doober.position;
			if (pos == null)
				continue;
			var p = radarPoint(pos.x, pos.y);
			if (p == null)
				continue;
			var kind = chestKind(data);
			var sprite = chestSprites[seen];
			if (sprite == null) {
				sprite = new Sprite();
				sprite.mouseEnabled = false;
				chestSprites[seen] = sprite;
				chestKinds[seen] = -1;
				markers.addChild(sprite);
			}
			// The chest of a slot may be another one now: its picture is drawn for the kind
			if (chestKinds[seen] != kind) {
				chestKinds[seen] = kind;
				drawChest(sprite, kind);
			}
			if (!seenKinds.exists(kind)) {
				seenKinds.set(kind, true);
				Log.write("chest kind " + kind + " (" + chestName(kind) + ")");
			}
			sprite.visible = true;
			sprite.x = p.x;
			sprite.y = p.y;
			seen++;
		}
		for (i in seen...chestSprites.length)
			chestSprites[i].visible = false;
		if (seen != lastChests) {
			lastChests = seen;
			Log.write("chests in sight " + seen + " of " + refs.doobers.length);
		}
	}

	/** Which of the six treasures of the game this is. */
	function chestKind(data:Dynamic):Int {
		var constant = "";
		try {
			constant = Std.string(data.Constant).toUpperCase();
		} catch (error:Dynamic) {}
		if (constant == "SILVER_CHEST")
			return CHEST_SILVER;
		if (constant == "GOLD_CHEST")
			return CHEST_GOLD;
		if (constant == "DRAGON_CHEST")
			return CHEST_DRAGON;
		if (constant == "SMALL_ITEM_BOX")
			return CHEST_SMALL;
		if (constant == "ROYAL_ITEM_BOX")
			return CHEST_ROYAL;
		return CHEST_WOOD;
	}

	/** The name of the kind, as the game calls it. */
	function chestName(kind:Int):String {
		if (kind == CHEST_SILVER)
			return "Uncommon Chest";
		if (kind == CHEST_GOLD)
			return "Rare Chest";
		if (kind == CHEST_DRAGON)
			return "Legendary Chest";
		if (kind == CHEST_SMALL)
			return "Small Item Box";
		if (kind == CHEST_ROYAL)
			return "Royal Item Box";
		return "Basic Chest";
	}

	/** A chest of the kind, drawn small, straight onto the slot of the radar. */
	function drawChest(s:Sprite, kind:Int):Void {
		var g = s.graphics;
		g.clear();
		var body = CHEST_WOOD_BODY;
		var lid = CHEST_WOOD_LID;
		var trim = CHEST_WOOD_TRIM;
		if (kind == CHEST_SILVER) {
			body = CHEST_SILVER_BODY;
			lid = CHEST_SILVER_LID;
			trim = CHEST_SILVER_TRIM;
		} else if (kind == CHEST_GOLD) {
			body = CHEST_GOLD_BODY;
			lid = CHEST_GOLD_LID;
			trim = CHEST_GOLD_TRIM;
		} else if (kind == CHEST_DRAGON) {
			body = CHEST_DRAGON_BODY;
			lid = CHEST_DRAGON_LID;
			trim = CHEST_DRAGON_TRIM;
		} else if (kind == CHEST_SMALL) {
			body = CHEST_SMALL_BODY;
			lid = CHEST_SMALL_LID;
			trim = CHEST_SMALL_TRIM;
		} else if (kind == CHEST_ROYAL) {
			body = CHEST_ROYAL_BODY;
			lid = CHEST_ROYAL_LID;
			trim = CHEST_ROYAL_TRIM;
		}

		if (kind == CHEST_SMALL || kind == CHEST_ROYAL) {
			// An item box: a plain box with a ribbon, not a chest with a lid
			g.lineStyle(1, 0x10141A, 1);
			g.beginFill(body);
			g.drawRoundRect(-5, -5, 10, 10, 1.5, 1.5);
			g.endFill();
			g.beginFill(lid);
			g.drawRect(-5, -1.2, 10, 2.4);
			g.drawRect(-1.2, -5, 2.4, 10);
			g.endFill();
			g.beginFill(trim);
			g.drawRect(-2, -2, 4, 4);
			g.endFill();
			return;
		}

		// A chest: the body, the lid over it, and the lock in the middle
		g.beginFill(body);
		g.lineStyle(1, 0x10141A, 1);
		g.drawRoundRect(-5, -1, 10, 7, 1, 1);
		g.endFill();
		g.beginFill(lid);
		g.lineStyle(1, 0x10141A, 1);
		g.drawRoundRect(-5, -5, 10, 4.5, 2, 2);
		g.endFill();
		g.beginFill(trim);
		g.drawRect(-5, -1.2, 10, 1.2);
		g.drawRect(-1.2, -2.2, 2.4, 3);
		g.endFill();
	}

	/** The other heroes, with the picture of theirs. */
	function drawParty():Void {
		var alive:Map<Int, Bool> = new Map();
		if (showParty) {
			for (other in ctx.state.heroes) {
				if (other.local || other.player == null)
					continue;
				var p = radarPoint(other.x, other.y);
				if (p == null)
					continue;
				alive.set(other.id, true);
				var sprite = portraitSprites.get(other.id);
				if (sprite == null) {
					sprite = other.player.createPortrait(16);
					sprite.mouseEnabled = false;
					portraitSprites.set(other.id, sprite);
					markers.addChild(sprite);
				}
				sprite.visible = true;
				sprite.x = p.x - 8;
				sprite.y = p.y - 8;
			}
		}
		for (s in portraitSprites) {
			if (!alive.exists(s))
				portraitSprites.get(s).visible = false;
		}
	}

	/**
	 * An arrow on the rim, for every exit.
	 *
	 * The arrow always shows, near or far: it sits on the rim, pointing the way the exit lies from
	 * the hero. As he walks, it slides around the rim, so it always says where the gate is.
	 */
	function drawExitArrows():Void {
		var g = exitArrows.graphics;
		g.clear();
		if (!showExits)
			return;
		for (t in exits) {
			// The direction of the exit from the hero, without cutting it to the disc
			var p = rawPoint(t.x + TILE_SIZE * 0.5, t.y + TILE_SIZE * 0.5);
			var distance = Math.sqrt(p.x * p.x + p.y * p.y);
			if (distance < 0.001)
				continue;
			var angle = Math.atan2(p.y, p.x);
			var color = exitColors.get(key(t.x, t.y));
			if (color == null)
				color = GATE_UNKNOWN;
			var tx = Math.cos(angle);
			var ty = Math.sin(angle);
			var px = -ty;
			var py = tx;
			// On the rim, with the tip out of the disc, clear of the ticks
			var cx = tx * (radius + 1);
			var cy = ty * (radius + 1);
			g.beginFill(color, 0.95);
			g.lineStyle(1.2, 0x000000, 0.85);
			g.moveTo(cx + tx * 9, cy + ty * 9);
			g.lineTo(cx - tx * 3 + px * 6, cy - ty * 3 + py * 6);
			g.lineTo(cx - tx * 3 - px * 6, cy - ty * 3 - py * 6);
			g.lineTo(cx + tx * 9, cy + ty * 9);
			g.endFill();
			// A halo, so it stands out from the floor under it
			g.lineStyle(1, 0xFFFFFF, 0.35);
			g.drawCircle(cx + tx * 3, cy + ty * 3, 5);
		}
	}

	/** A point of the world in the disc, in screen pixels. */
	function rawPoint(worldX:Float, worldY:Float):{x:Float, y:Float} {
		return { x: scale * (worldX - heroX), y: scale * (worldY - heroY) };
	}

	/** A point of the world in the disc, or null when it is out of sight. */
	function radarPoint(worldX:Float, worldY:Float):{x:Float, y:Float} {
		var p = rawPoint(worldX, worldY);
		if (p.x * p.x + p.y * p.y > radius * radius)
			return null;
		return p;
	}

	// ------------------------------------------------------------------ the text

	function drawHud():Void {
		hud.visible = showHud;
		if (!showHud)
			return;
		var floor = ctx.state.floor;
		var name = floor == null ? "" : floor.map;
		var number = floor == null ? 0 : floor.number;
		write(floorLabel, floorFmt, name == "" ? "FLOOR " + number : name + " - FLOOR " + number);

		var seconds = Std.int((Lib.getTimer() - dungeonStart) / 1000);
		write(timerLabel, timerFmt, pad(Std.int(seconds / 3600)) + ":" + pad(Std.int(seconds % 3600 / 60)) + ":" + pad(seconds % 60));

		var account = ctx.state.account;
		var coins = account == null ? 0 : account.coins;
		write(goldLabel, goldFmt, "GOLD " + (coins - goldBase));

		drawExp();
	}

	inline function pad(n:Int):String
		return n < 10 ? "0" + n : "" + n;

	// ------------------------------------------------------------------ zoom

	public function zoomIn():Void {
		if (zoomIndex < ZOOM_STEPS.length - 1) {
			zoomIndex++;
			dirty = true;
		}
	}

	public function zoomOut():Void {
		if (zoomIndex > 0) {
			zoomIndex--;
			dirty = true;
		}
	}

	// ------------------------------------------------------------------ helpers

	function key(x:Float, y:Float):String
		return Std.int(x) + "," + Std.int(y);

	/**
	 * Turns a list of the library into a Haxe array.
	 *
	 * The library is a plain dynamic object, so its lists are not Haxe arrays: they are read by
	 * their length and their items.
	 */
	function toArray(list:Dynamic):Array<Dynamic> {
		var out:Array<Dynamic> = [];
		if (list == null)
			return out;
		try {
			var n = list.length;
			var i = 0;
			while (i < n) {
				out.push(list[i]);
				i++;
			}
		} catch (error:Dynamic) {}
		return out;
	}

	public function destroy():Void {
		removeEventListener(Event.ENTER_FRAME, onFrame);
		back.graphics.clear();
		map.graphics.clear();
		rim.graphics.clear();
		markers.graphics.clear();
		monsterLayer.graphics.clear();
		exitArrows.graphics.clear();
		while (numChildren > 0)
			removeChildAt(0);
	}
}
