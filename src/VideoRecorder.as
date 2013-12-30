package
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.MouseEvent;
	import flash.events.NetStatusEvent;
	import flash.events.StatusEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.media.Camera;
	import flash.media.Microphone;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	import flash.system.Security;
	import flash.system.SecurityPanel;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	
	public class VideoRecorder extends Sprite
	{
		private var FMS_URL:String = "rtmp://infspylvf0nx4.rtmphost.com/hdfvr/";
		
		private var player:Boolean = true;
		
		private var mirror:Boolean = false;
		private var debug:Boolean = false;
		private var recordtime:Number = 0;
		
		private var quality:Number = 70;//90;
		private var filename:String = "";
		
		
		private var recordtimer:Timer;
		
		private var video:Video;
		private var cam:Camera;
		private var mic:Microphone;
		
		private var nc:NetConnection;
		private var ns:NetStream;
		
		private var isQ:Boolean = false;
		private var startDate:Date;
		private var countDownBar:Sprite;
		private var countDownTrack:Sprite;
		
		public function VideoRecorder()
		{
			stage.scaleMode = StageScaleMode.NO_SCALE;
			stage.align = StageAlign.TOP_LEFT;
			
			////////////////////////////
			
			var debugvar:String = stage.loaderInfo.parameters["debug"];
			if(debugvar == null){
				debug = false;
			}else{
				if(debugvar == 'true'){
					debug = true; 
				}else{
					debug = false;
				}
			}
			
			var playervar:String = stage.loaderInfo.parameters["player"];
			if(playervar == null){
				player = false;
			}else{
				if(playervar == 'true'){
					player = true; 
				}else{
					player = false;
				}
			}
			
			var mirrorvar:String = stage.loaderInfo.parameters["mirror"];
			if(mirrorvar == null){
				mirror = false;
			}else{
				if(mirrorvar == 'true'){
					mirror = true; 
				}else{
					mirror = false;
				}
			}
			
			var recordtimevar:String = stage.loaderInfo.parameters["recordtime"];
			if(recordtimevar == null){
				recordtime = 0;
			}else{
				recordtime = Number(recordtimevar)*1000;
			}
			
			var qualityvar:String = stage.loaderInfo.parameters["quality"];
			if(qualityvar != null){
				quality = Number(qualityvar);
			}
			
			var filenamevar:String = stage.loaderInfo.parameters["filename"];
			if(filenamevar != null){
				filename = filenamevar;
			}else{
				var d:Date = new Date();
				filename = 'recording'+d.getTime() + '_' + Math.round(Math.random()*1000) + '.f4v'; 
			}
			
			var fmsvar:String = stage.loaderInfo.parameters["fms"];
			if(fmsvar != null){
				FMS_URL = fmsvar;
			}
			
			////////////////////////////
			
			recordtimer = new Timer(recordtime);
			recordtimer.addEventListener(TimerEvent.TIMER, stopRecording);
			
			initCamera();
			
			initConnection();
			
			initDebug();
			
			initExternalInterface();
			
			if(isQ){
				initQ();
			}
		}
		
		private function initExternalInterface():void{
			if(ExternalInterface.available){
				ExternalInterface.addCallback('startRecording', startRecording);
				ExternalInterface.addCallback('stopRecording', stopRecording);
				ExternalInterface.addCallback('getFilename', getFilename);
				
				ExternalInterface.addCallback('hasWebcam', hasWebcam);
				ExternalInterface.addCallback('isWebCamMuted', isWebCamMuted);
				
				ExternalInterface.addCallback('startPlaying', startPlaying);
				ExternalInterface.addCallback('stopPlaying', stopPlaying);
				
				
			}
		}
		
		private function isWebCamMuted():Boolean{
			// TODO Auto Generated method stub
			return cam.muted;
		}
		
		private function getFilename():void{
			trace("filename = " + filename);
			ExternalInterface.call('showRecorderFilename', filename);
		}
		
		private function hasWebcam():Boolean{			
			if (Camera.names.length > 0) {
				return true;	
			}
			return false;
		}
		
		private function outputExternalInterface(str:String):void{
			if(ExternalInterface.available){
				ExternalInterface.call('recorderStatus', str);
			}
		}
		
		private function initCamera():void{
			if(player){
				return;	
			}

			cam = Camera.getCamera();
			cam.addEventListener(StatusEvent.STATUS, statusHandler);
			cam.setMode(640,480, 15);
			
			if(cam.muted){
				Security.showSettings(SecurityPanel.PRIVACY)
			}
			
			
			
			mic = Microphone.getMicrophone();
			mic.setSilenceLevel(0);
			mic.rate = 22
			
			cam.setQuality(0, quality);
			video = new Video(cam.width,cam.height);
			video.name = "recordervideo";
			
			addChild(video);
			
			var perc:Number = stage.stageWidth / video.width;
			video.scaleX = video.scaleY = perc;
			video.y = Math.round(stage.stageHeight / 2 -  video.height / 2); 
			
			if(mirror){
				video.scaleX = -video.scaleX;
				video.x = stage.stageWidth;
			}
		}
		
		private function statusHandler(event:StatusEvent):void{
			if (cam.muted){
				trace("User clicked Deny.");
			}
			else{
				trace("User clicked Accept.");
			}
		}
		
		private function initConnection():void{
			nc = new NetConnection();
			nc.addEventListener(NetStatusEvent.NET_STATUS, onNcStatus);
			nc.connect(FMS_URL);
		}
		
		private function initNetStream():void{
			ns = new NetStream(nc);
			ns.bufferTime = 5;
			ns.addEventListener(NetStatusEvent.NET_STATUS, onNsStatus);
			
			var client:Object = new Object();
			client.onMetaData = function(data:Object):void{
				video = new Video(data.width, data.height);
				video.attachNetStream(ns);
				addChild(video);
				
				var perc:Number = stage.stageWidth / data.width;
				video.scaleX = video.scaleY = perc;
				video.y = Math.round(stage.stageHeight / 2 -  video.height / 2); 
				
				if(mirror){
					video.scaleX = -video.scaleX;
					video.x = stage.stageWidth;
				}
				
			};
			ns.client = client;
			
			if(player){
				//video.attachNetStream(ns);
			}else{
				video.attachCamera(cam);
				
				ns.attachAudio(mic);
				ns.attachCamera(cam);
			}
		}
		
		private function onNcStatus(e:NetStatusEvent):void{
			trace(e.info.code);
			if(e.info.code == "NetConnection.Connect.Success"){
				initNetStream();
			}
		}
		
		private function onNsStatus(e:NetStatusEvent):void{
			if(debug){
				outputExternalInterface(e.info.code);
			}
			trace(e.info.code);
			if(e.info.code == 'NetStream.Video.DimensionChange'){
				
				var vw:Number = video.videoWidth;
				var vh:Number = video.videoHeight;
				
				removeChild(video);
				video.attachNetStream(null);
				video = null;
				
				video = new Video(vw, vh);
				video.attachNetStream(ns);
				addChild(video);
				
				var perc:Number = stage.stageWidth / vw;
				video.scaleX = video.scaleY = perc;
				video.y = Math.round(stage.stageHeight / 2 -  video.height / 2); 
				
				if(mirror){
					video.scaleX = -video.scaleX;
					video.x = stage.stageWidth;
				}
				
				
			}
			if(e.info.code == "NetStream.Buffer.Empty"){
				outputExternalInterface("play.stop");
			}
		}
		
		private function startRecording(e:MouseEvent = null):void{
			if(player || cam.muted){
				return;
			}
			
			trace( " cam.muted = " + cam.muted)
			
			if(video.name != "recordervideo"){
				removeChild(video);
				video.attachNetStream(null);
				video.attachCamera(null);
				
				video = new Video(cam.width,cam.height);
				video.name = "recordervideo";
				
				addChild(video);
				
				var perc:Number = stage.stageWidth / video.width;
				video.scaleX = video.scaleY = perc;
				video.y = Math.round(stage.stageHeight / 2 -  video.height / 2); 
				
				if(mirror){
					video.scaleX = -video.scaleX;
					video.x = stage.stageWidth;
				}
				
				video.attachCamera(cam);
				ns.attachCamera(cam);
			}
			
			ns.publish("mp4:"+filename, "record");
			outputExternalInterface("record.start");
			
			if(isQ){
				countDownBar.scaleX = 0;
				addChild(countDownTrack);
				addChild(countDownBar);
			}
			
			if(recordtime != 0){
				recordtimer.start();
				startDate = new Date();
			}
			
			saveSnapshot();
		}
		private function stopRecording(e:Event = null):void{
			if(player){
				return;
			}
			ns.close();
			recordtimer.stop();
			outputExternalInterface("record.stop");
		}
		
		private function startPlaying():void{
			
			ns.play("mp4:"+filename);
			outputExternalInterface("play.start");
			
			
		}
		private function stopPlaying():void{
			ns.close();
			outputExternalInterface("play.stop");
		}
		
		private function initDebug():void{
			if(!debug){
				return;
			}
			var startRec:Sprite = new Sprite();
			startRec.graphics.beginFill(0x00ff00);
			startRec.graphics.drawRect(0,0,20,20);
			startRec.buttonMode = true;
			startRec.addEventListener(MouseEvent.CLICK, startRecording);
			addChild(startRec);
			
			var stopRec:Sprite = new Sprite();
			stopRec.graphics.beginFill(0x00ff00);
			stopRec.graphics.drawRect(0,0,20,20);
			stopRec.buttonMode = true;
			stopRec.addEventListener(MouseEvent.CLICK, stopRecording);
			stopRec.x = 25;
			addChild(stopRec);
		}
		
		private function initQ():void{
			//#F70E13
			
			countDownTrack = new Sprite();
			countDownTrack.graphics.beginFill(0xffffff);
			countDownTrack.graphics.drawRect(0,0,stage.stageWidth, 2);
			countDownTrack.y = stage.stageHeight - countDownTrack.height;
			addChild(countDownTrack);
			
			countDownBar = new Sprite();
			countDownBar.graphics.beginFill(0xF70E13);
			countDownBar.graphics.drawRect(0,0,stage.stageWidth, 2);
			countDownBar.y = stage.stageHeight - countDownBar.height;
			countDownBar.scaleX = 0;
			countDownBar.addEventListener(Event.ENTER_FRAME, onCountDownRender);
			addChild(countDownBar);
		}
		
		private function onCountDownRender(e:Event):void{
			if(recordtimer.running){
				var now:Date = new Date();
				var ms:Number = now.getTime() - startDate.getTime()
				countDownBar.scaleX =  (ms / recordtime);
			}
		}
		
		private function saveSnapshot():void {
			var bd:BitmapData = new BitmapData(video.width, video.height, false, 0);
			bd.draw(video);
			var bitmap:Bitmap = new Bitmap(bd);
		
			PNGEncoder2.level = CompressionLevel.FAST; // Optional. Defaults to FAST
			
			var encoder:PNGEncoder2 = PNGEncoder2.encodeAsync(bd);
			
			encoder.addEventListener(Event.COMPLETE, function(e:Event):void {
				var png:ByteArray = encoder.png;
				uploadByteArray(png);
			});
			
		}


		private function uploadByteArray(png:ByteArray):void {
			trace(filename);
			var request:URLRequest = new URLRequest("https://beta.creativecomments.cc/en/api/video-still?video=" + filename );
			request.contentType = 'application/octet-stream';
			request.method = URLRequestMethod.POST;
			
			request.data = png;
			
			var urlLoader:URLLoader = new URLLoader();
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, errorHandler);
			urlLoader.addEventListener(Event.COMPLETE, completeHandler);
			urlLoader.load(request);
		}
		
		
		private function completeHandler(event:Event):void {
			trace(event.toString());
		}
		
		private function errorHandler(event:IOErrorEvent):void {
			trace(event.toString());
		}
	}
}