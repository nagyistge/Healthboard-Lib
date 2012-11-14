package models
{
	import mx.collections.ArrayCollection;
	
	import util.DateFormatters;

	[Bindable]
	public class UserModel extends PersonModel
	{
		public static const STATE_AVAILABLE:String = "A";
		public static const STATE_UNAVAILABLE:String = "U";
		
		public static const TYPE_PROVIDER:String = "provider";
		public static const TYPE_PATIENT:String = "patient";
		
		//	internal
		public var id:int;
		public var userType:String;
		
		//	basic
		public var birthdate:Date;
		public var sex:int;
		
		//	contact
		public var email:String;
		public var phone:String;
		
		//	location
		public var city:String;
		public var latitude:Number;
		public var longitude:Number;
		public var state:String;
		public var street1:String;
		public var street2:String;
		public var zip:String;
		
		//	security
		public var username:String;
		public var password:String;
		
		//	medical
		public var team:String;
		
		//	application-specific
		public var available:String;
		public var chatHistory:ArrayCollection;
		
		public function UserModel( type:String = TYPE_PATIENT )
		{
			this.userType = type;
			
			super();
		}
		
		public function get fullName():String
		{
			return firstName + ' ' + lastName;
		}
		
		public function get fullNameAbbreviated():String
		{
			return lastName;
		}
		
		public function getBirthdate():String
		{
			return DateFormatters.dateOnlyBackslashDelimited.format( birthdate );
		}
		
		public function getSex():String
		{
			return sex == 0 ? 'Male' : 'Female';
		}
		
		public function getDefaultProfilePictureURL( size:String = "small" ):String
		{
			if( userType == UserModel.TYPE_PATIENT )
				return "images/patients/" + size + "/default.jpg";
			
			return "images/providers/" + size + "/default.jpg";
		}
		
		public function getProfilePictureURL( size:String = "small" ):String
		{
			if( userType == UserModel.TYPE_PATIENT )
				return "images/patients/" + size + "/" + lastName.toLowerCase() + ".jpg";
			
			return "images/providers/" + size + "/" + lastName.toLowerCase() + ".jpg";
		}
	}
}