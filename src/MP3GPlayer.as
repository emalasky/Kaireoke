package
{
	import flash.display.Sprite;
	import flash.events.ProgressEvent;
	import flash.events.SampleDataEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;

	public class MP3GPlayer extends Sprite
	{
		public function MP3GPlayer()
		{
			super();
			init();
		}
		
		public function set rootPath( file:File ):void
		{
			_rootPath = file;
			_mp3Path = _rootPath.parent.resolvePath( _rootPath.name + ".mp3" );
			_cdgPath = _rootPath.parent.resolvePath( _rootPath.name + ".cdg" );
		}
		public function get rootPath():File { return _rootPath }
		
		public function set mp3Path( file:File ):void { _mp3Path = file; }
		public function get mp3Path():File { return _mp3Path; }
		
		public function set cdgPath( file:File ):void { _cdgPath = file; }
		public function get cdgPath():File { return _cdgPath; }
		
		private var _rootPath:File;
		private var _mp3Path:File;
		private var _cdgPath:File;

		private var _cdgDisplay:CDGDisplay;
		private var _playbackSound:Sound;
		private var _playbackSoundChannel:SoundChannel;
		private var _bufferedSong:Sound;
		private var _samples:ByteArray;
		private var _cdgTimer:Timer;
		private var _cdgFileStream:FileStream;


		[Bindable]
		public var soundChannelPosition:Number;
		
		[Bindable]
		public var cdgPosition:Number;
		private var _packetCount:Number;
		
		
		private const PLAYBACK_BUFFER_SIZE:Number = 4048;

		public function init():void
		
		{
			_samples = new ByteArray();
			_samples.length = PLAYBACK_BUFFER_SIZE;

			_packetCount = 0;

			_bufferedSong = new Sound();
			_bufferedSong.addEventListener(Event.COMPLETE, onBufferedSongComplete);
			
			_playbackSound = new Sound();
			_playbackSoundChannel = null;

			_cdgDisplay = new CDGDisplay();
			addChild( _cdgDisplay );
		}


		public function play():void
		{
			// Start loading the MP3 file to play.
			// The rest of setup will happen when the song is buffered in memory
			// @TODO: using File/FileStream APIs instead, we could avoid loading the whole
			// MP3 in memory....
			_bufferedSong.load( new URLRequest(_mp3Path.url) );

			// Read the whole CDG file
			var cdgFile:File = File.applicationDirectory.resolvePath(_cdgPath.url);
			_cdgFileStream = new FileStream();
			_cdgFileStream.addEventListener( ProgressEvent.PROGRESS, onCDGProgress );
			_cdgFileStream.addEventListener( Event.COMPLETE, onCDGComplete );
			
			// Setup timer that mimic reading CD sectors.
			// Doesn't have to be 100% exact; CDG will sync against the audio being played back.
			// Timer gets started later....
			_cdgTimer = new Timer( 13.33333333334 );  // Read Sector 75X per second
			_cdgTimer.addEventListener(TimerEvent.TIMER, onCDGSectorTimer );
		}

		public function stop():void
		{
			try {
				_cdgTimer.stop();
				_cdgFileStream.close();
				_playbackSoundChannel.stop();
				soundChannelPosition = 0;
			}
			catch( e:Error )
			{
				trace( "Exception on stop: "+ e.toString() );
			}
		}
		
		public function pause():String
		{
			var labelText:String = 'pause';
			try {
				if( _cdgTimer.running && soundChannelPosition > 0 )
				{
					_cdgTimer.stop();
					_playbackSoundChannel.stop();
					
					labelText = 'continue';
				}
				else if( soundChannelPosition > 0 )
				{
					_playbackSoundChannel = _playbackSound.play( soundChannelPosition );	
					_cdgTimer.start();
				}
			}
			catch( e:Error )
			{
				trace( "Exception on pause: "+ e.toString() );
			}
			return labelText;
		}
		
		public function reset():void
		{
			// @ TODO: clean this up.  it's a total hack.
			stop();
			_bufferedSong.removeEventListener(Event.COMPLETE, onBufferedSongComplete);
			_cdgDisplay.clear();
			init();
		}
		
		/**
		 * Once the mp3 has been loaded into memory, we can begin playing.
		 */
		public function onBufferedSongComplete( event:Event ):void
		{
			// Start the mixed playback sound; we feed the data on-demand
			_playbackSound.addEventListener( "sampleData", bufferedSongSampleDataHandler );
			_playbackSoundChannel = _playbackSound.play();	

			// start reading the CDG file
			_cdgFileStream.openAsync( _cdgPath, FileMode.READ );

			// Start the CDG timer, which fires once per "sector".
			// This timer drives the CDG rendering
			_cdgTimer.start();
		}
		

		public function readPacket( position:Number = -1):void
		{
			var packetBytes:ByteArray = new ByteArray();
			do {
				if( _cdgFileStream.bytesAvailable >= CDGPacket.SUBCODE_PACKET_SIZE )
				{
					// If we were given a position to match, keep going until we catch up.
					// If CDG is *ahead* of the MP3, this check will prevent us from reading the packet
					// in the first place
					if (position != -1 && cdgPosition > position ) break;

					// Read the next packet
					packetBytes.position = 0;
					_cdgFileStream.readBytes( packetBytes, 0, CDGPacket.SUBCODE_PACKET_SIZE );
				
					// Parse it and display it
					var cdgPacket:CDGPacket = new CDGPacket( packetBytes );
					_cdgDisplay.update( cdgPacket );
					
					// Update our count of packets read, which implies our position according
					// to CDG
					_packetCount++;
					cdgPosition = _packetCount*1000/300;
				}
				else
				{
					// Not enough data has been buffered by FileStream; need to suck it up and wait
					break;
				}
				
				// If we weren't given a position to match, then return after reading one packet
				if (position == -1 ) break;
				
			} while (1);
		}
		
		public function onCDGProgress( event:ProgressEvent ):void
		{
			// do nothing
		}			
		public function onCDGComplete( event:Event ):void
		{
			// do nothing
		}
		
		public function onCDGSectorTimer( event:TimerEvent ):void
		{
			// Read four (4) packets from each "sector" of the "CD"
			var position:Number = _playbackSoundChannel.position
			readPacket( position );
			readPacket();
			readPacket();
			readPacket();
		}

		public function bufferedSongSampleDataHandler( event:flash.events.SampleDataEvent ):void
		{
			
			if (_playbackSoundChannel != null)
			{
				soundChannelPosition = _playbackSoundChannel.position;
			}
				
			_samples.position = 0;
			var len:Number = _bufferedSong.extract( _samples, PLAYBACK_BUFFER_SIZE );
			if (len<PLAYBACK_BUFFER_SIZE)
			{
				// restart at beginning
				len += _bufferedSong.extract( _samples, PLAYBACK_BUFFER_SIZE-len, 0 );
			}
			
			// Copy int sampleData buffer
			_samples.position = 0;
			for ( var c:int=0; c < len; c++ ) {
		 	   var left:Number = _samples.readFloat();
			   var right:Number = _samples.readFloat();
			   event.data.writeFloat( left);
			   event.data.writeFloat(right);
			}		
			
		}	
	}
}