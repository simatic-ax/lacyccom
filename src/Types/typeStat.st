NAMESPACE Simatic.Ax.LAcycCom
    Type LAcycCom_TypestatResourceAddInfo
        :  Struct   // Additional resource information
             IOSystem  : Int;   // Format and area: 0=central, 1= PNIO, 2= DP, 3= AS-i
             station  : Int;   // Station number, central: rack
        end_struct;

    END_Type

    Type LAcycCom_TypestattempCurReqState
        : Struct   // Current state of the request
            allocated : Bool;   // TRUE: Resource should be allocated to current request
            assigned : Bool;   // TRUE: Resource is assigned to the current request
            release : Bool;   // TRUE: Resource can be released
            rejected : Bool;   // TRUE: Resource can be rejected
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatstatParameter
        :  Struct   // Parameter dataset
            parameterNo   : UInt;   // Number of parameter (Number 1..65535)
            index   : UInt;   // Subindex (Number 1..65535)
            realValue   : Real;   // Value of parameter (Real)
            dwordValue   : DWord;   // Value of parameter (DWord)
            format   : Byte;   // Format of value
            errorValue   : Byte;   // Error number (16#FF: no error; else: see error list)
        END_STRUCT;
    END_TYPE

    Type LAcycCom_Typestatheader
        : Struct   // Telegram header
            refNo   : Byte;   // Request reference (Request ID, mirrored in response)
            reqId   : Byte := byte#16#01;   // Request ID 0x1=Read
            doId   : Byte;   // Identification number of the drive object
            parameterNo   : Byte;   // Number of parameters
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatstatReqParameter
        : Struct   // Request telegram
            header :  LAcycCom_Typestatheader;
            parameterAddress : Array[0..typeconstantsint#LACYCCOM_READ_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatparameterAddress;
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatparameterAddress
        : Struct   // Parameter data in telegram
            attribute   : Byte;   // Attribute of parameters (0x10=Value, 0x30=Text)
            elementNo   : Byte;   // Number of elements (for single elements=1)
            parameterNo   : UInt;   // Number of parameter (Number 1..65535)
            index   : UInt;   // Subindex (Number 1..65535)
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatRespParameter
        : Struct   // Response telegram
            header   : LAcycCom_Typestatheader;
            data   : Array[0..typeconstantsint#LENGTH_PARAMETER_TELEGRAM_UPPER_LIM] of Byte;   // List of parameter
        END_STRUCT;
    END_TYPE

    Type LAcycCom_TypestatReqReadParameter
        : Struct   // Request telegram to read the format of parameters
            header   : LAcycCom_Typestatheader;   // Telegram header
            parameterAddress   : Array[0..typeconstantsint#WRITE_PARAMETERS_UPPER_LIM_SINGLE] of LAcycCom_TypestatparameterAddress;   // Parameter data in telegram
        END_STRUCT;
    end_Type

    Type LAcycCom_TypestatReqWriteParameter
        : Struct   // Response telegram
            header   : LAcycCom_Typestatheader;
            data   : Array[0..typeconstantsint#LENGTH_WRITE_TELEGRAM_UPPER_LIM] of Byte;   // List of parameter
        END_STRUCT;
    END_TYPE

END_NAMESPACE