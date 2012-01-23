package com.k_oke
{
	[Bindable]
	public class Song
	{
		[Id]
		[Column( name="song_id" )]
		public var id:int;
		
		[Column( name="song_name" )]
		public var name:String;
		
		[Column( name="song_artist" )]
		public var artist:String;
		
		[Column( name="qpid" )]
		public var qpid:String;
		
		[Column( name="song_file_path" )]
		[Unique]
		public var filePath:String;
		
		[Column( name="song_file_name" )]
		public var fileName:String;
		 
		public function Song()
		{
			
		}

	}
}