NAMESPACE Simatic.Ax.LAcycCom

   TYPE LAcycCom_typeDriveDataset

      : STRUCT
         parameterNumber : UInt := uint#0;   // Number of the parameter
         index : UInt := uint#0;   // Parameter index
         Rvalue : Real := real#0.0;   // Parameter value
         DWvalue : DWord := DWORD#16#0000_0000;   // Parameter value
         errorValue : Byte := byte#2#11111111;    // Error number (16#FF: no error; else: see error list)
      END_STRUCT;

   END_TYPE
(*
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
*)

      TYPE LAcycCom_ooptypeDriveDiagnostics

         : STRUCT
            status :  Word := word#16#0000;   // Status identifier when error occurred
            subfunctionStatus : Word := word#16#0000;   // Block status or error information
            stateNumber : LAcycCom_ReadWriteStatus;   // State of the FB when error occurred
            driveObjectId : USInt := usint#0;   // Identification number of the drive object
            hardwareId : HW_IO := HW_IO#default;   // Hardware identifier of the hardware module
            parameterCount : Int := 0;   // Total amount of parameters
            firstParameterError : Int := -1;   // Number of parameter at which the error occurred (-1: no parameter with error)
            errorValue : Byte := byte#2#11111111;    // Error number (16#FF: no error; else: see error list)
         END_STRUCT;

   END_TYPE

(*
   TYPE LAcycCom_typeDriveMessages
        : STRUCT
            code : Array[0..typeconstantsint#LACYCCOM_MESSAGES_UPPER_LIM] of UInt;
            info : Array[0..typeconstantsint#LACYCCOM_MESSAGES_UPPER_LIM] of UDInt;
            comeDateAndTime : Array[0..typeconstantsint#LACYCCOM_MESSAGES_UPPER_LIM] of LDATE_AND_TIME;
            Mtype  : Array[0..typeconstantsint#LACYCCOM_MESSAGES_UPPER_LIM] of SInt;
         END_STRUCT;

      END_TYPE
*)
END_NAMESPACE
