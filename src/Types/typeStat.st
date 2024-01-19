NAMESPACE Simatic.Ax.LAcycCom
    Type LAcycCom_TypestatResourceAddInfo
                 :   Struct  // Additional resource information
        IOSystem : INT;      // Format and area: 0=central, 1= PNIO, 2= DP, 3= AS-i
        station  : INT;      // Station number, central: rack
        end_struct;

    END_Type

    Type LAcycCom_TypestattempCurReqState
                  :  Struct  // Current state of the request
        allocated : BOOL;    // TRUE: Resource should be allocated to current request
        assigned  : BOOL;    // TRUE: Resource is assigned to the current request
        release   : BOOL;    // TRUE: Resource can be released
        rejected  : BOOL;    // TRUE: Resource can be rejected
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatstatParameter
                    :   Struct  // Parameter dataset
        parameterNo : UINT;     // Number of parameter (Number 1..65535)
        index       : UINT;     // Subindex (Number 1..65535)
        realValue   : REAL;     // Value of parameter (REAL)
        dwordValue  : DWORD;    // Value of parameter (DWORD)
        format      : BYTE;     // Format of value
        errorValue  : BYTE;     // Error number (16#FF: no error; else: see error list)
        END_STRUCT;
    END_TYPE

    Type LAcycCom_Typestatheader
                    :  Struct              // Telegram header
        refNo       : BYTE;                // Request reference (Request ID, mirrored in response)
        reqId       : BYTE := BYTE#16#01;  // Request ID 0x1=Read
        doId        : BYTE;                // Identification number of the drive object
        parameterNo : BYTE;                // Number of parameters
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatstatReqParameter
                         :  Struct                                                                                                  // Request telegram
        header           : LAcycCom_Typestatheader;
        parameterAddress : Array[0..LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatparameterAddress;
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatparameterAddress
                    :  Struct  // Parameter data in telegram
        attribute   : BYTE;    // Attribute of parameters (0x10=Value, 0x30=Text)
        elementNo   : BYTE;    // Number of elements (for single elements=1)
        parameterNo : UINT;    // Number of parameter (Number 1..65535)
        index       : UINT;    // Subindex (Number 1..65535)
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatRespParameter
               :  Struct                                                                      // Response telegram
        header : LAcycCom_Typestatheader;
        data   : Array[0..LAcycComConstantsInt#LENGTH_PARAMETER_TELEGRAM_UPPER_LIM] of BYTE;  // List of parameter
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatReqReadParameter
                         :  Struct                                                                                                 // Request telegram to read the format of parameters
        header           : LAcycCom_Typestatheader;                                                                                // Telegram header
        parameterAddress : Array[0..LAcycComConstantsInt#WRITE_PARAMETERS_UPPER_LIM_SINGLE] of LAcycCom_TypestatparameterAddress;  // Parameter data in telegram
        END_STRUCT;
    end_Type

    Type LAcycCom_TypestatReqWriteParameter
               :  Struct                                                                  // Response telegram
        header : LAcycCom_Typestatheader;
        data   : Array[0..LAcycComConstantsInt#LENGTH_WRITE_TELEGRAM_UPPER_LIM] of BYTE;  // List of parameter
        END_STRUCT;
    END_TYPE

END_NAMESPACE