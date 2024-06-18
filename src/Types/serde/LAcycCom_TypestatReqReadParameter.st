// This is generated code. *** DO NOT MODIFY ***

NAMESPACE Simatic.Ax.LAcycCom
FUNCTION SerializeBig : UDINT
    VAR_INPUT
        offset : UDINT;
        value : LAcycCom_TypestatReqReadParameter;
    END_VAR
    VAR_IN_OUT
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_TEMP
        i : INT;
    END_VAR
    SerializeBig := offset;
    SerializeBig := LAcycCom.SerializeBig(offset := SerializeBig, value := value.header, buffer := buffer);
    FOR i := 0 TO 0 DO
        SerializeBig := LAcycCom.SerializeBig(offset := SerializeBig, value := value.parameterAddress[i], buffer := buffer);
    END_FOR;
END_FUNCTION

FUNCTION DeserializeBig : UDINT
    VAR_INPUT
        offset : UDINT;
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_IN_OUT
        value : LAcycCom_TypestatReqReadParameter;
    END_VAR
    VAR_TEMP
        i : INT;
    END_VAR
    DeserializeBig := offset;
    DeserializeBig := LAcycCom.DeserializeBig(offset := DeserializeBig, value := value.header, buffer := buffer);
    FOR i := 0 TO 0 DO
        DeserializeBig := LAcycCom.DeserializeBig(offset := DeserializeBig, value := value.parameterAddress[i], buffer := buffer);
    END_FOR;
END_FUNCTION
END_NAMESPACE
