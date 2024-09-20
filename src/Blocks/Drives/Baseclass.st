using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom

    CLASS ABSTRACT ReadWriteParameter
        VAR
            statrequestBuffer : Resourcemanager;   // Connection to the request buffer of the resource manager. All LAcycCom blocks have to use the same request buffer
            statdiagnostics   : LAcycCom_ooptypeDrivediagnostics;   // statdiagnostics structure
            statTimerStart   : Bool := FALSE;   // TRUE: Starts IEC-Timer
            statCmdBusy   : Bool := FALSE;   // TRUE: Process is not yet complete
            statCmdDone   : Bool := FALSE;   // TRUE: Data record was transferred
            statCmdError   : Bool := FALSE;   // TRUE: An error occurred during processing
            statHwId  : HW_IO := HW_IO#default;   // Intern hardware identifier of the hardware module
            statDoId   : Byte := byte#16#00;   // Intern identification number of the drive object
            statRefNo   : Byte := byte#16#00;   // Reference number of request
            statFBState   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_IDLE;   // States in the function block state machine
            statFBSubState   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;   // States in the function block during processing (busy state)
            statFBSubStateOld   : LAcycCom_ReadWriteStatus := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;   // Previous state when temporary error occurs
            statStateNumber   : LAcycCom_ReadWriteStatus;   // State of the FB when error occurred
            statDatasetType   : SInt := sint#0;   // Dataset type used
            statStatus   : Word := STATUS_NO_CALL;   // Static value for output status
            statSubfunctionStatus   : Word := word#16#0000;    // Block status or error information
            statErrorCount   : UInt := uint#16#0000;   // Error counter of retry request
            statAllocatedIndex   : Int := -1;   // Allocated element index in the buffer DB
            statCountOfElements   : Int := 0;   // Number of parameters in the dataset
            statFirstParameterError   : Int := -1;   // Number of parameter at which the error occurred (-1: no parameter with error)
            statDataRecordNo   : DInt;   // Used data record 
            statReqParameter   : LAcycCom_TypestatstatReqParameter;   // Request telegram
            statReqParameterInit   : LAcycCom_TypestatparameterAddress :=(attribute := byte#16#10, elementNo  := byte#16#01, parameterNo := uint#0, index := uint#0);

            statRespParameter   : LAcycCom_TypestatRespParameter;   // Response telegram
            instWRREC : writerecord;   // WRREC command
            instRDREC  : ReadRecord;   // RDREC command
            instIECTimer  : ondelay;   // IEC-Timer

            atmpSend : ARRAY[0..237]of BYTE ;
            atmpRec  : ARRAY[0..237]of BYTE ;

         END_VAR

         VAR CONSTANT
            DATA_TYPE_SILENT : SInt := SInt#1;   // LAcycCom_typeDriveSilentOperation is in use
            DATA_TYPE_DATASET_REAL : SInt := SInt#2;   // LAcycCom_typeDriveDatasetReal is in use
            DATA_TYPE_DATASET_DWORD : SInt := SInt#3;   // LAcycCom_typeDriveDatasetDWord is in use
            NO_PARAMETER_ERROR : Int := Int#-1;   // No parameter error in response telegram
            ALL_ELEMENTS_OCCUPIED : Int := Int#-1;   // All buffer elements are occupied
            FORMAT_INTEGER_8 : SInt := SInt#2;   // Identifier for Integer8 format
            FORMAT_INTEGER_16 : SInt := SInt#3;   // Identifier for Integer16 format
            FORMAT_INTEGER_32 : SInt := SInt#4;   // Identifier for Integer32 format
            FORMAT_UNSIGNED_8 : SInt := SInt#5;   // Identifier for Unsigned8 format
            FORMAT_UNSIGNED_16 : SInt := SInt#6;   // Identifier for Unsigned16 format
            FORMAT_UNSIGNED_32 : SInt := SInt#7;   // Identifier for Unsigned32 format
            FORMAT_FLOATING_POINT : SInt := SInt#8;   // Identifier for Floating Point format
            FORMAT_OCTET_STRING : SInt := SInt#10;   // Identifier for OctetString format
            FORMAT_TIME_DIFFERENCE : SInt := SInt#13;   // Identifier for TimeDifference format
            FORMAT_ZERO : SInt := SInt#64;   // Identifier for void telegram
            FORMAT_BYTE : SInt := SInt#65;   // Identifier for Byte format
            FORMAT_WORD : SInt := SInt#66;   // Identifier for Word format
            FORMAT_DOUBLE_WORD : SInt := SInt#67;   // Identifier for Double Word format
            FORMAT_ERROR : Byte := Byte#16#44;   // Identifier for a format error
            SILENT_OPERATION_PARA_UPPER_LIM : Int := 17;   // Maximum count of parameters when using Silent Operation PLC data type
            LENGTH_PARAMETER_TELEGRAM_UPPER_LIM : Int := 233;   // Maximum length of telegram for parameter information in Byte
            LENGTH_READ_TELEGRAM_UPPER_LIM : Int := 113;   // Maximum length of telegram for parameter information in Byte
            MAX_ERROR_COUNT : UInt := UInt#40;   // Maximum error counter
            TIMER_TEMP_ERROR : Time := T#200MS;   // Waiting time until next system function block call
            TIMER_ALLOCATION : Time := T#10S;   // Timer limit for allocating a request element
            MAX_DRIVE_OBJECT_NO : Int := 254;   // Maximum drive object number limited by SINAMICS p101
            STATUS_EXECUTION_FINISHED : Word := word#16#0000;   // Execution finished without errors
            STATUS_NO_CALL : Word := word#16#7000;   // No call of FB
            STATUS_ALLOCATE : Word := word#16#7001;   // FB is currently allocating a request element
            STATUS_GET_RESOURCE : Word := word#16#7002;   // FB is waiting until it has “speaking rights”
            STATUS_BUSY : Word := word#16#7003;   // FB is currently in processing
            STATUS_RELEASE : Word := word#16#7004;   // FB is releasing the allocated element
            WARN_EXECUTE : Word := word#16#7100;   // Execute input set during silent operation mode
            ERR_NO_OF_PARAMETERS : Word := word#16#8001;   // Invalid count of parameters
            ERR_INVALID_PRIORITY_CLASS : Word := word#16#8002;   // FB is not called in OB1
            ERR_REQUEST_REJECTED : Word := word#16#8004;   // Request rejected
            ERR_RESOURCE_RELEASED : Word := word#16#8005;   // Request is already released
            ERR_AMBIGUOUS_FB_CALL : Word := word#16#8006;   // Execute input set during processing (possible inconsistent data at output)
            ERR_INVALID_DATA_TYPE : Word := word#16#8200;   // Invalid PLC data type at the input "dataset"
            ERR_INVALID_BUF_INDEX : Word := word#16#8201;   // Buffer index is invalid
            ERR_INVALID_DRIVE_OBJECT_ID : Word := word#16#8208;   // Drive Object ID is out of range (Drive Object ID < 0 for local access, 1..254 for global access is allowed)
            ERR_COMMAND_TIMEOUT : Word := word#16#8600;   // The assigned buffer element is no longer available for the request
            ERR_RDREC_TEMP_COUNTER : Word := word#16#8601;   // Counter for temporary errors reached the maximum during RDREC command
            ERR_WRREC_TEMP_COUNTER : Word := word#16#8602;   // Counter for temporary errors reached the maximum during WRREC command
            ERR_WRREC : Word := word#16#8603;   // Error occurred during WRREC command
            ERR_RDREC : Word := word#16#8604;   // Error occurred during RDREC command
            ERR_REFERENCE_NO : Word := word#16#8605;   // Reference number of the request does not match the response reference number
            ERR_RESPONSE_ID : Word := word#16#8606;   // Invalid response from the drive object
            ERR_PARAMETER_NO : Word := word#16#8607;   // The number of parameters received does not match the requested number of parameters
            ERR_DRIVE_OBJECT_NO : Word := word#16#8608;   // The drive object does not match the responded drive object
            ERR_ALLOCATION_TIME : Word := word#16#8609;   // The allocation time exceeded the configured value
            ERR_MOVE_BLK_VARIANT : Word := word#16#8610;   // Error occurred during MOVE_BLK_VARIANT command
            ERR_UNDEFINED_STATE : Word := word#16#8611;   // Error due to an undefined state
            ERR_UNDEFINED_SUBSTATE : Word := word#16#8612;   // Error due to an undefined substate
            ERR_PARAMETER : Word := word#16#8619;   // Error in at least one parameter (see: errorValue in dataset)
         END_VAR


        METHOD ABSTRACT BUSY END_METHOD

        METHOD PUBLIC FINAL execute

            //----------------------------------------------------------------------
            // State Machine
            //----------------------------------------------------------------------

            IF not (statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                    statFBState = LAcycCom_ReadWriteStatus#FB_DONE or
                    statFBState = LAcycCom_ReadWriteStatus#FB_ERROR ) THEN  // Functionality running
              CASE statFBState OF
                LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE:  // First cycle state

                    This.FIRST_CYCLE();

                    LAcycCom_ReadWriteStatus#FB_ALLOCATE:

                    This.Allocate();

                LAcycCom_ReadWriteStatus#FB_GET_RESOURCE:

                    This.GET_RESOURCE();

                LAcycCom_ReadWriteStatus#FB_BUSY:

                    This.BUSY();

                LAcycCom_ReadWriteStatus#FB_RELEASE:

                    This.RELEASE();

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

        METHOD final FIRST_CYCLE
            VAR_TEMP
                tempLoopIndex : Int;
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
                statRespParameter.data[tempLoopIndex] := byte#16#00;
              END_FOR;

              // Initialization after start, depending on the used PLC data type

                IF statDoId < byte#0 THEN // V1.5
                  statDataRecordNo := 16#B02E; // Base Mode Parameter Access local; doId not relevant

                ELSIF (statDoId <= to_byte(MAX_DRIVE_OBJECT_NO))
                  AND (statDoId <> byte#0)
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

              statdiagnostics.driveObjectId := to_usint(statDoId);
              statdiagnostics.hardwareId := statHwId;
              statdiagnostics.firstParameterError := statFirstParameterError; // V1.3.2
              statdiagnostics.errorValue := byte#16#FF; // V1.3.2

              // Reference number for next request
              statRefNo := to_byte(to_int(statRefNo) + int#1);

              IF statFBState = LAcycCom_ReadWriteStatus#FB_ERROR THEN // V1.5.2: Check if error appeared
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
        end_Method

        METHOD FINAL GET_RESOURCE
            case statrequestBuffer.GetRessource(statAllocatedIndex) of
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
                    // Element not enabled yet
                    //
                    statStatus := STATUS_GET_RESOURCE;
                else
                  ;
                END_CASE;
        end_Method

        METHOD FINAL RELEASE
                  case statrequestBuffer.release(statAllocatedIndex) of
                    LAcycCom_ResourceManagerRetval#ERR_INVALID_BUF_INDEX:
                      statStatus := ERR_INVALID_BUF_INDEX;
                      statStateNumber := statFBState;
                      statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                    LAcycCom_ResourceManagerRetval#STATUS_EXECUTION_FINISHED:
                      statStatus := STATUS_EXECUTION_FINISHED;
                      statFBState := LAcycCom_ReadWriteStatus#FB_DONE;
                  else
                    ;
                  END_case;
        end_Method

        Method public FINAL errordiagnostics   : LAcycCom_ooptypeDrivediagnostics;
            errordiagnostics := statdiagnostics;
        End_Method

        Method public FINAL Status   : LAcycComstateDef;
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
        End_Method

        METHOD PUBLIC FINAL Config : Bool
          VAR_INPUT
              requestBuffer : Resourcemanager;   // Connection to the request buffer of the resource manager. All LAcycCom blocks have to use the same request buffer
           END_VAR

           statrequestBuffer := requestBuffer;

      END_METHOD
    END_CLASS

END_NAMESPACE
