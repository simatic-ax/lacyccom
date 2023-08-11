NAMESPACE Simatic.Ax.LAcycCom
   TYPE LAcycCom_typeDriveDatasetDWord

      : STRUCT
         parameterNumber : UInt := uint#0;   // Number of the parameter
         index : UInt := uint#0;   // Parameter index
         value : DWord := DWORD#16#0000_0000;   // Parameter value
         errorValue : Byte := byte#2#11111111;   // Error number (16#FF: no error; else: see error list)
      END_STRUCT;
   
   END_TYPE
   
   TYPE LAcycCom_typeDriveDatasetReal

      : STRUCT
         parameterNumber : UInt := uint#0;   // Number of the parameter
         index : UInt := uint#0;   // Parameter index
         value : Real := real#0.0;   // Parameter value
         errorValue : Byte := byte#2#11111111;    // Error number (16#FF: no error; else: see error list)
      END_STRUCT;
   
   END_TYPE

   TYPE LAcycCom_typeDriveDiagnostics

      : STRUCT
         status : Word := word#16#0000;   // Status identifier when error occurred
         subfunctionStatus : Word := word#16#0000;   // Block status or error information
         stateNumber : SInt := sint#0;   // State of the FB when error occurred
         driveObjectId : USInt := usint#0;   // Identification number of the drive object
         hardwareId : HW_IO := HW_IO#default;   // Hardware identifier of the hardware module
         parameterCount : Int := 0;   // Total amount of parameters
         firstParameterError : Int := -1;   // Number of parameter at which the error occurred (-1: no parameter with error)
         errorValue : Byte := byte#2#11111111;    // Error number (16#FF: no error; else: see error list)
      END_STRUCT;
   
   END_TYPE
   
   Type LAcycCom_typeDriveDataset
      : Struct   // Dataset for reading and writing parameters
         parameterNumber : UInt := uint#0;   // Number of the parameter
         index : UInt := uint#0;   // Parameter index
         value : Real := real#0.0;   // Parameter value
         errorValue : Byte := byte#2#11111111;    // Error value in parameter response (16#FF: no error; else: see error list)
      END_STRUCT;
   END_TYPE   

   TYPE LAcycCom_typeDriveSilentOperation

      : STRUCT
         lifeSignCheckFBRead : UInt := uint#0;   // Counter to monitor that the function block LAcycCom_ReadDriveParams is enabled
         lifeSignCheckFBWrite : UInt := uint#0;   // Counter to monitor that the function block LAcycCom_WriteDriveParams is enabled
         functionBlockCommand : Byte := byte#2#00000000;   // 16#01: read command; 16#02: write command
         parameterCount : Int := 0;   // Count of parameters
         driveObjectId : Int := -1;   // Optional: Identification number of the drive object (value <0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
         hardwareId : HW_IO := HW_IO#default;   // Hardware identifier of the hardware module
         done : Bool := FALSE;   // TRUE: Finished processing
         busy : Bool := FALSE;   // TRUE: Function block is not finished and new output values can be expected
         error  : Bool := FALSE;   // TRUE: Rising edge informs that an error occurred during the execution
         status  : Word := word#16#0000;   // Status identifier
         dataset : Array[0..typeconstantsint#LACYCCOM_SILENT_OPERATION_PARAMETERS_UPPER_LIM] of LAcycCom_typeDriveDataset;   // Dataset for reading and writing parameters

      END_STRUCT;
   
   END_TYPE
(*
TYPE LAcycCom_typeDriveMessages

   : STRUCT
      code  : Array[0..typeconstantsint#LACYCCOM_MESSAGES_UPPER_LIM] of UInt;
      info  : Array[0..typeconstantsint#LACYCCOM_MESSAGES_UPPER_LIM] of UDInt;
      comeDateAndTime  : Array[0..typeconstantsint#LACYCCOM_MESSAGES_UPPER_LIM] of DTL;
      type  : Array[0..LACYCCOM_MESSAGES_UPPER_LIM] of SInt;
   END_STRUCT;

END_TYPE *)

END_NAMESPACE
