package
{
	import com.k_oke.KDatabase;
	import com.k_oke.QueueItem;
	
	import flash.filesystem.File;
	
	import mx.collections.ArrayCollection;
	
	public final class KGlobals
	{
		public function KGlobals()
		{
			if (_instance) throw ("KGlobals is a singleton!! Use KGlobals.globals instead.");
			_instance = this;
		}
		
		private static var _instance:KGlobals;
		public static function get globals():KGlobals
		{
			if (_instance==null)
			{
				_instance = new KGlobals();
			}
			return _instance;
		}

		


		public var rootPath:File;
		
		[Bindable]
		public var controllerWindow:KControllerWindow;
	
		[Bindable]
		public var playerWindow:KPlayerWindow;
		
		[Bindable]
		public var dashboardWindow:KDashboardWindow;
		
		[Bindable]
		public var monitorWindow:KMonitorWindow;
		
		[Bindable]
		public var controller:KController;
		
		
		[Bindable]
		public var queue:ArrayCollection = new ArrayCollection();
		[Bindable]
		public var singers:ArrayCollection = new ArrayCollection();
	
		[Bindable]
		public var nowPlaying:QueueItem = null;

		[Bindable]
		public var upNext:QueueItem = null;			

		public var songsDatabase:KDatabase;
		public var singersDatabase:KDatabase;
		public var queueDatabase:KDatabase;
		public var adminDatabase:KDatabase;
		
	}
}