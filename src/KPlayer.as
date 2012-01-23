package
{
	import com.k_oke.*;
	
	import flash.display.*;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.events.SampleDataEvent;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.media.Camera;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	import flash.net.URLRequest;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	import mx.controls.VideoDisplay;
	import mx.core.UIComponent;
	import mx.events.ResizeEvent;
	
	public class KPlayer extends UIComponent
	{
		public function KPlayer()
		{
			super();
			init();
		}
		
		protected override function commitProperties():void
		{
			trace("commitProperties");
		}
		/*
		public function set rootPath( file:File ):void
		{
			_rootPath = file;
			_mp3Path = _rootPath.parent.resolvePath( _rootPath.name + ".mp3" );
			_cdgPath = _rootPath.parent.resolvePath( _rootPath.name + ".cdg" );
		}
		public function get rootPath():File { return _rootPath }
		*/
		public function set mp3Path( file:File ):void { _mp3Path = file; }
		public function get mp3Path():File { return _mp3Path; }
		
		public function set cdgPath( file:File ):void { _cdgPath = file; }
		public function get cdgPath():File { return _cdgPath; }
		
		public function set kunzip( obj:KUnzip ):void
		{
			_rootPath = _mp3Path = cdgPath = null;
			_kunzip = obj;
			mp3Path = _kunzip.mp3Path;
			cdgPath = _kunzip.cdgPath;
		}
		
		public function set videoPath( file:File ):void { _videoPath = file; }
		public function get videoPath():File { return _videoPath; }
		
		public function set videoCamera( camera:Camera ):void { _camera = camera; }
		public function get videoCamera():Camera { return _camera; }
		
		public function set transparentBackground( value:Boolean ):void { _cdgDisplay.transparentBackground = value; }
		public function get transparentBackground():Boolean { return _cdgDisplay.transparentBackground; }
		
		public function set displayVideo( value:Boolean ):void { _displayVideo = value; }
		public function get displayVideo():Boolean { return _displayVideo; }
		
		public function get cdgBitmapData():BitmapData { return _cdgDisplay.cdgBitmapData; }
		
		private var _paused:Boolean = false;
		private var _playing:Boolean = false;

		[Bindable]
		public function get paused():Boolean { return _paused; }
		protected function set paused(value:Boolean):void { _paused = value; }
		
		[Bindable]
		public function get playing():Boolean { return _playing; }
		protected function set playing(value:Boolean):void { _playing = value; }
		
		private var _kunzip:KUnzip;
		private var _rootPath:File;
		private var _mp3Path:File;
		private var _cdgPath:File;
		private var _videoPath:File;
		private var _camera:Camera;
		private var _displayVideo:Boolean = false;
		
		private var _cdgDisplay:CDGDisplay;
		private var _playbackSound:Sound;
		private var _playbackSoundChannel:SoundChannel;
		private var _bufferedSong:Sound;
		private var _samples:ByteArray;
		private var _cdgTimer:Timer;
		private var _cdgFileStream:FileStream;

		private var _background:VideoDisplay;

		[Bindable]
		public var soundChannelPosition:Number;
		
		[Bindable]
		public var bufferedSoundPosition:Number;
		
		[Bindable]
		public var cdgPosition:Number;
		private var _packetCount:Number;
		
		
		private const PLAYBACK_BUFFER_SIZE:Number = 8096 ;// 4048;

		public function init():void
		
		{
			_samples = new ByteArray();
			_samples.length = PLAYBACK_BUFFER_SIZE;

			_bufferedSong = new Sound();
			
			_playbackSound = new Sound();
			_playbackSoundChannel = null;

			_cdgDisplay = new CDGDisplay();
			addChild( _cdgDisplay );
			
			_background = new VideoDisplay();
			_background.width = _cdgDisplay.width;
			_background.height = _cdgDisplay.height;
			addChildAt( _background, 0 );
			
			deferredCompletionTimer.addEventListener(TimerEvent.TIMER, onDeferredCompletionTimer);
			
			addEventListener(ResizeEvent.RESIZE, onResize);
			reset();
		}


		protected function onResize( event:ResizeEvent ):void
		{
			trace("resize: "+event.toString()+"\n");
			_cdgDisplay.width = _background.width = width;
			_cdgDisplay.height = _background.height = height;
		}
		public function reset():void
		{
			// @ TODO: clean this up.  it's a total hack.
			stop();
			_cdgDisplay.reset();
			_packetCount = 0;
			bufferedSoundPosition = 0;
			
			if (_kunzip && _kunzip.valid) _kunzip.clear();
			_kunzip = null; 
			mp3Path = cdgPath = null;
		}
		
		public function play():void
		{
			if ( paused )
			{
				resume();
				return;
			}
			
			// Start loading the MP3 file to play.
			// The rest of setup will happen when the song is buffered in memory
			// @TODO: using File/FileStream APIs instead, we could avoid loading the whole
			// MP3 in memory....
			_bufferedSong = new Sound();
			_bufferedSong.addEventListener(Event.COMPLETE, onBufferedSongComplete);
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
			
			paused = false;
			playing = true;
		}

		public function stop():void
		{
			try {
				_cdgTimer.stop();
				_cdgFileStream.close();
				_playbackSoundChannel.stop();
				soundChannelPosition = 0;
				
				paused = false;
				playing = false;
				
			}
			catch( e:Error )
			{
				trace( "Exception on stop: "+ e.toString() );
			}
		}
		
		public function pause():void
		{
			try {
				if ( playing )
				{
					if( _cdgTimer.running && soundChannelPosition > 0 )
					{
						_cdgTimer.stop();
						_playbackSoundChannel.stop();
						playing = false;
						paused = true;
					}
				}
			}
			catch( e:Error )
			{
				trace( "Exception on pause: "+ e.toString() );
			}
		}

		public function resume():void
		{
			if (!paused || soundChannelPosition == 0 ) throw new Error("resume: not paused");
			
			// When we resume, use bufferedSoundPosition, which track how much sample data
			// we've provided to the playbackSoundChannel.  Otherwise, the unplayed part of the 
			// last sample we provided doesn't get counted.
			// The result is that _playbackSoundChannel.position lags increasingly behind the real sound.
			_playbackSoundChannel = _playbackSound.play( bufferedSoundPosition / 44.1);	
			_cdgTimer.start();
			
			paused = false;
			playing = true;
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
			
			if (displayVideo)
			{
				if (_videoPath)
				{
				_background.source = _videoPath.url;
				_background.volume = 0;
				_background.play();
				}
				else if (_camera)
				{
					_background.volume = 0;
					_background.attachCamera( _camera );
				}
			}
		}
		

		public function readPacket( position:Number = -1):void
		{
			var packetBytes:ByteArray = new ByteArray();
			do {
					try {
						var bytesAvailable:Number = _cdgFileStream.bytesAvailable;
					} catch( e:Error )
					{
						trace("KPlayer.readPacket(): not enough data to read yet...");
						break;
					}
					
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
					//throw new Error("KPlayer.readPacket(): not enough CDG data fetched!");
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
			var position:Number = _playbackSoundChannel.position;
			readPacket( position );
			readPacket();
			readPacket();
			readPacket();
		}

		private var deferredCompletionTimer:Timer = new Timer(10, 1);
		private function onDeferredCompletionTimer( event:TimerEvent ):void
		{
			deferredCompletionTimer.stop();
			stop();
			dispatchEvent( new Event("songComplete") );
		}
		public function bufferedSongSampleDataHandler( event:flash.events.SampleDataEvent ):void
		{
			
			if (_playbackSoundChannel != null)
			{
				soundChannelPosition = _playbackSoundChannel.position;
			}
				
			_samples.position = 0;
			var len:Number = _bufferedSong.extract( _samples, PLAYBACK_BUFFER_SIZE );
			if (len == 0 )
			{
				// we're out of sound.  stop playback and let the world know that the song is over.
				// note that we can't just call stop here, as that'll cause a player crash!
				deferredCompletionTimer.reset();
				deferredCompletionTimer.start();				
			}
			/*
			if (len<PLAYBACK_BUFFER_SIZE)
			{
				// restart at beginning
				//bufferedSoundPosition = 0;
				//len += _bufferedSong.extract( _samples, PLAYBACK_BUFFER_SIZE-len, 0 );
				//bufferedSoundPosition = PLAYBACK_BUFFER_SIZE-len;
				
				// Flag song as done
			}*/
			
			else
			{
				bufferedSoundPosition += len;
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