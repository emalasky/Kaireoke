package com.k_oke
{
	import flash.events.Event;
	import flash.filesystem.File;

	public class KUnzipEvent extends Event
	{
		public function KUnzipEvent(type:String, kunzip:KUnzip, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			_unzip = kunzip;
		}
		
		private var _unzip:KUnzip;
		
		public function get kunzip():KUnzip { return _unzip; }
		
	}
}