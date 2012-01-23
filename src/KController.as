package
{
	import com.k_oke.*;
	
	import flash.data.*;
	import flash.desktop.NativeApplication;
	import flash.display.*;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.filesystem.*;
	import flash.filters.*;
	import flash.net.*;
	
	import mx.collections.ArrayCollection;
	import mx.collections.XMLListCollection;
	import mx.events.AIREvent;
	import mx.events.CollectionEvent;
	import mx.events.FlexEvent;
	
	import nz.co.codec.flexorm.*;
	import nz.co.codec.flexorm.criteria.Criteria;

	[Event(name="initComplete", type="flash.events.Event")]
	public final class KController extends EventDispatcher
	{
		private var globals:KGlobals;
		private var _player:KPlayer;
		public function KController(target:IEventDispatcher=null)
		{
			super(target);
			globals = KGlobals.globals;
			
			// Init database connections
			globals.songsDatabase = new KDatabase();
			globals.songsDatabase.addEventListener("databaseConnected", onDatabaseConnected);
			globals.singersDatabase = new KDatabase();
			globals.singersDatabase.addEventListener("databaseConnected", onDatabaseConnected);
			globals.queueDatabase = new KDatabase();
			globals.queueDatabase.addEventListener("databaseConnected", onDatabaseConnected);
			globals.adminDatabase = new KDatabase();
			globals.adminDatabase.addEventListener("databaseConnected", onDatabaseConnected);

			// Create windows
			globals.playerWindow = new KPlayerWindow();
			globals.controllerWindow = new KControllerWindow();
			globals.monitorWindow = new KMonitorWindow();
			globals.dashboardWindow = new KDashboardWindow();
			
			
			// Listen for the windows to be ready
			globals.playerWindow.addEventListener(FlexEvent.CREATION_COMPLETE,
				function( e:Event ):void
				{
					_player = globals.playerWindow.player;
					_player.addEventListener("songComplete", onSongComplete);
					dispatchEvent(e);
					globals.monitorWindow.player = _player;
				}
			);
			
			// Wait for windows to be created before laying them out.  Necessary to do initial fullscreen
			globals.playerWindow.addEventListener(AIREvent.WINDOW_COMPLETE, onWindowCreated );
			globals.monitorWindow.addEventListener(AIREvent.WINDOW_COMPLETE, onWindowCreated );
			globals.controllerWindow.addEventListener(AIREvent.WINDOW_COMPLETE, onWindowCreated );
			globals.dashboardWindow.addEventListener(AIREvent.WINDOW_COMPLETE, onWindowCreated );
			
			// Open all the windows
			globals.playerWindow.open();
			globals.monitorWindow.open(false);
			globals.controllerWindow.open();
			globals.dashboardWindow.open();
						
			NativeApplication.nativeApplication.addEventListener(Event.EXITING, onExiting);
		}
		
		
		public function play():void
		{
			if ( globals.nowPlaying )
			{
				// there is already a song, so keep playing
				_player.play();
			}
			else if ( globals.upNext )
			{
				var item:QueueItem = globals.upNext;
				globals.nowPlaying = item;
				var itemIndex:int = globals.queue.getItemIndex( item );
				globals.controller.removeQueueItemAt( itemIndex );
				
				refreshUpNext();
				
				var file:File = new File();
				file.url = globals.nowPlaying.song.filePath;					
				globals.controller.playZipFile( file );		
			}
			
		}
		public function pause():void
		{
			_player.pause();
		}
		
		private function onSongComplete(event:Event):void
		{
			trace("song is done!");
			
			// @TODO: move the played song to the History table
			
			globals.nowPlaying = null;
			
		}
		
		private var _initComplete:Boolean = false;
		public function onDatabaseConnected( event:Event ):void
		{
			if ( globals.songsDatabase.connected &&
				 globals.singersDatabase.connected &&
				 globals.queueDatabase.connected &&
				 globals.adminDatabase.connected )
			{
				setupEntityManagers();
				_initComplete = true;
				dispatchEvent( new Event("initComplete") );
			}
		}
		
		private var _em:EntityManager = EntityManager.instance;
		private var _emAsync:EntityManagerAsync = EntityManagerAsync.instance
		private var _emSqlConnection:SQLConnection;
		private var _emAsyncSqlConection:SQLConnection;
		public function setupEntityManagers():void
		{
			var dbFile:File = KDatabase.databaseFile;
			_emSqlConnection = new SQLConnection();
			_emSqlConnection.open(dbFile);
			_em.sqlConnection = _emSqlConnection;
			
			_emAsyncSqlConection = new SQLConnection();
			_emAsyncSqlConection.openAsync(dbFile);
			_emAsync.sqlConnection = _emAsyncSqlConection;
			
		}
		
		public function refreshSingers():void
		{
			globals.singers = _em.findAll( Singer );
			//globals.dashboardWindow.singer.dataProvider = singers;
			//globals.dashboardWindow.singersDataGrid.dataProvider = singers;
			var a1:ArrayCollection = globals.singers;	
			var a2:ArrayCollection = new ArrayCollection();
			for( var i:int=0; i<a1.length; ++i )
			{
				a2.addItem( a1.getItemAt(i) );
			}
			globals.dashboardWindow.singerAutoCompleteDataProvider = a2;
		}
		public function refreshQueue():void
		{
			var sortCriteria:Criteria = _em.createCriteria( QueueItem )
			sortCriteria = sortCriteria.addSort( "playOrder" );
			globals.queue = _em.fetchCriteria( sortCriteria );
			refreshUpNext();
		}
		public function refreshUpNext():void
		{
			if (globals.queue)
			{
				globals.upNext = QueueItem( globals.queue[0] );
			}
		}
		


		// When the Queue ArrayCollection is manipulated from UI (f.ex. drag'n'drop), 
		// this event listener should be connected.  It will make sure that the changes are
		// propagated down to the database.
		// Note that when *programmatically* manipulating the queue (addQueueItem(), etc),
		// it's important that this listener not be connected.
		public function onQueueCollectionChange( event:CollectionEvent ):void
		{
				trace("collectionChange event = "+event);
				switch( event.kind )
				{
					case "add":
						for( var i:int=0; i < event.items.length; ++i )
						{
							adjustQueuePlayOrderAfterAdd( event.items[i], event.location+i );
						}
						break;
					case "remove":
						// It's a little odd here.  We don't actually do removes, since FlexORM appears to
						// have difficulties with removes and re-adds.  Since we don't have a UI gesture to 
						// remove a queue item with d'n'd, that's OK.  It also works since the subsequent "add"
						// doesn't mind if the item is already in the DB.  FlexORM just updates the item, which is
						// exactly what we want.
						/*
						for( var i:int=0; i < event.items.length; ++i )
						{
							_em.remove( event.items[i] ); 
						}
						*/
						break;
				}
		}
		
				/*
			- insert
				* end
				* beginning
				* middle
		*/
		public function addQueueItem( item:QueueItem ):void
		{
			globals.queue.addItem( item );
			var newIndex:int = globals.queue.getItemIndex( item );
			adjustQueuePlayOrderAfterAdd( item, newIndex );
		}
		private function adjustQueuePlayOrderAfterAdd( item:QueueItem, addIndex:int ):void
		{
			var queue:ArrayCollection = globals.queue;
			// figure out the item's playOrder, by checking for a previous item (otherwise, it's just 0)
			var playOrder:int = 0;
			if ( addIndex > 0 )
			{
				var prevItem:QueueItem = QueueItem( queue.getItemAt(addIndex-1) );
				playOrder = prevItem.playOrder+1;
			}
			item.playOrder = playOrder;
			
			// after the add point, adjust up the play order for all items
			var newQueueLength:int = queue.length;
			for( var i:int=addIndex+1; i < newQueueLength; ++i )
			{
				var nextItem:QueueItem = QueueItem( queue.getItemAt(i) );
				nextItem.playOrder++; 
				_em.save( nextItem );
			}					
				
			// save the item
			_em.save( item );
		}
		
		public function addQueueItemAt( item:QueueItem, index:int ):void
		{
			item.playOrder = index;
			globals.queue.addItemAt( item, index );
			
			adjustQueuePlayOrderAfterAdd( item, index );
		}
		
		public function removeQueueItemAt( index:int ):void
		{
			var item:QueueItem = QueueItem( globals.queue.removeItemAt( index ) );
			if (!item)
				return;

			_em.remove( item );
		}
		
		public function buildTestQueue():void
		{
			var qi:QueueItem = new QueueItem;
			qi.singer = Singer( _em.loadItem( Singer, 1 ) );
			qi.song = Song( _em.loadItem( Song, 1 ) );
			addQueueItem( qi );
			
			qi = new QueueItem();
			qi.singer = Singer( _em.loadItem( Singer, 2 ) );
			qi.song = Song( _em.loadItem( Song, 3 ) );
			addQueueItem( qi );
		}
		
		public function saveSinger( singer:Singer ):void
		{
			_em.save( singer );
			if (!globals.singers.contains( singer ))
			{
				globals.singers.addItem( singer );
			}
			if (!globals.dashboardWindow.singerAutoCompleteDataProvider.contains( singer ) )
			{
				globals.dashboardWindow.singerAutoCompleteDataProvider.addItem( singer );
			}
		}
		public function deleteSinger( singer:Singer ):void
		{
			_em.remove( singer );
			var idx:int = globals.singers.getItemIndex(singer);
			if (idx > -1)
			{
				globals.singers.removeItemAt( idx );
			}
			
			var otherIdx:int = globals.dashboardWindow.singerAutoCompleteDataProvider.getItemIndex(singer);
			if (idx != otherIdx) throw new Error( "globals.singers out of sync with dashboardWindow.singerAutoCompleteDataProvider");
			if (otherIdx > -1)
			{
				globals.dashboardWindow.singerAutoCompleteDataProvider.removeItemAt( otherIdx );
			}
		}
		
		
		
		public override function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
		{
			super.addEventListener( type, listener, useCapture, priority, useWeakReference );
			
			// let late listeners also discover that we're init'd
			if ( _initComplete == true &&
				 type == "initComplete" )
			{
				dispatchEvent( new Event("initComplete") );
			}
		}
		public function onWindowCreated( event:Event ):void
		{
			if ( !globals.playerWindow.nativeWindow.closed &&
				 !globals.monitorWindow.nativeWindow.closed &&
				 !globals.controllerWindow.nativeWindow.closed &&
				 !globals.dashboardWindow.nativeWindow.closed )
			{
				layoutWindows();
			}
		}
		
		private function layoutWindows():void
		{
			//return;
			// Dorm Room Setup
			if (false)
			{
				// TODO: Implement
				// - just the playerWindow, really, but enable the in-window controls
				
				return;
			}
			
			// K-J Setup
			var ms:Screen = Screen.mainScreen;
			
			globals.playerWindow.nativeWindow.x = ms.visibleBounds.left;
			globals.playerWindow.nativeWindow.y = ms.visibleBounds.top;
			
			globals.controllerWindow.nativeWindow.x = ms.visibleBounds.left;
			globals.controllerWindow.nativeWindow.y = ms.visibleBounds.bottom - globals.controllerWindow.nativeWindow.height;
			
			globals.dashboardWindow.nativeWindow.x = ms.visibleBounds.right - globals.dashboardWindow.nativeWindow.width - 100;
			globals.dashboardWindow.nativeWindow.y = ms.visibleBounds.top + (ms.visibleBounds.height/2) - (globals.dashboardWindow.nativeWindow.height/2);
			
			globals.monitorWindow.nativeWindow.x = ms.visibleBounds.right - globals.monitorWindow.nativeWindow.width;
			globals.monitorWindow.nativeWindow.y = ms.visibleBounds.top;

			// K-J Setup, with multiple screens
			if( false && Screen.screens.length > 1 )
			{
					//if there is a second screen, place the CDG Window there
					
					// find, non-main screen
					var playerScreen:Screen;
					for each (var screen:Screen in Screen.screens)
					{
						if( screen != Screen.mainScreen)
						{
							playerScreen = screen;
							break;
						}
					}
					if (playerScreen)
					{					
						globals.playerWindow.nativeWindow.x = playerScreen.visibleBounds.left;
						globals.playerWindow.nativeWindow.y = playerScreen.visibleBounds.top;
						//and make full screen
						// TODO: clean up.  this will fail on async windowing systems.  damn linux.
						globals.playerWindow.goFullScreen();
					}
			}
			
			globals.playerWindow.visible = true;
			globals.monitorWindow.visible = false;
			globals.controllerWindow.visible = true;
			globals.dashboardWindow.visible = true;

		}
		
		private var _browseNewFile:File;
		public function browseNew():void
		{
			if ( _player == null ) return;

			_browseNewFile = new File();
			var filter:FileFilter = new FileFilter("Audio", "*.mp3");
			var filterZip:FileFilter = new FileFilter("Zip", "*.zip");
			_browseNewFile.browseForOpen("Select a song", [filter,filterZip]); 
			_browseNewFile.addEventListener(Event.SELECT, onBrowseNewSelect );
		}
		
		private function onBrowseNewSelect( event:Event ):void
		{
			if (_browseNewFile.exists && _browseNewFile.extension == "mp3")
			{
				throw new Error("Gotta browse to a zip file buddy");
				// strip the mp3; set it as the player root
				var plainName:String = _browseNewFile.name.substr( 0, _browseNewFile.name.length-4 );
				var rootPath:File = _browseNewFile.parent.resolvePath( plainName );
				_player.reset();
//				_player.rootPath = rootPath;
				_player.play();
			}
			if (_browseNewFile.exists && _browseNewFile.extension == "zip")
			{
				playZipFile( _browseNewFile );
			}	
		}
		
		public function playZipFile( file:File ):void
		{
			_player.reset();
	
			var zipFile:File = file;
			var unzip:KUnzip = new KUnzip();
			unzip.addEventListener( Event.COMPLETE, function( event:KUnzipEvent ):void
				{
					_player.kunzip = event.kunzip;
					_player.play();
				} );
			unzip.unzip( zipFile );
	
		}
		private var _exiting:Boolean = false;
		public function get exiting():Boolean { return _exiting; }
		private function onExiting( event:Event ):void
		{
			_exiting = true;
		}
			
		
		// TODO: move this whole thing to a test Model
		private var _testData:XMLListCollection;
		[Bindable]
		public function get testData():XMLListCollection
		{
			if (!_testData)
			{
				var testDataFile:File = new File();
				testDataFile.url = "app:/testData.xml";
				var fs:FileStream = new FileStream();
				
				fs.open( testDataFile, FileMode.READ );
				var x:XML = new XML( fs.readUTFBytes(fs.bytesAvailable) );
				_testData = new XMLListCollection( x.elements() );
			}
			return _testData;	
		}
		private function set testData(value:XMLListCollection):void
		{
			// nothing
		}
		
	}
}