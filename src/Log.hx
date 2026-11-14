package mods.radarmap;

import sys.io.File;

/** What the mod did, kept in its data folder, to see what happens without the game log. */
class Log {
	static inline final LIMIT = 12000;

	static var path:String = null;

	static var buffer:String = "";

	public static function start(folder:String):Void {
		path = folder + "/last.log";
		buffer = "";
		write("start");
	}

	public static function write(message:String):Void {
		buffer += message + "\n";
		if (buffer.length > LIMIT)
			buffer = buffer.substr(buffer.length - LIMIT / 2);
		flush();
	}

	static function flush():Void {
		if (path == null)
			return;
		try {
			File.saveContent(path, buffer);
		} catch (error:Dynamic) {}
	}
}
