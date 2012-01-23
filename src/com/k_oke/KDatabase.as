package com.k_oke
{
	import flash.data.*;
	import flash.errors.*;
	import flash.events.*;
	import flash.filesystem.*;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	
	import nz.co.codec.flexorm.*;
	import nz.co.codec.flexorm.command.*;
	import nz.co.codec.flexorm.criteria.*;

	[Event(name="addProgress", type="com.k_oke.KDatabaseEvent")]
	[Event(name="addComplete", type="com.k_oke.KDatabaseEvent")]
	[Event(name="addError", type="com.k_oke.KDatabaseEvent")]
	[Event(name="addWarning", type="com.k_oke.KDatabaseEvent")]
	[Event(name="databaseConnected", type="flash.events.Event")]
	
	/*
		* provide raw connection; sync or async; to client
		* create/dump tables
		* run through filesystem and populate Songs table
		* match songs
		* match singers
		* CRUD on SongQueue and SongHistory
		* CRUD on songs
		* CRUD on singers
		
		Definitely simpler if each KDatabase has a single SQLConnection (KDatabaseConnection?)
		But it's a pain to set up async connections. Ohh!  Multiple connections created at startup? Either in a single KDB, or thought multiple KDB instances...
		
		Consider the clients of this class:
			Songs Search Datagrid - just needs results
			Singer Search Component - mostly needs results, but also adds singers
			SongQueue Datagrid - just results
			Controller - add/remove from SongQueue and SongHistory; update with ratings, etc.
			
		Design: multiple KDatabase instances, each by convention restricted to an area (admin, song, singer, queue).  Create them all at start up; don't even tell
			components about that shit until they're all ready, by having KController dispatch "initComplete". Add special code to KController dispatcher logic so that
			late listeners get an event, even though the controller was ready before the client called addEventListener()
			
	*/
	public class KDatabase extends EventDispatcher
	{
		public function KDatabase(target:IEventDispatcher=null)
		{
			super(target);
			initialize();
			
			_em = EntityManager.instance;
			_emAsync = EntityManagerAsync.instance;
		}
		
		protected static const s_dbPath:String = "k-oke.db";
		protected static var s_dbFile:File = File.applicationStorageDirectory.resolvePath(s_dbPath);

		private var _em:EntityManager;
		private var _emAsync:EntityManagerAsync;

		private var _conn:SQLConnection;
		private var _stmt:SQLStatement;
		private var _savedStatementText:String = null;
		private var _savedNumResults:Number = -1;
		private var _savedStatementSummary:String = null;
		
		private function initialize():void
		{
			bootstrapDatabase();
			
			_conn = createConnectionAsync();
			_conn.addEventListener( flash.events.SQLEvent.OPEN, onConnectionOpen );
		}
		
		public static function createConnection():SQLConnection
		{
			var conn:SQLConnection = new SQLConnection();
			conn.open( s_dbFile );
			return conn;
		}
		public static function createConnectionAsync():SQLConnection
		{
			var conn:SQLConnection = new SQLConnection();
			conn.openAsync( s_dbFile );
			return conn;
		}		
		public static function get databaseFile():File { return s_dbFile; }
		
		private var _connected:Boolean = false;
		public function onConnectionOpen( event:SQLEvent ):void
		{
			_stmt = new SQLStatement();
			_stmt.sqlConnection = _conn;
			_stmt.addEventListener(SQLEvent.RESULT, onSQLResult);
			_stmt.addEventListener(SQLErrorEvent.ERROR, onSQLError);
			_connected = true;
			dispatchEvent( new Event("databaseConnected") );
		}
		
		public function get connected():Boolean { return _connected; }
		
		// @REMOVE
		private function createTables():void
		{
			return;
			var stmt:SQLStatement = new SQLStatement();
			stmt.sqlConnection = createConnection();
			
			stmt.text = "CREATE TABLE IF NOT EXISTS" +
				" SONGS (SONG_ID INTEGER PRIMARY KEY AUTOINCREMENT, SONG_NAME TEXT, SONG_ARTIST TEXT, " +
				" QPID TEXT, SONG_FILE_PATH TEXT UNIQUE, SONG_FILE_NAME TEXT ); ";
			stmt.execute();
			stmt.text = "CREATE INDEX IF NOT EXISTS" +
				" SONG_INDEX ON SONGS (SONG_NAME, SONG_ARTIST); "
			stmt.execute(); 	
			stmt.text = "CREATE TABLE IF NOT EXISTS" +
				" SINGERS (SINGER_ID INTEGER PRIMARY KEY AUTOINCREMENT, USERID TEXT, " +
				" FIRST_NAME TEXT, LAST_NAME TEXT, EMAIL TEXT, PHONE TEXT ); ";
			stmt.execute();
			stmt.text = "CREATE TABLE IF NOT EXISTS" +
				" SONGQUEUE ( " +
				"SONGQUEUE_ID INTEGER PRIMARY KEY AUTOINCREMENT, "+
				"SONG_ID INTEGER NOT NULL," +  /* Key */
				"SINGER_ID INTEGER NOT NULL, " + /* Key */
				"TRANSPOSE INTEGER NOT NULL DEFAULT 0," +
				"TIME_ADDED DATE NOT NULL);";
			stmt.execute();
			stmt.text = "CREATE TABLE IF NOT EXISTS" +
				" SONGHISTORY ( " +
				"SONGHISTORY_ID INTEGER PRIMARY KEY AUTOINCREMENT, "+
				"SONG_ID INTEGER NOT NULL, "+ /* Key */
				"SINGER_ID INTEGER NOT NULL, "+ /* Key */
				"TRANSPOSE INTEGER, " +
				"TIME_SUNG DATE NOT NULL, "+
				"RATING INTEGER );";
			stmt.execute();

						
		}
		
		// @REMOVE
		public function dropAllTables():void
		{
			dropSingerRelatedTables();

			var stmt:SQLStatement = new SQLStatement();
			stmt.sqlConnection = createConnection();
			stmt.text = "DROP INDEX SONG_INDEX;"; 
			stmt.execute();
			stmt.text = "DROP TABLE SONGS;"
			stmt.execute(); 	
		}
		
		// @REMOVE
		private function dropSingerRelatedTables():void
		{
			var stmt:SQLStatement = new SQLStatement();
			stmt.sqlConnection = createConnection();
			
			stmt.text = "DROP TABLE SONGQUEUE;"
			stmt.execute();
			stmt.text = "DROP TABLE SONGHISTORY;"
			stmt.execute();
			stmt.text = "DROP TABLE SINGERS;"
			stmt.execute();
		}
		private function bootstrapDatabase():void
		{
			if (!s_dbFile.exists)
			{
				// first, check for seed file in app: directory
				var packagedFile:File = File.applicationDirectory.resolvePath( s_dbPath );
				if (packagedFile.exists)
				{
					packagedFile.copyTo( s_dbFile );
					return;
				}
			}
		}
		
		private var _qpidRegexp:RegExp = /[A-Z]{1,4}\d{1,4}-\d{1,4}/i;
		private var _digitRegexp:RegExp = /\d+/;
		/**
		 * @returns an object with... null if the filename could not be parsed
		 */
		private function _parseFilenameForAdd( file:File ):Song
		{
			// Split the filename to the best of our ability
			if ( file.extension != null && 
				(file.extension.toLowerCase() == "mp3" ||
				 file.extension.toLowerCase() == "zip"))
			{
				var isZip:Boolean = (file.extension.toLowerCase() == "zip");
				var artist:String;
				var songName:String;
				var qpid:String;
				var success:Boolean = false;
				var noext:String = file.name.slice(0, -(1+file.extension.length));
				var chunks:Array = noext.split(" - ");
				
				var result:Song = new Song();
				if (chunks.length == 2)
				{
					result.artist = chunks[0];
					result.name = chunks[1];
					result.qpid = String(0);
					success = true;
				}
				else if (chunks.length == 3)
				{			
					
					
					var qpidIdx:Number = -1;
					if (_qpidRegexp.test( chunks[0] ))
						qpidIdx = 0;
					else if (_qpidRegexp.test( chunks[2] ))
						qpidIdx = 2;
					else if (_digitRegexp.test( chunks[0] ))
						qpidIdx = 0;
					else if (_digitRegexp.test( chunks[0] ))
						qpidIdx = 2;
					
					if (qpidIdx != -1)
					{
						// default ZIP: <artist> - <songName> - <qpid>.zip 
						result.artist = chunks[(qpidIdx+1)%3];
						result.name = chunks[(qpidIdx+2)%3];
						result.qpid = chunks[qpidIdx%3];			
				
						success = true;
					}
				}
				if (success) return result;				
			}
			return null;			
		}
		
		private var _testAddFileOrDirectory:Boolean = false;
		private var _rootDirectoryForAdd:File;
		
		private var _addDirectories:Vector.<File> = new Vector.<File>;
		private var _added:Number;
		private var _completed:Number;
		
		public function addFileAsync( file:File ):void
		{
			var v:Vector.<File> = new Vector.<File>;
			v.push( file );
			addFilesAsync( v );
		}
		
		public function addFilesAsync( files:Vector.<File> ):void
		{
			_added = _completed = 0;
			_addFilesAsync( files );
		}
		
		private static const _MAX_FILE_CHUNK:Number = 200;
		private var _deferredFileChunkTimer:Timer;
		
		private function _addFilesAsync( files:Vector.<File> ):void
		{
			// create a connection and iterate through the files
			var conn:SQLConnection = createConnection();
			try {
				conn.begin();
				
				var file:File;
				var fileCount:Number = 0;
				while ( files.length > 0 )
				{
					file = files.pop();
					
					if (!file.exists) continue;
			
					++fileCount;
					
					// directories get queued for later
					if (file.isDirectory)
					{
						_addDirectories.push( file );
						++_added;
						dispatchEvent( new KDatabaseEvent("addProgress", _added, _completed, file.url));
					}			
					// files get inserted
					else
					{
						_insertFile(file, conn);
					}
					
					// chunk it up; if the directory is too big, defer the rest for 20 ms
					if ( fileCount > _MAX_FILE_CHUNK )
					{
						break;
					}
				}
				conn.commit();
				conn.close();
			}
			catch( e:Error )
			{
				if (conn.inTransaction) conn.cancel();
				dispatchEvent( new KDatabaseEvent( KDatabaseEvent.ADD_WARNING, _added, _completed, e.toString()) );
			}
			if (files.length > 0)
			{
				if (_deferredFileChunkTimer == null )
					_deferredFileChunkTimer = new Timer( 20, 1 );
				var t:Timer = _deferredFileChunkTimer;
				var that:KDatabase = this;
				var listener:Function = function( event:TimerEvent ):void
					{
						t.removeEventListener(TimerEvent.TIMER_COMPLETE, listener);
						that._addFilesAsync( files );
					};
				t.addEventListener(TimerEvent.TIMER_COMPLETE, listener);
				t.start();
				return;
			}
			
			
			// if no more directories, we're done
			if ( _added == 0 )
			{
				dispatchEvent( new KDatabaseEvent("addComplete", _added, _completed) );
				return;
			}
			
			// start the next async directory listing
			if (_addDirectories.length > 0)
			{
				var nextDir:File = File( _addDirectories.pop() );
				nextDir.addEventListener( FileListEvent.DIRECTORY_LISTING, _onAddDirectoryListing );
				nextDir.getDirectoryListingAsync();
			}
		}
		
		private function _onAddDirectoryListing( event:FileListEvent ):void
		{
			_addFilesAsync( Vector.<File>( event.files ) );
			++_completed;
			dispatchEvent( new KDatabaseEvent("addProgress", _added, _completed ));
			if (_added == _completed )
			{
				dispatchEvent( new KDatabaseEvent("addComplete", _added, _completed) );
			}
		}
	
		private function _insertFile( file:File, conn:SQLConnection ):void
		{
			var song:Song = _parseFilenameForAdd(file);
			if (song == null)
			{
				// For now, let's just raise it up for someone else to log
				// 
				var event:KDatabaseEvent = new KDatabaseEvent(KDatabaseEvent.ADD_WARNING, _added, _completed, file.url);
				dispatchEvent(event);					
			}
			else
			{
				song.filePath = file.url;
				song.fileName = file.name;
				_em.save(song);
				/*
				try
				{
					var stmt:SQLStatement = new SQLStatement();
					stmt.sqlConnection = conn;
					// add to the database
					stmt.text = "INSERT INTO SONGS (SONG_NAME, SONG_ARTIST, QPID, SONG_FILE_PATH, SONG_FILE_NAME)"+
					" VALUES (@NAME, @ARTIST, @QPID, @PATH, @FILENAME);";
					stmt.parameters["@NAME"] = songInfo.songName;
					stmt.parameters["@ARTIST"] = songInfo.artist;
					stmt.parameters["@QPID"] = songInfo.qpid;
					stmt.parameters["@PATH"] = file.url;
					stmt.parameters["@FILENAME"] = file.name;
					stmt.execute();
				}
				catch( e:SQLError )
				{
					// todo: ensure it's because of the path uniqueness
					trace("addFileOrDirectory: ignoring file - "+file.url);
				}
				*/
			}			
		}
		
		public static const MATCH_SONGS:String = "MATCH_SONGS";
		public static const MATCH_SINGERS:String = "MATCH_SINGERS";
		private function generateMatchQuery( queryName:String, searchValue:String ):String
		{
			var resultString:String = null;
			switch(queryName)
			{
				case MATCH_SONGS:
					resultString = "SELECT song_name AS title, song_artist AS artist, qpid as qpick, song_file_path as filepath, song_file_name as filename, song_id from songs WHERE "
					var trimmer:RegExp = new RegExp(" *(.*) *");
					var strings:Array = searchValue.split(",");
					var s:String;
					for each (var q:String in strings)
					{
						s  = trimmer.exec( q )[1];
						// TODO: validate string to prevent sql injection
						if ( s.length > 0 )
						{
							if (q != strings[0])
							{
								resultString += " AND ";
							}
							resultString += "(song_name LIKE \"%" +s+ "%\" OR song_artist LIKE \"%" +s+ "%\")";
						}
					}				
				break;
	
				
				default:
				break;
			}
			
			if (resultString == null)
				throw new Error("Bad Match Query. query="+queryName+", searchValue="+searchValue);
				
			return resultString;
		}
	

		
		public function match( queryName:String, searchValue:String, numResults:Number ):void
		{
			// Start creating an async connection, if we don't yet have one
			if (!_conn || !_conn.connected || !_stmt)
				throw new Error("Barf. calling match() on bogus connection");
				//_conn = createConnectionAsync();
				
			trace("Cancelling previous match()");	
			_stmt.cancel();
			
			var queryText:String = generateMatchQuery( MATCH_SONGS, searchValue );
			
			_stmt.text = queryText;
			_stmt.execute(numResults);
		}
		
		public function getResultData():Array
		{
			var result:Array = null;
			try {
				result = _stmt.getResult().data;
			}
			catch( e:Error )
			{
				// swallow it
			}
			return result;
		}
		
		public function findSingers():ArrayCollection
		{
			var singers:ArrayCollection = _em.findAll( Singer );
			return singers;
		}
		
		public function cancelMatch():void
		{
			trace("cancelMatch() cancelling previous match");
			_stmt.cancel();
		}
		private function onSQLResult( event:SQLEvent ):void
		{
			trace("SQL Result!");
			dispatchEvent( event );
		}
		
		private function onSQLError( event:SQLErrorEvent ):void
		{
			trace("SQL Error.errorID = " + event.errorID +" : " +event.error );
			
			if ( event.errorID == 3118 )
			{
				if (_savedStatementText != null)
				{
					trace("\texecuting saved statment: "+_savedStatementSummary);
					_stmt.text = _savedStatementText;
					_stmt.execute( _savedNumResults );
					_savedStatementText = null;
					_savedNumResults = -1;
				}
			}
			else
			{
				dispatchEvent( event );
			}	
		}
		//
		// TEST STUFF
		//
		public function testFileParsing():void
		{
			var sampleFiles:Array =[
				["EKI01-07 - Christina Aquilera - Hurt.zip", "Christina Aquilera", "Hurt", "EKI01-07"],
				["Duran Duran - Hungry Like The Wolf.zip", "Duran Duran", "Hungry Like The Wolf", "0"],
				["Utfo - Roxanne Roxanne - Sc8656-03.zip", "Utfo", "Roxanne Roxanne", "Sc8656-03"],
				[ "Wreck Of The Edmond Fitzgerald - Sc8467-01 Lightfoot, Gordon.zip", "Lightfoot, Gordon", "Wreck Of The Edmond Fitzgerald", "Sc8467-01"],
				["They Might Be Giants - Birdhouse In Your Soul - Pi042-09.zip", "They Might Be Giants", "Birdhouse In Your Soul", "Pi042-09"],
				["Misfits, The - Devils Whorehouse - 11.zip", "Misfits, The", "Devils Whorehouse", "11"],
				["SC8532-03 - Prince & Revolution - Darling Nikki.mp3", "Prince & Revolution", "Darling Nikki", "SC8532-03"],
				];
				
			for each( var fileMap:Array in sampleFiles )
			{
				var file:File = File.applicationStorageDirectory.resolvePath(fileMap[0]);
				var songInfo:Object = _parseFilenameForAdd(file);
				if (!songInfo)
				{
					trace("NO SONGINFO!!"); continue;
				}
				if (
					songInfo.artist == fileMap[1] && 
					songInfo.songName == fileMap[2] &&
					songInfo.qpid == fileMap[3] )
				{
					// success!!
				}
				else
				{
					trace("ERROR! -- " + fileMap[0]);
					trace("\t\""+songInfo.artist+"\" should be \""+fileMap[1] +"\"");
					trace("\t\""+songInfo.songName+"\" should be \""+fileMap[2]+"\"");
					trace("\t\""+songInfo.qpid+"\" should be \""+fileMap[3]+"\"");
				}
			}
		}
		


		
		public function buildSongsFromSampleFile():void
		{
			// Read in the sample text file.  
			var seedFile:File = File.applicationDirectory.resolvePath("Unique_by_Song.txt");
			var fs:FileStream = new FileStream();
			fs.open( seedFile, FileMode.READ );
			var seedString:String = fs.readUTFBytes( fs.bytesAvailable );
			
			//var stmt:SQLStatement = new SQLStatement();
			//stmt.sqlConnection = createConnection();
			//stmt.sqlConnection.begin();
			
			// Each line has format "<songname>"%"<artist>"\r\n , complete with quotes
			// Split into lines, then rip out the strings
			var lines:Array = seedString.split("\r\n");
			_em.startTransaction();
			for each (var line:String in lines)
			{
				var tuple:Array = line.split("\"%\"");
				var name:String = String(tuple[0]).slice(1);
				var artist:String = String(tuple[1]).slice(0,-1);
				trace( name +" - "+artist);
				
				var song:Song = new Song();
				song.artist = artist;
				song.name = name;
				_em.save( song );
				// add to the database
				//stmt.text = "INSERT INTO SONGS (SONG_NAME, SONG_ARTIST) VALUES (@NAME, @ARTIST);";
				//stmt.parameters["@NAME"] = name;
				//stmt.parameters["@ARTIST"] = artist;
				//stmt.execute();
			}
			_em.endTransaction();
			//stmt.sqlConnection.commit();
		}
		
		public function generateSingersAndQueue():void
		{
			
		}
	}
}