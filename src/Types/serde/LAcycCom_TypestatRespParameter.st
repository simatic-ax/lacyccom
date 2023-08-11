// This is generated code. *** DO NOT MODIFY ***

NAMESPACE Simatic.Ax.LAcycCom
FUNCTION SerializeBig : UINT
    VAR_INPUT
        offset : UINT;
        value : LAcycCom_TypestatRespParameter;
    END_VAR
    VAR_IN_OUT
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_TEMP
        i : INT;
    END_VAR
    SerializeBig := offset;
    SerializeBig := LAcycCom.SerializeBig(offset := SerializeBig, value := value.header, buffer := buffer);
    FOR i := 0 TO 233 DO
        SerializeBig := System.Serde.SerializeBig(offset := SerializeBig, value := value.data[i], buffer := buffer);
    END_FOR;
END_FUNCTION

FUNCTION DeserializeBig : UINT
    VAR_INPUT
        offset : UINT;
        buffer : ARRAY[*] OF BYTE;
    END_VAR
    VAR_IN_OUT
        value : LAcycCom_TypestatRespParameter;
    END_VAR
    VAR_TEMP
        i : INT;
    END_VAR
    DeserializeBig := offset;
    DeserializeBig := LAcycCom.DeserializeBig(offset := DeserializeBig, value := value.header, buffer := buffer);
    FOR i := 0 TO 233 DO
        DeserializeBig := System.Serde.DeserializeBig(offset := DeserializeBig, value := value.data[i], buffer := buffer);
    END_FOR;
END_FUNCTION
END_NAMESPACE
