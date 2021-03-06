package edu.newschool.piim.healthboard.controller
{
	import edu.newschool.piim.healthboard.Constants;
	import edu.newschool.piim.healthboard.enum.ViewModeType;
	import edu.newschool.piim.healthboard.events.ApplicationDataEvent;
	import edu.newschool.piim.healthboard.events.ApplicationEvent;
	import edu.newschool.piim.healthboard.events.AppointmentEvent;
	import edu.newschool.piim.healthboard.events.AuthenticationEvent;
	import edu.newschool.piim.healthboard.model.ApplicationModel;
	import edu.newschool.piim.healthboard.model.AppointmentCategory;
	import edu.newschool.piim.healthboard.model.ModuleMappable;
	import edu.newschool.piim.healthboard.model.NextStep;
	import edu.newschool.piim.healthboard.model.PatientsModel;
	import edu.newschool.piim.healthboard.model.Preferences;
	import edu.newschool.piim.healthboard.model.ProvidersModel;
	import edu.newschool.piim.healthboard.model.UserModel;
	import edu.newschool.piim.healthboard.model.module.AppointmentsModel;
	import edu.newschool.piim.healthboard.model.module.ImmunizationsModel;
	import edu.newschool.piim.healthboard.model.module.MedicalRecordsModel;
	import edu.newschool.piim.healthboard.model.module.MedicationsModel;
	import edu.newschool.piim.healthboard.model.module.appointments.PatientAppointment;
	import edu.newschool.piim.healthboard.model.module.medicalrecords.MedicalRecord;
	import edu.newschool.piim.healthboard.util.DateUtil;
	
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.net.SharedObject;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	
	import mx.collections.ArrayCollection;
	import mx.core.FlexGlobals;
	import mx.core.IChildList;
	import mx.core.IFlexDisplayObject;
	import mx.core.UIComponent;
	import mx.events.FlexEvent;
	import mx.events.ListEvent;
	import mx.events.StyleEvent;
	import mx.managers.CursorManager;
	import mx.managers.PopUpManager;
	import mx.states.State;
	
	import net.flexwiz.blog.tabbar.plus.TabPlus;
	
	import spark.components.Application;
	import spark.events.IndexChangeEvent;
	
	public class Controller
	{
		[Bindable] public var appointmentsController:AppointmentsController;
		[Bindable] public var exerciseController:ExerciseController;
		[Bindable] public var immunizationsController:ImmunizationsController;
		[Bindable] public var medicalRecordsController:MedicalRecordsController;
		[Bindable] public var medicationsController:MedicationsController;
		[Bindable] public var messagesController:MessagesController;
		[Bindable] public var nutritionController:NutritionController;
		[Bindable] public var patientsController:PatientsController;
		[Bindable] public var providersController:ProvidersController;
		[Bindable] public var vitalSignsController:VitalSignsController;
		
 		private var _model:ApplicationModel;
		
		public var application:Application;
		
		protected var lastActivity:int;
		
		private var sessionTimer:Timer;
		
		public var persistentData:SharedObject;
		
		protected var controllersInitialized:Boolean;
		
		public function Controller()
		{
			appointmentsController = new AppointmentsController();
			exerciseController = new ExerciseController();
			immunizationsController = new ImmunizationsController();
			medicalRecordsController = new MedicalRecordsController();
			medicationsController = new MedicationsController();
			messagesController = new MessagesController();
			nutritionController = new NutritionController();
			patientsController = new PatientsController();
			providersController = new ProvidersController();
			vitalSignsController = new VitalSignsController();
			
			application = FlexGlobals.topLevelApplication as Application;
			
			application.addEventListener( AuthenticationEvent.SUCCESS, onAuthenticated );
			application.addEventListener( ApplicationDataEvent.LOAD, onLoadDataRequest );
			application.addEventListener( ApplicationEvent.NAVIGATE, onNavigate );
			application.addEventListener( ApplicationEvent.SET_STATE, onSetState );
			application.addEventListener( TabPlus.CLOSE_TAB_EVENT, onTabClose );
			application.addEventListener( FlexEvent.APPLICATION_COMPLETE, onApplicationComplete );
			application.addEventListener( MouseEvent.CLICK, onActivity );
			
			sessionTimer = new Timer( 5000 );
			sessionTimer.addEventListener(TimerEvent.TIMER, onCheckSession );
			
			persistentData = SharedObject.getLocal( id );
		}
		
		protected function init():void
		{
			patientsController.model.dataService.send();
			providersController.model.dataService.send();
		}
		
		protected function get initialized():Boolean
		{
			return patientsController.model.dataLoaded && providersController.model.dataLoaded;
		}
		
		protected function onInitialized():void
		{
		}
		
		protected function onPatientsLoaded(event:ApplicationDataEvent):void 
		{
			onInitialized();
		}
		
		protected function onProvidersLoaded(event:ApplicationDataEvent):void 
		{
			onInitialized();
		}
		
		protected function onAppointmentsLoaded(event:ApplicationDataEvent):void
		{
			var medicalRecords:ArrayCollection = new ArrayCollection();
			
			for each(var appointment:PatientAppointment in AppointmentsModel(appointmentsController.model).appointments)
			{
				for each(var medicalRecord:MedicalRecord in appointment.medicalRecords)
				{
					medicalRecords.addItem( medicalRecord );
				}
			}
			
			MedicalRecordsModel( medicalRecordsController.model ).medicalRecords = medicalRecords;
			MedicalRecordsModel( medicalRecordsController.model ).categories = AppointmentsModel(appointmentsController.model).appointmentCategories;
			MedicalRecordsModel( medicalRecordsController.model ).nextSteps = AppointmentsModel(appointmentsController.model).nextSteps;
		}
		
		public function getUserById( id:int, type:String = null ):UserModel
		{
			var user:UserModel;
			
			var users:ArrayCollection = (type==UserModel.TYPE_PROVIDER?ProvidersModel(providersController.model).providers:PatientsModel(patientsController.model).patients);
			
			for each(user in users) if( user.id == id ) return user;
			
			return null;
		}
		
		[Bindable]
		public function get model():ApplicationModel
		{
			return _model;
		}

		public function set model(value:ApplicationModel):void
		{
			_model = value;
			
			if( model )
			{
				loadPreferences();
			}
		}

		public function showPreferences():UIComponent{return null}
		
		protected function loadPreferences():void{}
		
		public function savePreferences( preferences:Preferences ):void
		{
			processPreferences( preferences );
			
			model.preferences = preferences;
		}
		
		protected function processPreferences( preferences:Preferences = null ):void
		{
			if( preferences == null ) preferences  = model.preferences;
			
			if( preferences 
				&& preferences.colorScheme != model.preferences.colorScheme )
			{
				loadStyles( preferences.colorScheme );
			}
		}
		
		protected function loadStyles( scheme:String = null ):void
		{
			if( !scheme ) scheme = model.preferences.colorScheme;
			
			CursorManager.setBusyCursor();
			
			application.styleManager.loadStyleDeclarations( "assets/themes/" + scheme + ".swf" ).addEventListener( StyleEvent.COMPLETE, onStylesLoad, false, 0, true );
		}
		
		protected function onStylesLoad(event:StyleEvent):void
		{
			CursorManager.removeBusyCursor();
			
			model.dispatchEvent( new ApplicationEvent( ApplicationEvent.STYLES_LOADED ) );
		}
		
		protected function onAuthenticated(event:AuthenticationEvent):void
		{
			if( !controllersInitialized )
			{
				appointmentsController.init();
				exerciseController.init();
				immunizationsController.init();
				medicalRecordsController.init();
				medicationsController.init();
				messagesController.init();
				nutritionController.init();
				patientsController.init();
				vitalSignsController.init();
				
				controllersInitialized = true;
			}
			
			lastActivity = getTimer();
			
			sessionTimer.reset();
			sessionTimer.start();
			
			showHome();
		}
		
		protected function showHome():void
		{
			setState( model.preferences.viewMode == ViewModeType.WIDGET ? Constants.STATE_WIDGET_VIEW : Constants.STATE_LOGGED_IN );
		}
		
		private function onApplicationComplete(event:FlexEvent):void
		{
			init();
		}
		
		protected function onLoadDataRequest(event:ApplicationDataEvent):void
		{
			loadData( event.data );
		}
		
		protected function onNavigate( event:ApplicationEvent ):void
		{
			if( event.data == 0 )
			{
				showHome();
			}
		}
		
		protected function onSetState( event:ApplicationEvent ):void
		{
			setState( event.data );
		}
		
		protected function onTabClose( event:ListEvent ):void
		{
		}
		
		protected function setState( state:String ):Boolean
		{
			closePopups();
			
			for each( var states:State in application.states )
			{
				if( states.name == state )
				{
					application.currentState = state;
					
					return true;
				}
			}
			
			return false;
		}
		
		private function onActivity( event:MouseEvent ):void
		{
			lastActivity = getTimer();
		}
		
		protected function onCheckSession( event:TimerEvent ):void
		{
			if( !model.preferences ) return;
			
			if( getTimer() - lastActivity > model.preferences.autoLockIntervalMinutes * DateUtil.MINUTE )
			{
				showInactivityTimeout();
			}
		}
		
		protected function showInactivityTimeout():void
		{
		}
		
		private function closePopups():void
		{
			var popups:ArrayCollection = getAllPopups();
			
			for each(var popup:IFlexDisplayObject in popups)
			{
				if( popup && popup.parent )
				{
					PopUpManager.removePopUp(popup);
				}
			}
		}
		
		public function logout():void
		{
			sessionTimer.stop();
			
			//	remove all cursors
			CursorManager.removeAllCursors();
			
			//	close all popups
			closePopups();
			
			model.user = null;
			
			var evt:ApplicationEvent = new ApplicationEvent( ApplicationEvent.SET_STATE );
			evt.data = Constants.STATE_DEFAULT;
			application.dispatchEvent( evt );
		}
		
		public function loadData( id:String ):Boolean
		{
			if( id == ImmunizationsModel.ID )
			{
				if( !immunizationsController.model.dataLoaded ) 
				{
					immunizationsController.model.dataService.send();
					
					return true;
				}
			}
			else if( id == MedicationsModel.ID )
			{
				if( !medicationsController.model.dataLoaded ) 
				{
					medicationsController.model.dataService.send();
					
					return true;
				}
			}
			else if( id == MedicalRecordsModel.ID )
			{
				if( !medicalRecordsController.model.dataLoaded ) 
				{
					medicalRecordsController.model.dataService.send();
					
					return true;
				}
			}
			
			return false;
		}
		
		public function selectSetting( event:IndexChangeEvent ):void
		{
		}
		
		public function validateUser( username:String, password:String ):UserModel
		{
			return null;
		}
		
		public function getDefaultUser():UserModel
		{
			return null;
		}
		
		public function processModuleMappable( item:ModuleMappable ):void
		{
			var evt:Event;
			
			var module:String = item.moduleID;
			
			if( module == Constants.MODULE_APPOINTMENTS )
			{
				if( item is NextStep 
					&& (item as NextStep).recommendation )
				{
					evt = new AppointmentEvent( AppointmentEvent.REQUEST_APPOINTMENT, true );
					
					if( item.type == "class" )
					{
						evt = new AppointmentEvent( AppointmentEvent.REQUEST_APPOINTMENT, true, false, (item as NextStep).actionId );
						AppointmentEvent(evt).category = new AppointmentCategory( 'class' );
					}
					
					AppProperties.getInstance().controller.application.dispatchEvent( evt );
					
					return;
				}
			}
			
			if( module )
			{
				evt = new ApplicationEvent( ApplicationEvent.SET_STATE, true, false, module );
				application.dispatchEvent( evt );
			}
		}
		
		public function getModuleTitle(module:String):String
		{
			if( module == Constants.MODULE_APPOINTMENTS ) return "Appointments";
			if( module == Constants.MODULE_EXERCISE ) return "Exercise";
			if( module == Constants.MODULE_IMMUNIZATIONS ) return "Immunizations";
			if( module == Constants.MODULE_MEDICATIONS ) return "Medications";
			if( module == Constants.MODULE_MEDICAL_RECORDS ) return "Medical Records";
			if( module == Constants.MODULE_MESSAGES ) return "Messages";
			if( module == Constants.MODULE_NUTRITION ) return "Nutrition";
			if( module == Constants.MODULE_RECENT_ACTIVITIES ) return "Recent Activities";
			if( module == Constants.MODULE_VITAL_SIGNS ) return "Vital Signs";
			
			return null;
		}
		
		private function getAllPopups(applicationInstance: Object = null, onlyVisible: Boolean = false):ArrayCollection
		{
			var result: ArrayCollection = new ArrayCollection();
			
			if (applicationInstance == null)
			{
				applicationInstance = FlexGlobals.topLevelApplication;
			}
			
			var rawChildren:IChildList = applicationInstance.systemManager.rawChildren;
			
			for (var i: int = 0; i < rawChildren.numChildren; i++)
			{
				var currRawChild:DisplayObject = rawChildren.getChildAt(i);
				
				if ((currRawChild is UIComponent) && UIComponent(currRawChild).isPopUp)
				{
					if (!onlyVisible || UIComponent(currRawChild).visible)
					{
						result.addItem(currRawChild);
					}
				}
			}
			
			return result;
		}
		
		protected function get id():String
		{
			throw new Error( 'Sub-classes must implement get id()' );
		}
	}
}