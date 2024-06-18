// This is generated code. *** DO NOT MODIFY ***

NAMESPACE Simatic.Ax.LAcycCom
FUNCTION SerializeBig : UDINT
    VAR_INPUT
        offset : UDINT;
        value : LAcycCom_TypestatReqWriteParameter;
    END_VAR
    VAR_IN_OUT
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_TEMP
        i : INT;
    END_VAR
    SerializeBig := offset;
    SerializeBig := LAcycCom.SerializeBig(offset := SerializeBig, value := value.header, buffer := buffer);
    FOR i := 0 TO 227 DO
        SerializeBig := System.Serialization.SerializeBig(offset := SerializeBig, value := value.data[i], buffer := buffer);
    END_FOR;
END_FUNCTION

FUNCTION DeserializeBig : UDINT
    VAR_INPUT
        offset : UDINT;
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_IN_OUT
        value : LAcycCom_TypestatReqWriteParameter;
    END_VAR
    VAR_TEMP
        i : INT;
    END_VAR
    DeserializeBig := offset;
    DeserializeBig := LAcycCom.DeserializeBig(offset := DeserializeBig, value := value.header, buffer := buffer);
    FOR i := 0 TO 227 DO
        DeserializeBig := System.Serialization.DeserializeBig(offset := DeserializeBig, value := value.data[i], buffer := buffer);
    END_FOR;
END_FUNCTION
END_NAMESPACE
