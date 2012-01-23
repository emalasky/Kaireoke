package
{
	import flash.display.*;
	import flash.geom.Rectangle;
	
	public class CDGDisplay extends Sprite
	{
		private var bitmap:Bitmap;
	
		private var _colorTable:Vector.<uint>;
		private var _transparentColor:int;
		private var _backgroundColor:int;
		
		public var transparentBackground:Boolean = false;
		
		public function CDGDisplay()
		{
			super();
			bitmap = new Bitmap();
			addChild( bitmap );
			bitmap.bitmapData = new BitmapData(300,216);
			reset();
		}
		
		public function get cdgBitmapData():BitmapData { return bitmap.bitmapData; }
		
		public function reset():void
		{
			// init the display
			var bd:BitmapData = bitmap.bitmapData;
			bd.fillRect( new Rectangle(0,0,300,216), 0x00000000 );
			
			// init colors we care about
			_colorTable = new Vector.<uint>(16);
			_transparentColor = -1;
			_backgroundColor = -1;
		}
		
	   /*
		* In the CD+G system, 16 color graphics are displayed on a raster field which is
		* 300 x 216 pixels in size.  The middle 294 x 204 area is within the TV's
		* "safe area", and that is where the graphics are displayed.  The outer border is
		* set to a solid color.  The colors are stored in a 16 entry color lookup table.
		*
		* Each color in the table is drawn from an RGB space of 4096 (4 bits each for
		* R,G and B) colors.
		* 
		* Since we are using a 16 color table, each pixel can be stored in 4 bits,
		* resulting in a total pixelmap size of 4 * 300 * 216 = 259200 bits = a little less
		* than 32K.
		*/
		public function update( packet:CDGPacket ):void
		{	
			if( packet.command != 0x09 ) 
			{
				return;
			}
			
			var i:Number;
			var color:uint;
			switch( packet.instruction )
			{
				case CDGPacket.MEMORY_PRESET:
				{
					memoryBlock( packet );
					break;
				}
				case CDGPacket.BORDER_PRESET:
					// @TODO: IMPLEMENT
					break;
				case CDGPacket.TILE_BLOCK_NORMAL:
				{
					tileBlock( packet );
					break;
				}	
				case CDGPacket.SCROLL_PRESET:
					// @TODO: IMPLEMENT
					break;
				case CDGPacket.SCROLL_COPY:
					// @TODO: IMPLEMENT
					break;
				case CDGPacket.DEFINE_TRANSPARENT_COLOR:
				{
					_transparentColor = packet.data[0] & 0x0F;
				}
				break;
				case CDGPacket.LOAD_COLOR_TABLE_LOWER:
				{
					loadColorTable( packet, false );
					break;
				}
				break;
				case CDGPacket.LOAD_COLOR_TABLE_UPPER:
				{
					loadColorTable( packet, true );
					break;
				}
				case CDGPacket.TILE_BLOCK_XOR:
				{
					tileBlock( packet, true );
					break;
				}
				default:
				break;
			}
		}
		

		private function loadColorTable( packet:CDGPacket, upper:Boolean ):void
		{
			var offset:uint = upper ? 8 : 0;			
			var color:uint;	
			for( var i:uint=0; i<8; ++i )
			{
				color = makeColor( packet.data[2*i], packet.data[(2*i)+1] );
				_colorTable[offset+i] = color;
			}
		}

		private function memoryBlock( packet:CDGPacket ):void
		{
			/*
			typedef struct {
				char	color;				// Only lower 4 bits are used, mask with 0x0F
				char	repeat;				// Only lower 4 bits are used, mask with 0x0F
				char	filler[14];
			 } CDG_MemPreset;
			*/
			var colorIdx:uint = packet.data[0] & 0xF;
			_backgroundColor = colorIdx;
			
			var repeat:uint = packet.data[1] & 0xF;
			if (repeat != 0 ) return;
			
			var color:uint = getColor(colorIdx);
			
			var bd:BitmapData = bitmap.bitmapData;
			bd.fillRect( new Rectangle(0,0,300,216), color );
		}
				
		private function tileBlock( packet:CDGPacket, xor:Boolean=false ):void
		{
			/*
			typedef struct {
			char	color0;				// Only lower 4 bits are used, mask with 0x0F
			char	color1;				// Only lower 4 bits are used, mask with 0x0F
			char	row;				// Only lower 5 bits are used, mask with 0x1F
			char	column;				// Only lower 6 bits are used, mask with 0x3F
			char	tilePixels[12];		// Only lower 6 bits of each byte are used
			} CDG_Tile;
			*/

			var color0idx:uint = packet.data[0] & 0xF;
			var color1idx:uint = packet.data[1] & 0xF;
			var row:uint = packet.data[2] & 0x1F;
			var column:uint = packet.data[3] & 0x3F;
			
		
			var bd:BitmapData = bitmap.bitmapData;
			var color0:uint = getColor(color0idx);
			var color1:uint = getColor(color1idx);
				
			for (var i:Number=0; i<12; ++i)
			{
				var pixelOn:Boolean;
				var pixelData:uint;
				var x:Number;
				var y:Number;
				y = (row * 12) + i;
				pixelData = packet.data[ 4 + i ] & 0x3F;
				for (var j:Number=0; j<6; ++j)
				{
					x = (column * 6) + j;	
					pixelOn = ((pixelData >> (5-j)) & 0x1) == 0x1;
					if (xor)
					{
						var orgColorIdx:uint = getColorIndex( bd.getPixel32(x,y));
						var color:uint;
						color = getColor( pixelOn ? (orgColorIdx ^ color1idx) : (orgColorIdx ^ color0idx) );
						bd.setPixel32( x, y, color );
					}
					else
					{
						bd.setPixel32( x, y, pixelOn ? color1 : color0 );
					}
				}
			} 
		}
		
		protected function makeColor( high:uint, low:uint ):uint
		{
			var alpha:uint = 0xFF000000;
			var red:uint = ( (high>>2) & 0xF  ) * 16;
			var green:uint = ( ((high & 0x3) << 2) + ((low>>4) & 0x3) ) * 16;
			var blue:uint = ( low & 0xF ) * 16;
			
			var color:uint = alpha + (red<<16) + (green<<8) + blue;
			return color;
		}
		
		protected function getColor( index:uint ):uint
		{
			if (index == _transparentColor )
			{
				return 0x00000000;
			}
			if ( transparentBackground && index == _backgroundColor )
			{
				return 0x00000000;
			}
			return _colorTable[index];
		}
		
		public function getColorIndex( color:uint ):uint
		{
			for( var i:uint=0; i<16; ++i )
			{
				if (color == _colorTable[i])
					return i;
			}
			return 0;
		}
	}
}