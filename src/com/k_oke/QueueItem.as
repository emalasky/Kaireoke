package com.k_oke
{
	[Bindable]
	[Table(name="queue")]
	public class QueueItem
	{
		[Id]
		public var id:int;
		
		[ManyToOne]
		public var song:Song;
		
		[ManyToOne]
		public var singer:Singer;
		
		public var playOrder:int;
		
		public var transpose:int;
		
		public function QueueItem()
		{
			
		}

	}
}