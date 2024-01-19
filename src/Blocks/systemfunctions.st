using system.timer;
using system.DateTime;

NAMESPACE Simatic.Ax.LAcycCom
    TYPE typeGEOADDR : STRUCT
            HWTYPE  : UINT;
            AREA    : UINT;
            IOSYSTEM: UINT;
            STATION : UINT;
            SLOT    : UINT;
            SUBSLOT : UINT;
        END_STRUCT;
    END_TYPE

    TYPE TypeSoftware_Revision : STRUCT
            Functional : INT := 3;
        END_STRUCT;
    END_TYPE

    TYPE Typedata : STRUCT
            Order_ID    : STRING := STRING#'22222222';
            Software_Revision : TypeSoftware_Revision;
        END_STRUCT;
    END_TYPE

    FUNCTION_BLOCK Get_IM_Data
        VAR_INPUT
            LADDR	:HW_IO;
            IM_TYPE	:UINT;
        end_VAR

        VAR_OUTPUT
            DONE	:BOOL;
            BUSY	:BOOL;
            ERROR	:BOOL;
            STATUS	:WORD;
        end_var
        VAR_IN_OUT
            DATA  : Typedata;
        END_VAR

        DONE    := True;
        BUSY    := false;
        ERROR   := False;
        STATUS  := WORD#0;

    END_FUNCTION_BLOCK

    FUNCTION LOG2GEO : INT
        VAR_INPUT
            LADDR : HW_IO;
        END_VAR
        VAR_OUTPUT
            GEOADDR : typeGEOADDR;
        end_var

            GEOADDR.IOSYSTEM := UINT#1;
            GEOADDR.STATION := UINT#1;

            LOG2GEO :=0;
    END_FUNCTION



END_NAMESPACE