using system.timer;
USING Siemens.Simatic.S71500.Clocks;
USING System.DateTime;
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
            statWriteDrivePara   : LAcycCom_classWriteDriveSingleParams; 
            statFBState   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_IDLE;   // States in the function block state machine
            statFBSubState   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_BUSY_PING;   // States in the function block during processing (busy state)
            statStatus   : Word := STATUS_NO_CALL;   // Static value for output status
            statStateNumber   : LAcycCom_ReadWriteStatus;   // State of the FB when error occurred
            stathardwareId : HW_IO;
            statsystemDateTime : LDATE_AND_TIME;
            statWritepara : LAcycCom_classWriteDriveSingleParams; 
            statactmilisecond : DWORD;
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
            VAR
                actDays : INT;
                actMonth : INT;
                actYear : INT;
                actHour : INT;
                actMinute : INT;
                actSecond : INT;
                actMillisecond : INT;
                elapsedYears : INT;
                elapsedDays : DINT;
                loop : DINT;
            END_VAR

            CASE statFBSubState OF
                LAcycCom_ReadWriteStatus#FB_BUSY_PING_RESET: 
                    If statRetResetrtcRealTimeSyncPING then 
                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
                        statWriteDriveParams.execute();
                        statWriteDriveParams.Start(driveObjectId := uint#1, 
                        hardwareId := stathardwareId, 
                        parameterCount := 2);  
                    END_IF;


                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC:
                    statWriteDriveParams.execute();
 
                    If  statWriteDriveParams.Status() = LAcycComstateDef#DONE Then
                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_PING;

                    end_IF; 
                
                LAcycCom_ReadWriteStatus#FB_BUSY_PING: 
                    statrtcRealTimeSyncPING := TRUE;
                    If statRetSetrtcRealTimeSyncPING then 
                        
                        GetSystemDateTime(value => statsystemDateTime);

                        SplitDateAndTime(value := statsystemDateTime,
                        year => actYear,
                        month => actMonth,
                        day => actDays,
                        hour => actHour,
                        minute => actMinute,
                        second => actSecond,
                        millisecond => actMillisecond);
                
                        //add number of days from full years, subtracting the current year
                        FOR loop := 1992 TO (actYear - 1) DO
                            IF loop MOD 4 = 0 AND loop <> 2100 THEN
                                elapsedDays := elapsedDays + 366;
                            ELSE
                                elapsedDays := elapsedDays + 365;
                            END_IF;
                        END_FOR;
                
                        //add days from full months of the current year
                        IF actMonth > 1 THEN
                            elapsedDays := elapsedDays + 31;
                        END_IF;
                        IF actMonth > 2 THEN
                            IF actYear MOD 4 = 0 AND NOT (actYear = 2100) THEN
                                elapsedDays := elapsedDays + 29;
                            ELSE
                                elapsedDays := elapsedDays + 28;
                            END_IF;
                        END_IF;
                        IF actMonth > 3 THEN
                            elapsedDays := elapsedDays + 31;
                        END_IF;
                        IF actMonth > 4 THEN
                            elapsedDays := elapsedDays + 30;
                        END_IF;
                        IF actMonth > 5 THEN
                            elapsedDays := elapsedDays + 31;
                        END_IF;
                        IF actMonth > 6 THEN
                            elapsedDays := elapsedDays + 30;
                        END_IF;
                        IF actMonth > 7 THEN
                            elapsedDays := elapsedDays + 31;
                        END_IF;
                        IF actMonth > 8 THEN
                            elapsedDays := elapsedDays + 31;
                        END_IF;
                        IF actMonth > 9 THEN
                            elapsedDays := elapsedDays + 30;
                        END_IF;
                        IF actMonth > 10 THEN
                            elapsedDays := elapsedDays + 31;
                        END_IF;
                        IF actMonth > 11 THEN
                            elapsedDays := elapsedDays + 30;
                        END_IF;
                
                        //add days from current month
                        elapsedDays := elapsedDays + actDays;
                        statactmilisecond :=TO_DWORD (TO_UDINT(actMillisecond) + UDINT#1000 * (TO_UDINT(actSecond) + UDINT#60 * (TO_UDINT(actMinute + 60 * ( actHour)))));

                        statWriteDriveParams.DeleteList();   

                        statdatasetItem.parameterNumber := uint#3101; //date
                        statdatasetItem.index := uint#1;
                       // statdatasetItem.Rvalue := LWORD_TO_LREAL(LDATE_TO_LWORD(LDATE_AND_TIME_TO_LDATE(statsystemDateTime)));
                        statWriteDriveParams.AddatasetItem(datasetItem := statdatasetItem); 
            

                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;
                        statWriteDriveParams.execute();
                        statWriteDrivePara.execute();
                        statWriteDrivePara.Start(driveObjectId  := UINT#1,   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                                                hardwareId := word#266,   // Hardware identifier of the hardware module
                                                parameterNumber := UInt#3101,   // Number of the parameter
                                                index := uint#1,   // Parameter index
                                                value   := TO_REAL(elapsedDays+8034),
                                                DWVALUE := dword#0
                                                );
                  (*       statWriteDriveParams.Start(driveObjectId := uint#1, 
                                                    hardwareId := stathardwareId, 
                                                    parameterCount := 1); *)
                    END_IF;     

                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1 :
                    statWriteDriveParams.execute();
                    statWriteDrivePara.execute();
  
                    If  statWriteDrivePara.Status() = LAcycComstateDef#DONE Then

                        statWriteDriveParams.DeleteList();   

            
                        statdatasetItem.parameterNumber := uint#3101;//ms
                        statdatasetItem.index := uint#0;
                        statdatasetItem.Rvalue := real#288000.0;
                        statWriteDriveParams.AddatasetItem(datasetItem := statdatasetItem); 

                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;
                        statWriteDriveParams.execute();
                        statWriteDrivePara.execute();
                        statWriteDrivePara.Start(driveObjectId  := UINT#1,   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                                        hardwareId := word#266,   // Hardware identifier of the hardware module
                                        parameterNumber := UInt#3101,   // Number of the parameter
                                        index := uint#0,   // Parameter index
                                        value   := real#0.0,
                                        DWVALUE := statactmilisecond
                                        
                                        );
             (*            statWriteDriveParams.Start(driveObjectId := uint#1, 
                                                    hardwareId := stathardwareId, 
                                                    parameterCount := 1); 
*)
                    end_IF; 
  
                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2 :
                    statWriteDriveParams.execute();
                    statWriteDrivePara.execute();
                    If  statWriteDrivePara.Status() = LAcycComstateDef#DONE Then
                        statFBState := LAcycCom_ReadWriteStatus#FB_DONE;
                        statrtcRealTimeSyncPING := FALSE;
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
            statWriteDrivePara.Config(requestBuffer := statrequestBuffer); 
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

        METHOD PUBLIC status : LAcycCom_ReadWriteStatus
            status := statFBSubState;
        END_METHOD

        METHOD PUBLIC diag : LAcycCom_ooptypeDrivediagnostics
            diag := statWriteDriveParams.errordiagnostics();
        END_METHOD

    END_CLASS

END_NAMESPACE         