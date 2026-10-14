package funkin.mobile;

#if sys
import sys.io.File;
import sys.io.FileOutput;
import sys.thread.Mutex;
#end

class MobileLog
{
	public static var enabled:Bool = true;

	#if sys
	static var output:FileOutput = null;
	static var failed:Bool = false;
	static var mutex:Mutex = new Mutex();
	#end

	public static function getLogPath():String
		return funkin.backend.utils.StorageUtil.storageDirectory + "logs/latest.log";

	public static function write(line:String)
	{
		#if sys
		if (!enabled || failed)
			return;

		mutex.acquire();
		try
		{
			if (output == null)
			{
				funkin.backend.utils.StorageUtil.createDirectory(funkin.backend.utils.StorageUtil.storageDirectory + "logs");
				output = File.write(getLogPath(), false);
			}
			output.writeString(line + "\n");
			output.flush();
		}
		catch (e:Dynamic)
		{
			failed = true;
		}
		mutex.release();
		#end
	}
}
