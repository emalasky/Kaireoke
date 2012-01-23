package com.k_oke
{
	[Bindable]
	public class Singer
	{
		/*
		SINGER_ID INTEGER PRIMARY KEY AUTOINCREMENT, USERID TEXT, " +
				" FIRST_NAME TEXT, LAST_NAME TEXT, EMAIL TEXT, PHONE TEXT
		*/
		
		[Id]
		[Column (name="singer_id")]
		public var id:int;
		
		[Unique]
		public var username:String;
		
		public var firstName:String;
		
		public var lastName:String;
		
		public var email:String;
		
		public var phone:String;
		
		public var persistent:Boolean;
		
		public function Singer()
		{
		}

	}
}