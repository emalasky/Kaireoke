package com.k_oke
{
	import __AS3__.vec.Vector;
	
	import flash.filesystem.File;
	
	public class KUtilities
	{
		public function KUtilities()
		{

		}

		public static function stripExtension( file:File, exts:Array ):File
		{
			for( var i:int=0; i<exts.length; i++ )
			{
				if (file.extension == exts[i])
				{
					// strip the mp3; set it as the player root
					var plainName:String = file.name.substr( 0, file.name.length- (exts[i].length+1));
					var rootPath:File = file.parent.resolvePath( plainName );
					return rootPath;
				}
			}	
			return null;
		}

	}
}