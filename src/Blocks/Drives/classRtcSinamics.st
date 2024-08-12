using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom
    CLASS LAcycCom_classRtcSinamics
        VAR
            statrtcRealTimeSyncPING : bool;
            statRetSetrtcRealTimeSyncPING : bool;
            statRetResetrtcRealTimeSyncPING : bool;
            statdatasetItem : LAcycCom_typeDriveDataset;
            statrequestBuffer    : Resourcemanager;
            statWriteDriveParams : LAcycCom_classWriteDriveParams;
            statFBState   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_IDLE;   // States in the function block state machine
            statFBSubState   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_BUSY_PING;   // States in the function block during processing (busy state)
            statStatus   : Word := STATUS_NO_CALL;   // Static value for output status
            statStateNumber   : LAcycCom_ReadWriteStatus;   // State of the FB when error occurred
            stathardwareId : HW_IO;
        end_VAR   

        VAR CONSTANT
            STATUS_EXECUTION_FINISHED : Word := word#16#0000;   // Execution finished without errors
            STATUS_NO_CALL : Word := word#16#7000;   // No call of FB
            STATUS_ALLOCATE : Word := word#16#7001;   // FB is currently allocating a request element
            STATUS_GET_RESOURCE : Word := word#16#7002;   // FB is waiting until it has “speaking rights”
            STATUS_BUSY : Word := word#16#7003;   // FB is currently in processing
            STATUS_RELEASE : Word := word#16#7004;   // FB is releasing the allocated element
            ERR_UNDEFINED_STATE : Word := word#16#8611;   // Error due to an undefined state
        END_VAR

        METHOD PUBLIC execute

            IF not (statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                statFBState = LAcycCom_ReadWriteStatus#FB_DONE or
                statFBState = LAcycCom_ReadWriteStatus#FB_ERROR ) THEN  // Functionality running
                CASE statFBState OF
                    LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE:  // First cycle state

                        This.FIRST_CYCLE();

                    LAcycCom_ReadWriteStatus#FB_BUSY:

                        This.BUSY();

                    ELSE
                    statStatus := ERR_UNDEFINED_STATE;
                    statStateNumber := statFBState;
                    statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                END_CASE;
            END_IF;


        end_METHOD         

        Method Private FIRST_CYCLE
            
            statWriteDriveParams.DeleteList();   

            statdatasetItem.parameterNumber := uint#3100;
            statdatasetItem.index := uint#0;
            statdatasetItem.Rvalue := real#1.0;
            statWriteDriveParams.AddatasetItem(datasetItem := statdatasetItem); 

            statdatasetItem.parameterNumber := uint#3103;
            statdatasetItem.index := uint#0;
            statdatasetItem.Rvalue := real#0.0;
            statWriteDriveParams.AddatasetItem(datasetItem := statdatasetItem); 

            statrtcRealTimeSyncPING := False;
            statRetSetrtcRealTimeSyncPING := False;
            statRetResetrtcRealTimeSyncPING := False;

            statFBState := LAcycCom_ReadWriteStatus#FB_BUSY;
            statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_PING_RESET;
        END_METHOD

        Method PRIVATE Busy
            CASE statFBSubState OF
                LAcycCom_ReadWriteStatus#FB_BUSY_PING_RESET: 
                    If statRetResetrtcRealTimeSyncPING then 
                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_PING;
                    END_IF;

                LAcycCom_ReadWriteStatus#FB_BUSY_PING: 
                    statrtcRealTimeSyncPING := TRUE;
                    If statRetSetrtcRealTimeSyncPING then 
                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
                    END_IF;
                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC:
                    statWriteDriveParams.execute();
                    statWriteDriveParams.Start(driveObjectId := uint#1, 
                                                hardwareId := stathardwareId, 
                                                parameterCount := 2);   
                    If  statWriteDriveParams.Status() = LAcycComstateDef#DONE Then
                        statFBState := LAcycCom_ReadWriteStatus#FB_DONE;
                    end_IF;                           
            END_CASE;

        END_METHOD

        METHOD PUBLIC Start : bool
            VAR_INPUT
                hardwareId : HW_IO;
            END_VAR
                         // starts functionality
             IF not ((statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                 statFBState = LAcycCom_ReadWriteStatus#FB_DONE or 
                 statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND
                 statrequestBuffer <> NULL) THEN
                   Start := False;
             ELSE
               // Initialisation
                stathardwareId := hardwareId;
                statFBState := LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE;

             end_if;
            statWriteDriveParams.Config(requestBuffer := statrequestBuffer); 

        end_METHOD
        
        METHOD PUBLIC getPing : bool
            getPing := statrtcRealTimeSyncPING;
            If statrtcRealTimeSyncPING Then
                statRetSetrtcRealTimeSyncPING := TRUE;
                statRetResetrtcRealTimeSyncPING := False;
            else
                statRetSetrtcRealTimeSyncPING := False;
                statRetResetrtcRealTimeSyncPING := TRUE;
            end_If;
        end_METHOD  

        METHOD PUBLIC Config : Bool
            VAR_INPUT
                requestBuffer : Resourcemanager;   // Connection to the request buffer of the resource manager. All LAcycCom blocks have to use the same request buffer
             END_VAR

             statrequestBuffer := requestBuffer;
             statWriteDriveParams.Config(requestBuffer := statrequestBuffer);

        END_METHOD

    END_CLASS

END_NAMESPACE         