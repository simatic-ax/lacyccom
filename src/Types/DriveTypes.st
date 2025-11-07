NAMESPACE Simatic.Ax.LAcycCom

   TYPE LAcycCom_typeDriveDataset

      : STRUCT
         parameterNumber : UINT  := UINT#0;              // Number of the parameter
         index           : UINT  := UINT#0;              // Parameter index
         Rvalue          : REAL  := REAL#0.0;            // Parameter value
         DWvalue         : DWORD := DWORD#16#0000_0000;  // Parameter value
         errorValue      : BYTE  := BYTE#2#11111111;     // Error number (16#FF: no error; else: see error list)
      END_STRUCT;

   END_TYPE


      TYPE LAcycCom_ooptypeDriveDiagnostics

         : STRUCT
            status             : WORD := WORD#16#0000;      // Status identifier when error occurred
            subfunctionStatus  : WORD := WORD#16#0000;      // Block status OR error information
            stateNumber        : LAcycCom_ReadWriteStatus;  // State of the FB when error occurred
            driveObjectId      : USINT := USINT#0;          // Identification number of the drive object
            hardwareId         : HW_IO := HW_IO#default;    // Hardware identifier of the hardware module
            parameterCount     : INT := 0;                  // Total amount of parameters
            firstParameterError: INT := -1;                 // Number of parameter at which the error occurred (-1: no parameter with error)
            errorValue         : BYTE := BYTE#2#11111111;   // Error number (16#FF: no error; else: see error list)
         END_STRUCT;

   END_TYPE

END_NAMESPACE
