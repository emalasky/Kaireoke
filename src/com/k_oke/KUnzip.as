package com.k_oke
{
	import __AS3__.vec.Vector;
	
	import deng.fzip.*;
	
	import flash.errors.IOError;
	import flash.events.ErrorEvent;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.OutputProgressEvent;
	import flash.events.ProgressEvent;
	import flash.filesystem.File;
	import flash.filesystem.FileMode;
	import flash.filesystem.FileStream;
	import flash.net.URLRequest;
	
	public class KUnzip extends EventDispatcher
	{
		private static var _unzips:Vector.<KUnzip> = new Vector.<KUnzip>();
		
		public function KUnzip(target:IEventDispatcher=null)
		{
			super(target);
		}
		
		public var mp3Path:File = null;
		public var cdgPath:File = null;
		
		private var _mp3Written:Boolean = false;
		private var _cdgWritten:Boolean = false;
		private var _parseComplete:Boolean = false;
		
		private var fzip:FZip;
		private var outputDir:File;
		public function unzip( file:File ):void
		{
			if (!file.exists) throw new Error("File does not exist");
			if (file.extension != "zip") throw new Error("File is not named .zip");
			
			_unzips.push(this);

			var rootPath:File = KUtilities.stripExtension(file, ["zip"]);
			outputDir = File.createTempDirectory().resolvePath( rootPath.name );			

			fzip = new FZip();	
			fzip.addEventListener(FZipEvent.FILE_LOADED, onFileLoaded);
			fzip.addEventListener(FZipErrorEvent.PARSE_ERROR, onParseError);
			fzip.addEventListener(ProgressEvent.PROGRESS, onProgress);
			fzip.addEventListener(Event.COMPLETE, onComplete);
			fzip.load( new URLRequest( file.url ) );
			
		}
		
		private function onFileLoaded( event:FZipEvent ):void
		{
			trace("onFileLoaded: " + event.file.filename  + " datalength="+event.file.content.length+ 
			" bytesavailable="+event.file.content.bytesAvailable);
			var fzfile:FZipFile = event.file;
			
			var baseName:File = KUtilities.stripExtension( File.applicationDirectory.resolvePath( fzfile.filename ), ["mp3", "cdg"]);
			if (!baseName) throw new ErrorEvent("KUnzip invalid zipped file", false, false, "Invalid zipped file name: "+fzfile.filename );
			
			// Start asynchronously writing the file out 
			var fileStream:FileStream = new FileStream();
			var outputFile:File = outputDir.resolvePath( fzfile.filename );
			fileStream.openAsync( outputFile, FileMode.WRITE ); 
			// Listen for the write to complete
			var unzip:KUnzip = this;
			fileStream.addEventListener(OutputProgressEvent.OUTPUT_PROGRESS, function ( event:OutputProgressEvent ):void
				{
					// Ignore real progress; wait for completion
					if (event.bytesPending != 0 ) return;
					
					if ( outputFile.extension == "mp3" )
					{
						mp3Path = outputFile;
						_mp3Written = true;
					}
					if ( outputFile.extension == "cdg" )
					{
						cdgPath = outputFile;
						_cdgWritten = true;
					}	
					// Close the file before telling anyone. Important because concurrent access
					// is fragile on win32
					fileStream.close();
					unzip._checkForCompletion();								
				}
			);
			fileStream.addEventListener(ProgressEvent.PROGRESS, onProgress );
			fileStream.addEventListener(IOErrorEvent.IO_ERROR, onIOErrorEvent );
			fileStream.writeBytes( fzfile.content );
		}
		
		// Coordinate the completion of three asynchronous events. We want to know that
		//  - FZip has finished breaking the zip file into pieces
		//  - mp3 has been completely written to temp dir
		//  - cdg has been completely written to temp dir
		private function _checkForCompletion():void
		{
			if (_mp3Written && _cdgWritten && _parseComplete)
			{
				var newEvent:KUnzipEvent;
				newEvent = new KUnzipEvent(Event.COMPLETE, this);
				dispatchEvent( newEvent );				
			}
		}
		
		private function onParseError( event:FZipEvent ):void
		{
			trace("parse error...");
		}
		private function onComplete( event:Event ):void
		{
			_parseComplete = true;
			trace("complete...");
			_checkForCompletion();
		}
		public function onProgress( event:ProgressEvent ):void
		{
			trace("progress...");
		}
		public function onIOErrorEvent( event:IOError ):void
		{
			trace("ioerror...");
		}
		
		public function clear():void
		{
			if (outputDir && outputDir.exists)
			{
				trace("KUnzip DELETE : " +outputDir.url+"\n");	
				outputDir.deleteDirectory(true);
			}
			fzip = null;
		}
		
		public function get valid():Boolean
		{
			return ( cdgPath && cdgPath.exists && mp3Path && mp3Path.exists );
		}
	}
}