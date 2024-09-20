NAMESPACE Simatic.Ax.LAcycCom
    Type
        LAcycCom_ReadWriteStatus : (
            FB_IDLE,        // Idle state in FB
            FB_FIRST_CYCLE, // First cycle state in FB
            FB_ALLOCATE,    // Allocating a request element in request buffer DB
            FB_GET_RESOURCE,// State to check if the communication to the drive object can be established
            FB_BUSY,        // Busy state in FB
            FB_RELEASE,     // State to return the allocated index
            FB_DONE,        // Done state in FB
            FB_ERROR,       // Error state in FB
            FB_BUSY_WRREC,  // WRREC in busy state
            FB_BUSY_RDREC,  // RDREC in busy state
            FB_BUSY_WAIT,    // State when temporary error occurred
            FB_BUSY_WRREC_1,
            FB_BUSY_WRREC_2,
            FB_BUSY_WRREC_3,
            FB_BUSY_RDREC_1,
            FB_BUSY_RDREC_2,
            FB_GET_SUBSTATE,

            FB_BUSY_PING_RESET,
            FB_BUSY_PING_RESET_END,
            FB_BUSY_PING,
            FB_BUSY_READ_PING,
            FB_BUSY_CHECK_PING,
            FB_BUSY_RD_LOC_T_DAYS,
            FB_BUSY_RD_LOC_T_MSEC,
            FB_BUSY_WRREC_TIMESTAMP, 
            FB_BUSY_WRREC_TIME_DAYS, 
            FB_BUSY_WRREC_TIME_MSEC, 
            FB_BUSY_WRREC_RD_PING,
            FB_BUSY_RDREC_TIMESTAMP, 
            FB_BUSY_RDREC_TIME_DAYS, 
            FB_BUSY_RDREC_TIME_MSEC, 
            FB_BUSY_RDREC_RD_PING

        );

        LAcycCom_ResourceManagerRetval : (
            ERR_INVALID_BUF_INDEX,
            ERR_REQUEST_REJECTED,
            ERR_RESOURCE_RELEASED,
            STATUS_BUSY,
            STATUS_GET_RESOURCE,
            STATUS_EXECUTION_FINISHED
        );

        LAcycComstateDef : (
            BUSY,
            IDLE,
            DONE,
            ABORTED,
            ERROR
        );
    END_TYPE
END_NAMESPACE
