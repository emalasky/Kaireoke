package com.k_oke.controls
{
	import flash.display.Bitmap;
	import flash.events.*;
	import mx.containers.Canvas;
	import mx.events.*;

	public class Monitor extends Canvas
	{
		public function Monitor()
		{
			super();
			addEventListener(FlexEvent.CREATION_COMPLETE, onCreationComplete);
			addEventListener(FlexEvent.ADD, onResize);
			addEventListener(ResizeEvent.RESIZE, onResize);
			width=300; height=216;
			setStyle("backgroundColor", 0x222222 ); 
			
		}
		public function onCreationComplete( event:FlexEvent ):void
		{
			_updateBitmap();	
		}
		private function onResize( e:Event ):void
		{
			adjustSize();
		}
		public function adjustSize():void
		{
			const widthToHeight:Number = (300/216);
			const heightToWidth:Number = (216/300);
			var ratio:Number = width/height;
			if (_bitmap)
			{
				if ( ratio < widthToHeight )
				{
					_bitmap.width = this.width;
					
					var h:Number = this.width * heightToWidth;
					_bitmap.height = h;
					
					// center vertically
					_bitmap.x = 0;
					_bitmap.y = (this.height - _bitmap.height)/2;
				}
				else
				{
					_bitmap.height = this.height;
					var w:Number = this.height * widthToHeight;
					_bitmap.width = w;
					
					// center horizontally
					_bitmap.x = (this.width - _bitmap.width)/2;
					_bitmap.y = 0;
					
				}
				
				
				
			}
		}
		private var _bitmap:Bitmap;
		private function constructBitmap(player:KPlayer):Bitmap
		{
			return new Bitmap(player.cdgBitmapData);
		}
		private function _updateBitmap():void
		{
			var player:KPlayer = null;
			try {
				player = KGlobals.globals.playerWindow.player;
			}
			catch( e:Error ){}

			if (_bitmap)
			{
				rawChildren.removeChild(_bitmap);
				_bitmap = null;
			}			

			if (player)
			{
				_bitmap = constructBitmap( player );
				rawChildren.addChild(_bitmap);
				adjustSize();
			}
			
		}
	}
}