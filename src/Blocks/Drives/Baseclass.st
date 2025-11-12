using System.Timer;
using Siemens.Simatic.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom

    CLASS ABSTRACT ReadWriteParameter
        VAR
            statrequestBuffer      : Resourcemanager;                                                                                                                  // Connection to the request buffer of the resource manager. All LAcycCom blocks have to use the same request buffer
            statdiagnostics        : LAcycCom_ooptypeDrivediagnostics;                                                                                                 // statdiagnostics structure
            statTimerStart         : BOOL := FALSE;                                                                                                                    // TRUE: Starts IEC-Timer
            statCmdBusy            : BOOL := FALSE;                                                                                                                    // TRUE: Process is NOT yet complete
            statCmdDone            : BOOL := FALSE;                                                                                                                    // TRUE: Data record was transferred
            statCmdError           : BOOL := FALSE;                                                                                                                    // TRUE: An error occurred during processing
            statHwId               : HW_IO := HW_IO#default;                                                                                                           // Intern hardware identifier of the hardware module
            statDoId               : INT;                                                                                                               // Intern identification number of the drive object
            statRefNo              : BYTE := BYTE#16#00;                                                                                                               // Reference number of request
            statFBState            : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_IDLE;                                                                     // States in the function block state machine
            statFBSubState         : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;                                                               // States in the function block during processing (busy state)
            statFBSubStateOld      : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;                                                               // Previous state when temporary error occurs
            statStateNumber        : LAcycCom_ReadWriteStatus;                                                                                                         // State of the FB when error occurred
            statDatasetType        : SINT := SINT#0;                                                                                                                   // Dataset type used
            statStatus             : WORD := STATUS_NO_CALL;                                                                                                           // Static value for output status
            statSubfunctionStatus  : WORD := WORD#16#0000;                                                                                                             // Block status OR error information
            statErrorCount         : UINT := UINT#16#0000;                                                                                                             // Error counter of retry request
            statAllocatedIndex     : INT := -1;                                                                                                                        // Allocated element index in the buffer DB
            statCountOfElements    : INT := 0;                                                                                                                         // Number of parameters in the dataset
            statFirstParameterError: INT := -1;                                                                                                                        // Number of parameter at which the error occurred (-1: no parameter with error)
            statDataRecordNo       : DINT;                                                                                                                             // Used data record 
            statReqParameter       : LAcycCom_TypestatstatReqParameter;                                                                                                // Request telegram
            statReqParameterInit   : LAcycCom_TypestatparameterAddress :=(attribute := BYTE#16#10, elementNo  := BYTE#16#01, parameterNo := UINT#0, index := UINT#0);

            statRespParameter: LAcycCom_TypestatRespParameter;  // Response telegram
            instWRREC        : WriteRecord;                     // WRREC command
            instRDREC        : ReadRecord;                      // RDREC command
            instIECTimer     : OnDelay;                         // IEC-Timer

            atmpSend : ARRAY[0..237]of BYTE ;
            atmpRec  : ARRAY[0..237]of BYTE ;

         END_VAR

         VAR CONSTANT
            DATA_TYPE_SILENT                    : SINT := SINT#1;        // LAcycCom_typeDriveSilentOperation is in use
            DATA_TYPE_DATASET_REAL              : SINT := SINT#2;        // LAcycCom_typeDriveDatasetReal is in use
            DATA_TYPE_DATASET_DWORD             : SINT := SINT#3;        // LAcycCom_typeDriveDatasetDWord is in use
            NO_PARAMETER_ERROR                  : INT  := INT#-1;        // No parameter error in response telegram
            ALL_ELEMENTS_OCCUPIED               : INT  := INT#-1;        // All buffer elements are occupied
            FORMAT_INTEGER_8                    : SINT := SINT#2;        // Identifier for Integer8 format
            FORMAT_INTEGER_16                   : SINT := SINT#3;        // Identifier for Integer16 format
            FORMAT_INTEGER_32                   : SINT := SINT#4;        // Identifier for Integer32 format
            FORMAT_UNSIGNED_8                   : SINT := SINT#5;        // Identifier for Unsigned8 format
            FORMAT_UNSIGNED_16                  : SINT := SINT#6;        // Identifier for Unsigned16 format
            FORMAT_UNSIGNED_32                  : SINT := SINT#7;        // Identifier for Unsigned32 format
            FORMAT_FLOATING_POINT               : SINT := SINT#8;        // Identifier for Floating Point format
            FORMAT_OCTET_STRING                 : SINT := SINT#10;       // Identifier for OctetString format
            FORMAT_TIME_DIFFERENCE              : SINT := SINT#13;       // Identifier for TimeDifference format
            FORMAT_ZERO                         : SINT := SINT#64;       // Identifier for void telegram
            FORMAT_BYTE                         : SINT := SINT#65;       // Identifier for BYTE format
            FORMAT_WORD                         : SINT := SINT#66;       // Identifier for WORD format
            FORMAT_DOUBLE_WORD                  : SINT := SINT#67;       // Identifier for Double WORD format
            FORMAT_ERROR                        : BYTE := BYTE#16#44;    // Identifier for a format error
            SILENT_OPERATION_PARA_UPPER_LIM     : INT  := 17;            // Maximum count of parameters when using Silent Operation PLC data type
            LENGTH_PARAMETER_TELEGRAM_UPPER_LIM : INT  := 233;           // Maximum length of telegram for parameter information in BYTE
            LENGTH_READ_TELEGRAM_UPPER_LIM      : INT  := 113;           // Maximum length of telegram for parameter information in BYTE
            MAX_ERROR_COUNT                     : UINT := UINT#40;       // Maximum error counter
            TIMER_TEMP_ERROR                    : Time := T#200MS;       // Waiting time until next system function block call
            TIMER_ALLOCATION                    : Time := T#10S;         // Timer limit for allocating a request element
            MAX_DRIVE_OBJECT_NO                 : INT  := 254;           // Maximum drive object number limited by SINAMICS p101
            STATUS_EXECUTION_FINISHED           : WORD := WORD#16#0000;  // Execution finished without errors
            STATUS_NO_CALL                      : WORD := WORD#16#7000;  // No call of FB
            STATUS_ALLOCATE                     : WORD := WORD#16#7001;  // FB is currently allocating a request element
            STATUS_GET_RESOURCE                 : WORD := WORD#16#7002;  // FB is waiting until it has “speaking rights”
            STATUS_BUSY                         : WORD := WORD#16#7003;  // FB is currently in processing
            STATUS_RELEASE                      : WORD := WORD#16#7004;  // FB is releasing the allocated element
            WARN_EXECUTE                        : WORD := WORD#16#7100;  // Execute input set during silent operation mode
            ERR_NO_OF_PARAMETERS                : WORD := WORD#16#8001;  // Invalid count of parameters
            ERR_INVALID_PRIORITY_CLASS          : WORD := WORD#16#8002;  // FB is NOT called in OB1
            ERR_REQUEST_REJECTED                : WORD := WORD#16#8004;  // Request rejected
            ERR_RESOURCE_RELEASED               : WORD := WORD#16#8005;  // Request is already released
            ERR_AMBIGUOUS_FB_CALL               : WORD := WORD#16#8006;  // Execute input set during processing (possible inconsistent data at output)
            ERR_INVALID_DATA_TYPE               : WORD := WORD#16#8200;  // Invalid PLC data type at the input "dataset"
            ERR_INVALID_BUF_INDEX               : WORD := WORD#16#8201;  // Buffer index is invalid
            ERR_INVALID_DRIVE_OBJECT_ID         : WORD := WORD#16#8208;  // Drive Object ID is out of range (Drive Object ID < 0 for local access, 1..254 for global access is allowed)
            ERR_COMMAND_TIMEOUT                 : WORD := WORD#16#8600;  // The assigned buffer element is no longer available for the request
            ERR_RDREC_TEMP_COUNTER              : WORD := WORD#16#8601;  // Counter for temporary errors reached the maximum during RDREC command
            ERR_WRREC_TEMP_COUNTER              : WORD := WORD#16#8602;  // Counter for temporary errors reached the maximum during WRREC command
            ERR_WRREC                           : WORD := WORD#16#8603;  // Error occurred during WRREC command
            ERR_RDREC                           : WORD := WORD#16#8604;  // Error occurred during RDREC command
            ERR_REFERENCE_NO                    : WORD := WORD#16#8605;  // Reference number of the request does NOT match the response reference number
            ERR_RESPONSE_ID                     : WORD := WORD#16#8606;  // Invalid response from the drive object
            ERR_PARAMETER_NO                    : WORD := WORD#16#8607;  // The number of parameters received does NOT match the requested number of parameters
            ERR_DRIVE_OBJECT_NO                 : WORD := WORD#16#8608;  // The drive object does NOT match the responded drive object
            ERR_ALLOCATION_TIME                 : WORD := WORD#16#8609;  // The allocation time exceeded the configured value
            ERR_MOVE_BLK_VARIANT                : WORD := WORD#16#8610;  // Error occurred during MOVE_BLK_VARIANT command
            ERR_UNDEFINED_STATE                 : WORD := WORD#16#8611;  // Error due to an undefined state
            ERR_UNDEFINED_SUBSTATE              : WORD := WORD#16#8612;  // Error due to an undefined substate
            ERR_PARAMETER                       : WORD := WORD#16#8619;  // Error in at least one parameter (see: errorValue in dataset)
         END_VAR


        METHOD ABSTRACT BUSY END_METHOD

        METHOD PUBLIC FINAL execute

            //----------------------------------------------------------------------
            // State Machine
            //----------------------------------------------------------------------

            IF NOT (statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                    statFBState = LAcycCom_ReadWriteStatus#FB_DONE OR
                    statFBState = LAcycCom_ReadWriteStatus#FB_ERROR ) THEN  // Functionality running
              CASE statFBState OF
                LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE:  // First cycle state

                    THIS.FIRST_CYCLE();

                    LAcycCom_ReadWriteStatus#FB_ALLOCATE:

                    THIS.Allocate();

                LAcycCom_ReadWriteStatus#FB_GET_RESOURCE:

                    THIS.GET_RESOURCE();

                LAcycCom_ReadWriteStatus#FB_BUSY:

                    THIS.BUSY();

                LAcycCom_ReadWriteStatus#FB_RELEASE:

                    THIS.RELEASE();

                ELSE
                  statStatus := ERR_UNDEFINED_STATE;
                  statStateNumber := statFBState;
                  statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
              END_CASE;

            END_IF;

            //----------------------------------------------------------------------
            // Error handling and write outputs
            //----------------------------------------------------------------------

            IF (statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
              // Release the allocated element when error occurs
              IF (statStateNumber <> LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE) AND (statStateNumber <> LAcycCom_ReadWriteStatus#FB_ALLOCATE)
              THEN
                statrequestBuffer.release(statAllocatedIndex);
              END_IF;
              statdiagnostics.stateNumber := statStateNumber;
              statdiagnostics.subfunctionStatus := statSubfunctionStatus;
              statdiagnostics.status := statStatus;

            END_IF;

        END_METHOD

        METHOD FINAL FIRST_CYCLE
            VAR_TEMP
                tempLoopIndex : INT;
                tempVoidDiagnostics : LAcycCom_ooptypeDriveDiagnostics;   // Temporary empty diagnostics structure
                tempVoidHeader : LAcycCom_Typestatheader;   // Temporary empty header structure
             END_VAR

              // Clearing the sending buffer
              statReqParameter.header := tempVoidHeader;
              FOR tempLoopIndex := 0 TO LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM DO
                statReqParameter.parameterAddress[tempLoopIndex] := statReqParameterInit;
              END_FOR;

              // Clearing the receive buffer
              statRespParameter.header := tempVoidHeader;
              FOR tempLoopIndex := 0 TO LENGTH_PARAMETER_TELEGRAM_UPPER_LIM DO
                statRespParameter.data[tempLoopIndex] := BYTE#16#00;
              END_FOR;

              // Initialization after start, depending on the used PLC data type

                IF statDoId < 0 THEN // V1.5
                  statDataRecordNo := 16#B02E; // Base Mode Parameter Access local; doId NOT relevant
                  statDoId := 0; //set DO to zero for use in header
                ELSIF (statDoId <= MAX_DRIVE_OBJECT_NO)
                  AND (statDoId <> 0)
                THEN // V1.5.2
                  statDataRecordNo := 47; // Data record 47; Base Mode Parameter Access global

                ELSE // V1.5.2
                  // Wrong drive object ID at input
                  statStateNumber := statFBState;
                  statStatus := ERR_INVALID_DRIVE_OBJECT_ID;
                  statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                END_IF;

                statHwId := statHwId;

              statdiagnostics := tempVoidDiagnostics;
              IF statStatus = WARN_EXECUTE THEN
                statdiagnostics.status := statStatus;
              END_IF;

              statdiagnostics.driveObjectId       := TO_USINT(statDoId);
              statdiagnostics.hardwareId          := statHwId;
              statdiagnostics.firstParameterError := statFirstParameterError;  // V1.3.2
              statdiagnostics.errorValue          := BYTE#16#FF;               // V1.3.2

              // Reference number for next request
              statRefNo := to_byte(to_int(statRefNo) + INT#1);

              IF statFBState = LAcycCom_ReadWriteStatus#FB_ERROR THEN // V1.5.2: Check IF error appeared
                ;

              // Next state is depending on the FB mode
            ELSE
                statStatus := STATUS_ALLOCATE;
                statFBState := LAcycCom_ReadWriteStatus#FB_ALLOCATE;

            END_IF;

        END_METHOD

        METHOD FINAL Allocate
                  // Allocation of a request element
                  statAllocatedIndex := statrequestBuffer.allocate(hardwareId :=statHwId);

                  IF statAllocatedIndex >= 0 THEN

                    statTimerStart := FALSE;
                    statStatus := STATUS_GET_RESOURCE;
                    statFBState := LAcycCom_ReadWriteStatus#FB_GET_RESOURCE;


                  ELSIF (instIECTimer.output = TRUE) THEN
                    statStateNumber := statFBState;
                    statStatus := ERR_ALLOCATION_TIME;
                    statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                  ELSE
                    ; // Waiting until lockbit is reset and a request element is available
                  END_IF; // (buffer.lockBuffer = FALSE) AND (buffer.actualWriteIndex >= 0)

                  instIECTimer(signal := statTimerStart,
                                duration := TIMER_ALLOCATION);

                  statTimerStart := TRUE;
                  IF (instIECTimer.output = TRUE) THEN
                    statTimerStart := FALSE;
                  END_IF;
        END_METHOD

        METHOD FINAL GET_RESOURCE
            CASE statrequestBuffer.GetRessource(statAllocatedIndex) of
                // Check buffer index for correctness
                LAcycCom_ResourceManagerRetval#ERR_INVALID_BUF_INDEX:
                  statStateNumber := statFBState;
                  statStatus := ERR_INVALID_BUF_INDEX;
                  statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                LAcycCom_ResourceManagerRetval#ERR_REQUEST_REJECTED:
                    // Request was rejected by buffer manager
                    statStateNumber := statFBState;
                    statStatus := ERR_REQUEST_REJECTED;
                    statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                LAcycCom_ResourceManagerRetval#ERR_RESOURCE_RELEASED:
                    // Request already released
                    statStateNumber := statFBState;
                    statStatus := ERR_RESOURCE_RELEASED;
                    statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                LAcycCom_ResourceManagerRetval#STATUS_BUSY:
                    // Element is enabled
                    statStatus := STATUS_BUSY;
                    statFBState := LAcycCom_ReadWriteStatus#FB_BUSY;
                    statFBSubState := LAcycCom_ReadWriteStatus#FB_GET_SUBSTATE;

                LAcycCom_ResourceManagerRetval#STATUS_GET_RESOURCE:
                    // Element NOT enabled yet
                    //
                    statStatus := STATUS_GET_RESOURCE;
                ELSE
                  ;
                END_CASE;
        end_Method

        METHOD FINAL RELEASE
                  CASE statrequestBuffer.release(statAllocatedIndex) of
                    LAcycCom_ResourceManagerRetval#ERR_INVALID_BUF_INDEX:
                      statStatus := ERR_INVALID_BUF_INDEX;
                      statStateNumber := statFBState;
                      statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                    LAcycCom_ResourceManagerRetval#STATUS_EXECUTION_FINISHED:
                      statStatus := STATUS_EXECUTION_FINISHED;
                      statFBState := LAcycCom_ReadWriteStatus#FB_DONE;
                  ELSE
                    ;
                  END_CASE;
        end_Method

        Method PUBLIC FINAL errorDiagnostics   : LAcycCom_ooptypeDrivediagnostics;
            errorDiagnostics := statdiagnostics;
        End_Method

        Method PUBLIC FINAL Status   : LAcycComstateDef;
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

                ELSE
                ;
            END_CASE;
        End_Method

        METHOD PUBLIC FINAL Config : BOOL
          VAR_INPUT
              requestBuffer : Resourcemanager;   // Connection to the request buffer of the resource manager. All LAcycCom blocks have to use the same request buffer
           END_VAR

           IF requestBuffer <> NULL THEN
            statrequestBuffer := requestBuffer;
            Config := TRUE;
           ELSE
            ;
           END_IF;

      END_METHOD
    END_CLASS

END_NAMESPACE
