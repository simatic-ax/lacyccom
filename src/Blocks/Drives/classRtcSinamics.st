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
            statrequestBuffer    : Resourcemanager;
            statWriteDrivePara   : LAcycCom_classWriteDriveSingleParams; 
            statFBState   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_IDLE;   // States in the function block state machine
            statFBSubState   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_BUSY_PING;   // States in the function block during processing (busy state)
            statStatus   : Word := STATUS_NO_CALL;   // Static value for output status
            statStateNumber   : LAcycCom_ReadWriteStatus;   // State of the FB when error occurred
            stathardwareId : HW_IO;
            statsystemDateTime : LDATE_AND_TIME;
            statWritepara : LAcycCom_classWriteDriveSingleParams; 
            statactmilisecond : DWORD;
            statexternTime : Bool;
            StatEnablePing : Bool;
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
 
                        statWriteDrivePara.execute();
                        statWriteDrivePara.Start(driveObjectId  := UINT#1,   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                                                hardwareId := stathardwareId,   // Hardware identifier of the hardware module
                                                parameterNumber := UInt#3100,   // Number of the parameter
                                                index := uint#0,   // Parameter index
                                                value   := real#1.0,
                                                DWVALUE := dword#0
                                                );
                    END_IF;


                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC:
                    statWriteDrivePara.execute();
 
                    If  statWriteDrivePara.Status() = LAcycComstateDef#DONE Then
                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;
                        If StatEnablePing Then
                            statWriteDrivePara.Start(driveObjectId  := UINT#1,   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                                                    hardwareId := stathardwareId,   // Hardware identifier of the hardware module
                                                    parameterNumber := UInt#3103,   // Number of the parameter
                                                    index := uint#0,   // Parameter index
                                                    value   := real#0.0,
                                                    DWVALUE := dword#0
                                                    );
                        else
                            statWriteDrivePara.Start(driveObjectId  := UINT#1,   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                                                    hardwareId := stathardwareId,   // Hardware identifier of the hardware module
                                                    parameterNumber := UInt#3103,   // Number of the parameter
                                                    index := uint#0,   // Parameter index
                                                    value   := real#2.0,
                                                    DWVALUE := dword#0
                                                    );  
                        end_IF;
                    end_IF; 
 
                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1:
                    statWriteDrivePara.execute();
 
                    If  statWriteDrivePara.Status() = LAcycComstateDef#DONE Then
                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_PING;
                    end_IF;   

                LAcycCom_ReadWriteStatus#FB_BUSY_PING: 
                    statrtcRealTimeSyncPING := StatEnablePing;
                    If statRetSetrtcRealTimeSyncPING or not StatEnablePing then 
                        
                        If not statexternTime Then
                            GetSystemDateTime(value => statsystemDateTime);
                        END_IF;

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
          

                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2;
                        statWriteDrivePara.execute();
                        statWriteDrivePara.Start(driveObjectId  := UINT#1,   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                                                hardwareId := stathardwareId,   // Hardware identifier of the hardware module
                                                parameterNumber := UInt#3101,   // Number of the parameter
                                                index := uint#1,   // Parameter index
                                                value   := TO_REAL(elapsedDays+8034),
                                                DWVALUE := dword#0
                                                );
                    END_IF;     

                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2 :
                    statWriteDrivePara.execute();
  
                    If  statWriteDrivePara.Status() = LAcycComstateDef#DONE Then

                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_3;
                        statWriteDrivePara.execute();
                        statWriteDrivePara.Start(driveObjectId  := UINT#1,   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                                        hardwareId := stathardwareId,   // Hardware identifier of the hardware module
                                        parameterNumber := UInt#3101,   // Number of the parameter
                                        index := uint#0,   // Parameter index
                                        value   := real#0.0,
                                        DWVALUE := statactmilisecond
                                        
                                        );

                    end_IF; 
  
                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_3 :
                    statWriteDrivePara.execute();
                    If  statWriteDrivePara.Status() = LAcycComstateDef#DONE Then
                        statFBState := LAcycCom_ReadWriteStatus#FB_DONE;
                        statrtcRealTimeSyncPING := FALSE;
                    end_IF; 
            END_CASE;

        END_METHOD

        METHOD PUBLIC Start : bool
            VAR_INPUT
                hardwareId      : HW_IO;
                enablePingSnap  : Bool := TRUE;
            END_VAR
                         // starts functionality
             IF not ((statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                    statFBState = LAcycCom_ReadWriteStatus#FB_DONE or 
                    statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND
                    statrequestBuffer <> NULL) THEN
                    Start := False;
             ELSE
               // Initialisation
                StatEnablePing := enablePingSnap;
                Start          := True;
                statexternTime := False;
                stathardwareId := hardwareId;
                statFBState := LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE;

             end_if;

            statWriteDrivePara.Config(requestBuffer := statrequestBuffer); 
        end_METHOD

        METHOD PUBLIC StartTimeSet : bool
            VAR_INPUT
                hardwareId : HW_IO;
                enablePingSnap  : Bool := FALSE;
                SetTime : LDATE_AND_TIME;
            END_VAR
                         // starts functionality
             IF not ((statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                    statFBState = LAcycCom_ReadWriteStatus#FB_DONE or 
                    statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND
                    statrequestBuffer <> NULL) THEN
                    StartTimeSet := False;
             ELSE
               // Initialisation
                    StatEnablePing      := enablePingSnap;
                    StartTimeSet        := True;
                    statexternTime      := true;
                    stathardwareId      := hardwareId;
                    statsystemDateTime  := SetTime;
                    statFBState         := LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE;
             end_if;

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

        END_METHOD

        METHOD PUBLIC Status   : LAcycComstateDef;
            CASE statFBState OF
                LAcycCom_ReadWriteStatus#FB_IDLE:
                    Status := LAcycComstateDef#IDLE;

                LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE,
                LAcycCom_ReadWriteStatus#FB_ALLOCATE,
                LAcycCom_ReadWriteStatus#FB_GET_RESOURCE,
                LAcycCom_ReadWriteStatus#FB_BUSY,
                LAcycCom_ReadWriteStatus#FB_RELEASE:
                    Status := LAcycComstateDef#BUSY;

                LAcycCom_ReadWriteStatus#FB_DONE:
                    Status := LAcycComstateDef#DONE;

                LAcycCom_ReadWriteStatus#FB_ERROR:
                    Status := LAcycComstateDef#Error;

                else
                ;
            END_CASE;
        END_METHOD

        METHOD PUBLIC diag : LAcycCom_ooptypeDrivediagnostics
            diag := statWriteDrivePara.errordiagnostics();
        END_METHOD

    END_CLASS

END_NAMESPACE         