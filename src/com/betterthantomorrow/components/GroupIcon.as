package com.betterthantomorrow.components {
	import com.betterthantomorrow.utils.AvatarUtils;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.CapsStyle;
	import flash.display.LineScaleMode;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.display.PixelSnapping;
	import flash.display.Shape;
	import flash.events.Event;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.URLRequest;
	import flash.utils.Dictionary;
	
	import mx.collections.ArrayCollection;
	import mx.controls.Image;
	import mx.core.FlexGlobals;
	import mx.core.UIComponent;
	import mx.events.CollectionEvent;
	import mx.events.CollectionEventKind;
	import mx.styles.CSSStyleDeclaration;
	
	import spark.components.BorderContainer;
	
	[Style(name="mainIconPercentSize", type="Number", inherit="yes")]
	[Style(name="showGridlines", type="Boolean", inherit="yes")]
	[Style(name="gridlinesWeight", type="Number", format="Length", inherit="yes")]
	[Style(name="gridlinesPrecentWeight", type="Number", inherit="yes")]
	[Style(name="gridlinesColor", type="Number", format="Color", inherit="yes")]
	[Style(name="gridlinesAlpha", type="Number", inherit="yes")]
	
	public class GroupIcon extends BorderContainer {
		private static const DEFAULT_MAIN_ICON_PERCENT_SIZE:Number = 45;
		
		private static const DEFAULT_MAX_AVATARS:Number = 100;
		private static const DEFAULT_SHOW_GRIDLINES:Boolean = false;
		private static const DEFAULT_GRIDLINES_WEIGHT:Number = 2;
		private static const DEFAULT_GRIDLINES_PERCENT_WEIGHT:Number = 0;
		private static const DEFAULT_GRIDLINES_COLOR:Number = 0x7f7f7f;
		private static const DEFAULT_GRIDLINES_ALPHA:Number = 1.0;

		public function GroupIcon() {
			super();
		}

		private static var classConstructed:Boolean = classConstruct();
		private static function classConstruct():Boolean {
			if (!FlexGlobals.topLevelApplication.styleManager.getStyleDeclaration("com.betterthantomorrow.components.GroupIcon")) {
				var myStyles:CSSStyleDeclaration = new CSSStyleDeclaration();
				myStyles.defaultFactory = function():void {
					this.mainIconPercentSize = DEFAULT_MAIN_ICON_PERCENT_SIZE;
					this.showGridlines = DEFAULT_SHOW_GRIDLINES;
					this.gridlinesWeight = DEFAULT_GRIDLINES_WEIGHT;
					this.gridlinesPrecentWeight = DEFAULT_GRIDLINES_PERCENT_WEIGHT;
					this.gridlinesColor = DEFAULT_GRIDLINES_COLOR;
					this.gridlinesAlpha = DEFAULT_GRIDLINES_ALPHA;
				}
				FlexGlobals.topLevelApplication.styleManager.setStyleDeclaration("com.betterthantomorrow.components.GroupIcon", myStyles, true);
			}
			return true;
		}
		
		[Bindable] private var _mainIconURL:String = new String();
		private var _mainIcon:Image;
		[Bindable] private var _avatarItems:ArrayCollection;
		private static var _loadedAvatars:Dictionary = new Dictionary();
		private var _croppedAvatars:Dictionary;
		private var _resultImage:Image;
		private var _resultMask:UIComponent;
		private var _avatarSize:Number;
		private var _maxAvatars:uint = DEFAULT_MAX_AVATARS;
		private var _avatarSizeBleed:Number;
		private var _mainIconSize:Number;
		private var _oldWidth:Number;
		
		public function set mainIconURL(v:String):void {
			if (_mainIconURL != v) {
				_mainIconURL = v;
				prepareFullRedraw();
				var loader:Loader = new Loader();
				loader.contentLoaderInfo.addEventListener(Event.COMPLETE,
					function oc(e:Event):void {
						loader.removeEventListener(Event.COMPLETE, oc);
						var li:LoaderInfo = e.currentTarget as LoaderInfo;
						_mainIcon = new Image();
						_mainIcon.smoothBitmapContent = true;
						_mainIcon.source = li.content;
						_mainIcon.width = li.content.width;
						_mainIcon.height = li.content.height;
						fullRedraw();
					});
				loader.load(new URLRequest(_mainIconURL));
			}
		}

		private function loadAvatar(avatarItem:IGroupIconItem):void {
			var loader:Loader = new Loader();
			loader.contentLoaderInfo.addEventListener(Event.COMPLETE,
				function oc(e:Event):void {
					loader.removeEventListener(Event.COMPLETE, oc);
					var li:LoaderInfo = e.currentTarget as LoaderInfo;
					if (!(avatarItem.avatarURL in _loadedAvatars)) {
						_loadedAvatars[avatarItem.avatarURL] = li.content as Bitmap;
						_loadedAvatars[avatarItem.avatarURL].smoothing = true;
					}
					fullRedraw();
				});
			loader.load(new URLRequest(avatarItem.avatarURL));
		}

		private function loadAvatars():void {
			prepareFullRedraw();
			for each (var avatarItem:IGroupIconItem in _avatarItems) {
				if (!(avatarItem.avatarURL in _loadedAvatars)) {
					loadAvatar(avatarItem);
				}
				else {
					fullRedraw();
				}
			}
		}

		public function set avatars(v:ArrayCollection):void {
			if (_avatarItems != v) {
				_avatarItems = v;
				_avatarItems.addEventListener(CollectionEvent.COLLECTION_CHANGE,
					function avatarsUpdated(event:CollectionEvent):void {
						var c:ArrayCollection = event.currentTarget as ArrayCollection;
						if (event.kind != CollectionEventKind.RESET) {
							loadAvatars();
						}
					});
				loadAvatars();
			}
		}
		
		private function prepareFullRedraw():void {
			measure();
			_croppedAvatars = new Dictionary();
			_resultImage = createResultImage();
			_resultMask = createMask();
			_resultImage.mask = _resultMask;
		}

		private function fullRedraw():void {
			var numLoaded:int = 0;
			for each (var item:IGroupIconItem in _avatarItems) {
				if (item.avatarURL in _loadedAvatars) {
					numLoaded++;
					if (!(item.avatarURL in _croppedAvatars)) {
						var avatarImage:Image = new Image();
						//avatarImage.addChild(crop(cropping.x, cropping.y, _avatarSize, _avatarSize, _loadedAvatars[item.avatarURL]));
						avatarImage.addChild(AvatarUtils.squareCrop(_loadedAvatars[item.avatarURL], _avatarSize));
						_croppedAvatars[item.avatarURL] = avatarImage;	
						_resultImage.addChild(avatarImage);
					}
				}
			}
			if (numLoaded > 0) {
				placeAvatars();
			}
			addMainIcon(_resultImage);
			removeAllElements();
			addElement(_resultImage);
			addElement(_resultMask);
		}

		public function set maxAvatars(v:uint):void {
			if (v != _maxAvatars) {
				_maxAvatars = v;
				prepareFullRedraw();
				fullRedraw();
			}
		}

		private function createResultImage():Image {
			var resultImage:Image = new Image();
			resultImage.width = width;
			resultImage.height = height;
			resultImage.x = -_borderWeight - _avatarSizeBleed / 2;
			resultImage.y = -_borderWeight - _avatarSizeBleed / 2;
			return resultImage;
		}
		
		override protected function measure():void {
			var w:Number = width;
			if (_mainIcon != null) {
				_mainIconSize = w * getStyle("mainIconPercentSize") / 100;
			}
			if (_numAvatars > 0) {
				if (_numAvatars < 3) {
					_avatarSize = Math.ceil(w / _numAvatars);
					_avatarSizeBleed = _avatarSize * _numAvatars - width;
				}
				else {
					for each (var c:uint in [2, 3, 4, 5, 6, 7, 8, 9, 10]) {
						if (_numAvatars < Math.pow(c + 1, 2) || _maxAvatars < Math.pow(c + 1, 2)) {
							_avatarSize = Math.ceil(w / c);
							_avatarSizeBleed = _avatarSize * c - width;
							break;
						}
					}
				}
			}
		}

		override public function set width(v:Number):void {
			if (v != _oldWidth) {
				_oldWidth = width;
				super.width = v;
				super.height = v;
				prepareFullRedraw();
				fullRedraw();
			}
		}
		
		private function get _borderWeight():Number {
			return getStyle("borderVisible") && !isNaN(getStyle("borderWeight")) ? getStyle("borderWeight") : 0;
		}

		private function get _cornerRadius():Number {
			return !isNaN(getStyle("cornerRadius")) ? getStyle("cornerRadius") : 0;
		}

		private function get _showGridlines():Boolean {
			return getStyle("showGridlines");
		}
		
		private function get _gridlinesPercentWeight():Number {
			return _showGridlines && !isNaN(getStyle("gridlinesPercentWeight")) ? getStyle("gridlinePercentsWeight") : DEFAULT_GRIDLINES_PERCENT_WEIGHT;
		}

		private function get _gridlinesWeight():Number {
			if (_gridlinesPercentWeight > 0) {
				return _gridlinesPercentWeight * width;
			}
			else {
				return _showGridlines && !isNaN(getStyle("gridlinesWeight")) ? getStyle("gridlinesWeight") : DEFAULT_GRIDLINES_WEIGHT;
			}
		}
		
		private function get _gridlinesColor():Number {
			return _showGridlines && !isNaN(getStyle("gridlinesColor")) ? getStyle("gridlinesColor") : DEFAULT_GRIDLINES_COLOR;
		}
		
		private function get _gridlinesAlpha():Number {
			return _showGridlines && !isNaN(getStyle("gridlinesAlpha")) ? getStyle("gridlinesAlpha") : DEFAULT_GRIDLINES_ALPHA;
		}
		
		private function get _numAvatars():uint {
			return _avatarItems != null ? _avatarItems.length : 0;
		}

		private function createMask():UIComponent {
			var maskShape:UIComponent = new UIComponent();
			maskShape.graphics.beginFill(0xff0000);
			maskShape.graphics.drawRoundRect(-0.5, -0.5,
				width - _borderWeight * 2 + 1, height - _borderWeight * 2 + 1,
				_cornerRadius * 2);
			maskShape.graphics.endFill();
			maskShape.visible = false;
			return maskShape;
		}

		private function addMainIcon(resultImage:Image):void {
			if (_mainIcon != null) {
				resultImage.addChild(_mainIcon);
			}
			placeMainIcon();
		}
		
		private function drawGridCross(grid:Image, _x:Number, _y:Number):void {
			grid.graphics.moveTo(_x, 0);
			grid.graphics.lineTo(_x, grid.height);
			grid.graphics.moveTo(0, _y);
			grid.graphics.lineTo(grid.width, _y);			
		}

		private function placeAvatars():void {
			var numAvatars:int = _numAvatars;
			var _avatars:Array = new Array();
			for each (var item:IGroupIconItem in _avatarItems) {
				if (item.avatarURL in _croppedAvatars) {
					_avatars.push(_croppedAvatars[item.avatarURL]);
				}
			}
			if (_avatars != null && _avatars.length > 1) {
				var grid:Image = new Image();
				grid.width = _resultImage.width;
				grid.height = _resultImage.height;
				grid.graphics.lineStyle(_gridlinesWeight, _gridlinesColor, _gridlinesAlpha, false, LineScaleMode.NORMAL, CapsStyle.NONE);
				var i:int;
				if (_numAvatars == 2 && _avatars.length > 1) {
					_avatars[0].x = _avatarSize;
					_avatars[1].y = _avatarSize;
				}
				else {
					for each (var c:uint in [2, 3, 4, 5, 6, 7, 8, 9, 10]) {
						if (numAvatars < Math.pow(c + 1, 2) || _maxAvatars < Math.pow(c + 1, 2)) {
							for (i = 0; i < c * c && i < _avatars.length; i++) {
								_avatars[i].x = (i % c) * _avatarSize;
								_avatars[i].y = Math.floor(i / c) * _avatarSize;
							}
							if (_showGridlines) {
								for (var g:int = 1; g < c; g++) {
									drawGridCross(grid, _avatarSize * g, _avatarSize * g);
								}
							}
							break;
						}
					}
				}
				if (_showGridlines) {
					_resultImage.addChild(grid);
				}
			}
		}
		
		private function placeMainIcon():void {
			if (_mainIcon != null) {
				_mainIcon.width = _mainIconSize;
				_mainIcon.height = _mainIconSize;
				_mainIcon.x = (width - _mainIconSize) / 2;
				_mainIcon.y = (height - _mainIconSize) / 2;
			}
		}
	}
}