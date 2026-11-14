package mods.radarmap;

import distributedObjects.DistributedDungeonFloor;
import distributedObjects.HeroGameObjectOwner;
import doobers.DooberGameObject;

/**
 * The live game objects the radar reads.
 *
 * The api gives the state, but not the objects behind it: the floor itself, the hero and the
 * doobers, the chests among them, are read here.
 */
class Refs {
	/** The hero of the local player. */
	public var localHero:HeroGameObjectOwner = null;

	/** The floor in progress. */
	public var floor:DistributedDungeonFloor = null;

	/** The doobers on the floor, the chests among them. */
	public var doobers:Array<DooberGameObject> = [];

	public function new() {}

	public function addDoober(doober:DooberGameObject):Void {
		if (doober == null)
			return;
		for (other in doobers)
			if (other == doober)
				return;
		doobers.push(doober);
	}

	public function removeDoober(object:Dynamic):Void {
		for (i in 0...doobers.length) {
			if (doobers[i] == object) {
				doobers.splice(i, 1);
				return;
			}
		}
	}
}
