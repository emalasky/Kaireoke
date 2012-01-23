package com.k_oke
{
	import flash.events.Event;

	public class KDatabaseEvent extends Event
	{
		public static const ADD_PROGRESS:String = "addProgress";
		public static const ADD_COMPLETE:String = "addComplete";
		public static const ADD_ERROR:String = "addError";
		public static const ADD_WARNING:String = "addWarning";
		
		public var directoriesAdded:Number;
		public var directoriesCompleted:Number;
		public var url:String;
		
		public function KDatabaseEvent(type:String, added:Number=0, completed:Number=0, url:String=null, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			directoriesAdded = added;
			directoriesCompleted = completed;
			this.url = url;
		}
		
		
		
	}
}