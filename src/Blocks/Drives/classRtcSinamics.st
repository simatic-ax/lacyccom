using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom
    CLASS LAcycCom_classRtcSinamics
        VAR
            rtcRealTimeSyncPING : bool;
        end_VAR    
        METHOD PUBLIC execute
                ;
        end_METHOD   
        METHOD PUBLIC Start : bool
             ;
        end_METHOD
        METHOD PUBLIC getPing : bool
            getPing := rtcRealTimeSyncPING;
        end_METHOD  
    END_CLASS
END_NAMESPACE         