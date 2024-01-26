// This is generated code. *** DO NOT MODIFY ***

NAMESPACE Simatic.Ax.LAcycCom
FUNCTION SerializeBig : UINT
    VAR_INPUT
        offset : UINT;
        value : LAcycCom_Typestatheader;
    END_VAR
    VAR_IN_OUT
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    SerializeBig := offset;
    SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.refNo, buffer := buffer);
    SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.reqId, buffer := buffer);
    SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.doId, buffer := buffer);
    SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.parameterNo, buffer := buffer);
END_FUNCTION

FUNCTION DeserializeBig : UINT
    VAR_INPUT
        offset : UINT;
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_IN_OUT
        value : LAcycCom_Typestatheader;
    END_VAR
    DeserializeBig := offset;
    DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.refNo, buffer := buffer);
    DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.reqId, buffer := buffer);
    DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.doId, buffer := buffer);
    DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.parameterNo, buffer := buffer);
END_FUNCTION
END_NAMESPACE
