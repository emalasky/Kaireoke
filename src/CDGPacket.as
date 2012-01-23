package
{
	import flash.utils.ByteArray;
	
	public class CDGPacket extends Object
	{
		/*
		typedef struct {
 	    char	command;
  		char	instruction;
  		char	parityQ[2];
  		char	data[16];
  		char	parityP[4];
		} SubCode;
		*/
			
		private var _command:Number;
		private var _instruction:Number;
		private var _parityQ0:Number;
		private var _parityQ1:Number;
		private var _data:ByteArray;
		private var _parityP0:Number;
		private var _parityP1:Number;
		private var _parityP2:Number;
		private var _parityP3:Number;

		/** Size of a subcode packet */
		public static const SUBCODE_PACKET_SIZE:Number = 24;

		/** Set the screen to a particular color. */
		public static const MEMORY_PRESET:Number = 1;  

   		/** Set the border of the screen to a particular color. */
   		public static const BORDER_PRESET:Number = 2;

   		/**	Load a 12 x 6, 2 color tile and display it normally. */
   		public static const TILE_BLOCK_NORMAL:Number = 6;
   		
   		/** Scroll the image, filling in the new area with a color. */
   		public static const SCROLL_PRESET:Number = 20;

   		/** Scroll the image, rotating the bits back around. */
   		public static const SCROLL_COPY:Number = 24;

		/** Define a specific color as being transparent. */
		public static const DEFINE_TRANSPARENT_COLOR:Number = 28;

   		/** Load in the lower 8 entries of the color table. */
		public static const LOAD_COLOR_TABLE_LOWER:Number = 30;
		 
   		/** Load in the upper 8 entries of the color table. */
		public static const LOAD_COLOR_TABLE_UPPER:Number = 31;

   		/** Load a 12 x 6, 2 color tile and display it using the XOR method. */
   		public static const TILE_BLOCK_XOR:Number = 38;

		public function CDGPacket( bytes:ByteArray )
		{
			super();
			parsePacket( bytes );
		}
		
		private function parsePacket( bytes:ByteArray ):void
		{
			var pos:Number = bytes.position;
			_command = bytes.readUnsignedByte() & 0x3F; 
			_instruction = bytes.readUnsignedByte() & 0x3F; 
			_parityQ0 = bytes.readUnsignedByte();
			_parityQ1 = bytes.readUnsignedByte();
			_data = new ByteArray();
			_data.position = 0;
			for (var c:uint = 0; c< 16; ++c)
			{
				_data.writeByte( bytes.readUnsignedByte() );	
			}
			_parityP0 = bytes.readUnsignedByte();
			_parityP1 = bytes.readUnsignedByte();
			_parityP2 = bytes.readUnsignedByte();
			_parityP3 = bytes.readUnsignedByte();
		}
		
		public function get command():Number
		{
			return _command;
		}
		
		public function get instruction():Number
		{
			return _instruction;
		}
		
		public function get data():ByteArray
		{
			return _data;
		}
		private static var _packetCount:Number = 0;
		public function toString():String
		{
			var out:String = new String("Packet #"+_packetCount++ + " - " + Number(_packetCount/300).toPrecision(4) + " secs" + "\n");
			out += "\tcommand = 0x"+_command.toString(16)+"\n";
			out += "\tinstruction = 0x"+_instruction.toString(16)+"\n";
			out += "\tdata = ";
			for (var i:Number=0; i<16; ++i)
			{
				out += "0x"+Number(data[0]).toString(16)+" ";
			}
			out += "\n";
			out += "\tParityQ = 0x"+_parityQ0.toString(16)+" 0x"+_parityQ1.toString(16)+"\n";
			out += "\tParityP = 0x"+_parityP0.toString(16)+" 0x"+_parityP1.toString(16)+" 0x"+_parityP2.toString(16)+" 0x"+_parityP3.toString(16)+"\n";
			out += "\n";
			return out;
		}
	}
}