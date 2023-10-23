using system.timer;
using system.DateTime;

NAMESPACE Simatic.Ax.LAcycCom
    TYPE typeGEOADDR : STRUCT
            HWTYPE  : Uint;
            AREA    : Uint;
            IOSYSTEM: Uint;
            STATION : Uint;
            SLOT    : Uint;
            SUBSLOT : Uint;
        END_STRUCT;
    END_TYPE

    TYPE TypeSoftware_Revision : STRUCT
            Functional : Int := 3;
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
            IM_TYPE	:UInt;
        end_VAR

        VAR_OUTPUT
            DONE	:Bool;
            BUSY	:Bool;
            ERROR	:Bool;
            STATUS	:Word;
        end_var
        VAR_IN_OUT
            DATA  : Typedata;
        END_VAR

        DONE    := True;
        BUSY    := false;
        ERROR   := False;
        STATUS  := word#0;

    END_FUNCTION_BLOCK

    FUNCTION LOG2GEO : int
        VAR_INPUT
            LADDR : HW_IO;
        END_VAR
        VAR_OUTPUT
            GEOADDR : typeGEOADDR;
        end_var

            GEOADDR.IOSYSTEM := uint#1;
            GEOADDR.STATION := uint#1;

            LOG2GEO :=0;
    END_FUNCTION



END_NAMESPACE