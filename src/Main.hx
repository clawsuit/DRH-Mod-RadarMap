package mods.radarmap;

import distributedObjects.DistributedDungeonFloor;
import distributedObjects.HeroGameObjectOwner;
import doobers.DistributedDooberGameObject;
import doobers.DooberGameObject;
import mods.api.Context;
import mods.api.Mod;
import mods.api.dungeon.Floor;
import mods.api.settings.Flag;
import mods.api.settings.KeyAction;
import mods.api.settings.Slider;
import openfl.Lib;
import openfl.ui.Keyboard;

/**
 * A radar of the dungeon floor, in the top right corner.
 *
 * The camera does not turn, so the map does not either: north is always up and the arrow in the
 * middle points the way the hero faces. The rooms and the corridors come from the tiles the
 * server laid out. The chests, the enemies, the party and the exits are marked on it, and under
 * it are the floor, the timer, the gold and the experience.
 *
 * Configure it in the game's settings menu, and bind the key that shows and hides it.
 */
class Main extends Mod {
	var ctx:Context;
	var refs:Refs = new Refs();
	var radar:Radar = null;

	/** When the dungeon started, for the timer. Kept across floors. */
	var dungeonStart:Int = -1;

	/** The balance when the dungeon started, to show the gold it made. */
	var goldBase:UInt = 0;

	/** The experience when the dungeon started, to show the one it made. */
	var expBase:Int = -1;

	// Options, shown in the game's settings menu
	var flagChests:Flag;
	var flagMonsters:Flag;
	var flagParty:Flag;
	var flagExits:Flag;
	var flagHud:Flag;
	var sliderRadius:Slider;

	var keyToggle:KeyAction;
	var keyZoomIn:KeyAction;
	var keyZoomOut:KeyAction;

	override public function init(context:Context):Void {
		ctx = context;
		try {
			Log.start(ctx.data);
		} catch (error:Dynamic) {}
		Log.write("init");

		flagChests = ctx.settings.flag("chests", "Chests", "Shows the treasure chests on the radar.", true);
		flagMonsters = ctx.settings.flag("monsters", "Monsters", "Shows the enemies on the radar.", true);
		flagParty = ctx.settings.flag("party", "Party", "Shows the other heroes on the radar.", true);
		flagExits = ctx.settings.flag("exits", "Exits", "Shows the exits and the state of their gates.", true);
		flagHud = ctx.settings.flag("hud", "HUD", "Shows the floor, the timer, the gold and the experience under the radar.", true);
		sliderRadius = ctx.settings.slider("radius", "Radius", "The radius of the radar, in pixels.", 120, 220, 10, 120);

		keyToggle = ctx.keys.action("toggleRadar", "Show Radar", "Shows or hides the radar.", Keyboard.N);
		keyToggle.onPress(function() {
			if (radar != null)
				radar.visible = !radar.visible;
		});

		// The game binds no bracket key, so these are free to use.
		keyZoomIn = ctx.keys.action("zoomIn", "Zoom In", "Zooms the radar in.", 219);
		keyZoomIn.onPress(function() {
			if (radar != null)
				radar.zoomIn();
		});
		keyZoomOut = ctx.keys.action("zoomOut", "Zoom Out", "Zooms the radar out.", 221);
		keyZoomOut.onPress(function() {
			if (radar != null)
				radar.zoomOut();
		});

		// The wheel, over the radar, zooms it too
		var stage = ctx.overlay.stage;
		if (stage != null)
			stage.addEventListener(openfl.events.MouseEvent.MOUSE_WHEEL, onWheel);

		ctx.onFloorEnter(onFloorEnter);
		ctx.onFloorExit(onFloorExit);

		// The live objects the radar reads. The api gives the state, but not the objects behind it.
		ctx.core.onObjectReady(function(object:Dynamic) {
			if (Std.isOfType(object, HeroGameObjectOwner)) {
				refs.localHero = cast object;
			} else if (Std.isOfType(object, DistributedDungeonFloor)) {
				refs.floor = cast object;
			} else if (Std.isOfType(object, DooberGameObject)) {
				refs.addDoober(cast object);
			} else if (Std.isOfType(object, DistributedDooberGameObject)) {
				var true = Reflect.callMethod(object, Reflect.field(object, "getTrueObject"), []);
				if (true != null && Std.isOfType(true, DooberGameObject))
					refs.addDoober(cast true);
			}
		});
		ctx.core.onObjectGone(function(object:Dynamic) {
			if (object == refs.localHero)
				refs.localHero = null;
			if (object == refs.floor)
				refs.floor = null;
			refs.removeDoober(object);
		});
	}

	function onWheel(event:openfl.events.MouseEvent):Void {
		if (radar == null || !radar.visible)
			return;
		// Only when the pointer is over the radar
		var w = ctx.viewWidth;
		var h = ctx.viewHeight;
		if (w <= 0 || h <= 0)
			return;
		var mx = ctx.overlay.mouseX - radar.x;
		var my = ctx.overlay.mouseY - radar.y;
		if (mx * mx + my * my > radar.radius * radar.radius)
			return;
		if (event.delta > 0)
			radar.zoomIn();
		else
			radar.zoomOut();
	}

	function onFloorEnter(floor:Floor):Void {
		if (floor.number == 1 || dungeonStart < 0) {
			dungeonStart = Lib.getTimer();
			goldBase = currentCoins();
			// The experience is read when the hero appears, so it starts unknown
			expBase = -1;
		} else if (radar != null) {
			// The same dungeon: it keeps the experience it had gathered
			expBase = radar.expBase;
		}
		removeRadar();
		radar = new Radar(ctx, refs);
		radar.dungeonStart = dungeonStart;
		radar.goldBase = goldBase;
		radar.expBase = expBase;
		radar.setRadius(sliderRadius.value);
		radar.showChests = flagChests.value;
		radar.showMonsters = flagMonsters.value;
		radar.showParty = flagParty.value;
		radar.showExits = flagExits.value;
		radar.showHud = flagHud.value;
		ctx.overlay.addChild(radar);
		Log.write("floor enter " + floor.id + " map=" + floor.map + " radar=" + Std.string(radar));
	}

	function onFloorExit(floor:Floor):Void {
		removeRadar();
	}

	function removeRadar():Void {
		if (radar == null)
			return;
		radar.destroy();
		if (radar.parent != null)
			radar.parent.removeChild(radar);
		radar = null;
	}

	/** The balance of the account now, 0 when it cannot be read. */
	function currentCoins():UInt {
		var account = ctx.state.account;
		return account == null ? 0 : account.coins;
	}

	override public function ready(context:Context):Void {
		// The options may change while the mod runs.
		sliderRadius.onChange(function(value:Float) {
			if (radar != null)
				radar.setRadius(value);
		});
		flagChests.onChange(function(value:Bool) {
			if (radar != null)
				radar.showChests = value;
		});
		flagMonsters.onChange(function(value:Bool) {
			if (radar != null)
				radar.showMonsters = value;
		});
		flagParty.onChange(function(value:Bool) {
			if (radar != null)
				radar.showParty = value;
		});
		flagExits.onChange(function(value:Bool) {
			if (radar != null)
				radar.showExits = value;
		});
		flagHud.onChange(function(value:Bool) {
			if (radar != null)
				radar.showHud = value;
		});
	}

	override public function dispose():Void {
		var stage = ctx.overlay.stage;
		if (stage != null)
			stage.removeEventListener(openfl.events.MouseEvent.MOUSE_WHEEL, onWheel);
		removeRadar();
	}
}
