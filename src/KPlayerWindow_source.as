// ActionScript file
import flash.display.StageDisplayState;
import flash.events.KeyboardEvent;
import flash.ui.Keyboard;

protected function onCreationComplete():void
{
	root.addEventListener( KeyboardEvent.KEY_DOWN, onKeyDown );
}

protected function onKeyDown( event:KeyboardEvent ):void
{
	if ( event.ctrlKey && event.charCode == Keyboard.ENTER )
		toggleFullScreen();
	if ( event.charCode == Keyboard.SPACE )
	{		
		
//		quickAddShow.yFrom = 200;
//	 	quickAddShow.yTo = this.height - quickAddCanvas.height;
//	 	quickAddShow.repeatCount = 1;
//	 	quickAddShow.play( [quickAddCanvas] );
		if (!quickAddCanvas.visible)
		{
			searchInput.setFocus();
		}
		quickAddCanvas.visible = !quickAddCanvas.visible;
	}
}

private function requireOpenWindow():void
{
	if (!nativeWindow || nativeWindow.closed || !visible)
		throw new Error("Player Window not open");
}
protected function toggleFullScreen():void
{
	requireOpenWindow();
	
	var ds:String = stage.displayState;
	
	if (ds == StageDisplayState.FULL_SCREEN ||
		ds == StageDisplayState.FULL_SCREEN_INTERACTIVE )
		stage.displayState = StageDisplayState.NORMAL;
	else
		stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
}

public function goFullScreen():void
{
	requireOpenWindow();
	stage.displayState = StageDisplayState.FULL_SCREEN_INTERACTIVE;
}

public function goNormalSize():void
{
	requireOpenWindow();
	stage.stageWidth = 300;
	stage.stageHeight = 216;
}
public function goDoubleSize():void
{
	requireOpenWindow();
	stage.stageWidth = 600;
	stage.stageHeight = 432;
}
protected function slideQuickAddCanvas( current:Number, start:Number, amount:Number, duration:Number ):Number
{
	if ( amount == 0 ) return start;
	
	var result:Number = int( quickAddCanvas.parent.height - start - ( amount * current / duration ) ); 
	trace ( "[current, start, amount, duration = ["+current+", "+start+", "+start+", "+amount+", "+duration+"] = "+result+"\n");
	return result;
}