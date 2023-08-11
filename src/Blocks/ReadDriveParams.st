using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom
    FUNCTION_BLOCK LAcycCom_ReadDriveParams

       VAR_INPUT 
          execute : Bool;   // TRUE: Rising edge starts the functionality once
          parameterCount : Int := -1;   // Count of parameters to read (-1: read all parameter in dataset)
          driveObjectId : Int := -1;   // Optional: Identification number of the drive object (value <0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
          hardwareId : HW_IO;   // Hardware identifier of the hardware module
       END_VAR
    
       VAR_OUTPUT 
          done   : Bool;   // TRUE: Finished reading all parameters
          busy   : Bool;   // TRUE: FB is not finished and new output values can be expected
          error   : Bool;   // TRUE: Rising edge informs that an error occurred during the execution of the FB
          status   : Word := STATUS_NO_CALL;   // Status identifier
          diagnostics   : LAcycCom_typeDriveDiagnostics;   // Diagnostics structure
       END_VAR
    
       VAR_IN_OUT 
          requestBuffer : LAcycCom_typeRequestBuffer;   // Connection to the request buffer of the resource manager. All LAcycCom blocks have to use the same request buffer
          dataset : Array[0..typeconstantsint#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_typeDriveDatasetReal;   // Dataset with all parameters to be read
       END_VAR
    
       VAR 
          statExecuteOld   : Bool := FALSE;   // TRUE: Indicates that the execute input in the previous cycle was set
          statBusy   : Bool := FALSE;   // Static value for output busy
          statDone   : Bool := FALSE;   // Static value for output done
          statError   : Bool := FALSE;   // Static value for output error
          statCmdBusy   : Bool := FALSE;   // TRUE: Process is not yet complete
          statCmdDone   : Bool := FALSE;   // TRUE: Data record was transferred
          statCmdError   : Bool := FALSE;   // TRUE: An error occurred during processing
          statTimerStart   : Bool := FALSE;   // TRUE: Starts IEC-Timer
          statHwId  : HW_IO := HW_IO#default;   // Intern hardware identifier of the hardware module
          statDoId   : Byte := byte#16#00;   // Intern identification number of the drive object
          statRefNo   : Byte := byte#16#00;   // Reference number of request
          statWithoutResourceManager   : Bool := FALSE;   // TRUE: No resource manager available; FALSE: Resource manager available
          statFBState   : SInt := FB_IDLE;   // States in the function block state machine
          statFBSubState   : SInt := FB_BUSY_WRREC;   // States in the function block during processing (busy state)
          statFBSubStateOld   : SInt := FB_BUSY_WRREC;   // Previous state when temporary error occurs
          statStateNumber   : SInt := sint#0;   // State of the FB when error occurred
          statDatasetType   : SInt := sint#0;   // Dataset type used
          statStatus   : Word := STATUS_NO_CALL;   // Static value for output status
          statSubfunctionStatus   : Word := word#16#0000;   // Block status or error information
          statErrorCount   : UInt := uint#16#0000;   // Error counter of retry request
          statAllocatedIndex   : Int := 0;   // Allocated element index in the buffer DB
          statCountOfElements   : Int := 0;   // Number of parameters in the dataset
          statFirstParameterError   : Int := -1;   // Number of parameter at which the error occurred (-1: no parameter with error)
          statWarningRetriggering   : Bool;   // TRUE: Input execute is set during processing
          statDataRecordNo   : DInt;   // Used data record
          statParameter   : Array[0..typeconstantsint#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatstatParameter;   // Parameter dataset
          statReqParameter   : LAcycCom_TypestatstatReqParameter;   // Request telegram
          parameterAddress   : Array[0..typeconstantsint#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatparameterAddress;   // Parameter data in telegram
          statReqParameterInit   : LAcycCom_TypestatparameterAddress :=(attribute := byte#16#10, elementNo  := byte#16#01, parameterNo := uint#0, index := uint#0);
         // statReqParameterInit   : LAcycCom_TypestatReqParameterInit;   // Initialisation of the parameter dataset

          statRespParameter   : LAcycCom_TypestatRespParameter;   // Response telegram
          instWRREC : writerecord;   // WRREC command
          instRDREC  : ReadRecord;   // RDREC command
          instIECTimer  : ondelay;   // IEC-Timer

          atmpSend : ARRAY[0..237]of BYTE ;
          atmpRec  : ARRAY[0..237]of BYTE ;

       END_VAR
    
       VAR_TEMP 
          tempExecute : Bool;   // TRUE: Indicates that the execute input was set
          tempCmdValid : Bool;   // TRUE: New data record was received and is valid
          tempStatusWord : Word;   // Temporary status
          tempWord : Word;   // Temporary word variable
          tempParameterCount : Int;   // Temporary variable of the output parameterCount
          tempPointer : Int;   // Temporary pointer variable
          tempLoopIndex : Int;   // Temporary loop index variable
          tempBlkVariant : Int;   // Temporary result of MOVE_BLK_VARIANT
          tempLastQueueElement : Int;   // Last element in queue
          tempCmdStatus : DWord;   // Temporary status of WRREC and RDREC command
          tempDWord : DWord;   // Temporary DWord variable
          tempVoidDiagnostics : LAcycCom_typeDriveDiagnostics;   // Temporary empty diagnostics structure
          tempActualElementReal : LAcycCom_typeDriveDatasetReal;   // Temporary element of the dataset (real values)
          tempActualElementDWord : LAcycCom_typeDriveDatasetDWord;   // Temporary element of the dataset (double word values)
          tempSilentOperationData : LAcycCom_typeDriveSilentOperation;   // Data for silent mode configuration
          tempVoidHeader : LAcycCom_Typestatheader;   // Temporary empty header structure
          tempDatasetRealValue : Array[0..1] of LAcycCom_typeDriveDatasetReal;   // Temporary dataset variable for comparing purpose (with real values)
        //  tempDatasetDWordValue : Array[0..1] of LAcycCom_typeDriveDatasetDWord;   // Temporary dataset variable for comparing purpose (with dword values)
       END_VAR
    
       VAR CONSTANT 
          DATA_TYPE_SILENT : SInt := SInt#1;   // LAcycCom_typeDriveSilentOperation is in use
          DATA_TYPE_DATASET_REAL : SInt := SInt#2;   // LAcycCom_typeDriveDatasetReal is in use
          DATA_TYPE_DATASET_DWORD : SInt := SInt#3;   // LAcycCom_typeDriveDatasetDWord is in use
          MODE_WITH_RESOURCE_MANAGER : USInt := USInt#0;   // Processing with ResourceManager
          MODE_WITHOUT_RESOURCE_MANAGER : USInt := USInt#1;   // Processing without ResourceManager
          NO_PARAMETER_ERROR : Int := Int#-1;   // No parameter error in response telegram
          ALL_ELEMENTS_OCCUPIED : Int := Int#-1;   // All buffer elements are occupied
          FB_IDLE : SInt := SInt#0;   // Idle state in FB
          FB_FIRST_CYCLE : SInt := SInt#1;   // First cycle state in FB
          FB_ALLOCATE : SInt := SInt#2;   // Allocating a request element in request buffer DB
          FB_GET_RESOURCE : SInt := SInt#3;   // State to check if the communication to the drive object can be established
          FB_BUSY : SInt := SInt#4;   // Busy state in FB
          FB_RELEASE : SInt := SInt#5;   // State to return the allocated index
          FB_DONE : SInt := SInt#6;   // Done state in FB
          FB_ERROR : SInt := SInt#7;   // Error state in FB
          FB_BUSY_WRREC : SInt := SInt#8;   // WRREC in busy state
          FB_BUSY_RDREC : SInt := SInt#9;   // RDREC in busy state
          FB_BUSY_WAIT : SInt := SInt#10;   // State when temporary error occurred
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
          SILENT_OPERATION_PARA_UPPER_LIM : Int := 17;   // Maximum count of parameters when using Silent Operation PLC data type
          LENGTH_PARAMETER_TELEGRAM_UPPER_LIM : Int := 233;   // Maximum length of telegram for parameter information in Byte
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
          WARN_EXECUTE_SET_DURING_PROCESSING : Word := word#16#7101;   // Execute input set during processing
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
    
    
   
        //==========================================================================================
        // SIEMENS AG
        // (c)Copyright 2020 All Rights Reserved
        //------------------------------------------------------------------------------------------
        // Library: LAcycCom
        // Tested with: S7-1513-1 PN
        // Engineering: TIA Portal V15
        // Restrictions: ---
        // Requirements: S7-1200 / S7-1500
        //               FB LAcycCom_ResourceManager is required
        // Functionality: Reads parameters from a drive object according to the configured dataset 
        //------------------------------------------------------------------------------------------
        // Change log table:
        // Version    Date          Expert in charge    Changes applied
        // 01.00.00   05.05.2015    AW                  release
        // 01.01.00   27.01.2016    AW                  values of MAX_ERROR_COUNT and TIMER_TEMP_ERROR changed
        // 01.03.00   05.07.2016    AL                  output added: diagnostics.status
        //                                              bugfix error handling (if execute input is set only for 1 cycle)
        // 01.03.01   21.11.2016    AL                  prevent reentrant calls (added warning WARN_EXECUTE_SET_DURING_PROCESSING
        //                                                                       and error ERR_AMBIGUOUS_FB_CALL)  
        // 01.03.02   22.11.2017    AL                  added handling of error 80A0 (RDREC)
        //                                              added handling of error 80A1 (WRREC)
        //                                              added errorValue to "LAcycCom_typeDriveDiagnostics"
        // 01.03.03   13.03.2018    AL                  values of MAX_ERROR_COUNT and TIMER_TEMP_ERROR changed
        // 01.05.00   31.10.2018    AL                  added support of Base Mode Parameter Access local (16#B02E)
        //                                              (driveObjectId < 0: local, driveObjectId >= 0: Base Mode Parameter Access global via dataset 47)
        //                                              input 'driveObjectId' data type changed from USInt to Int
        //                                              changed handling of OCTET_STRING format
        // 01.05.01   11.10.2019    AL                  bugfix lockBuffer
        // 01.05.02   19.05.2020    CR                  new errorId when input 'driveObjectId' is out of range
        // 
        //------------------------------------------------------------------------------------------
        // Function block: LAcycCom_ReadDriveParams
        //===========================================================================================
        //
        
        //----------------------------------------------------------------------
        // Determine which PLC data type for readDataset is in use
        //----------------------------------------------------------------------
        
       // IF (TypeOf(dataset) = TypeOf(tempDatasetRealValue)) OR (TypeOf(dataset) = TypeOf(tempDatasetDWordValue)) THEN
          tempExecute := execute;

       (*  ELSIF (TypeOf(dataset) = LAcycCom_typeDriveSilentOperation) THEN
          tempBlkVariant := MOVE_BLK_VARIANT(SRC := dataset, COUNT := 1, SRC_INDEX := 0, DEST_INDEX := 0, DEST => tempSilentOperationData);
          
          // Error occurred during MOVE_BLK_VARIANT command
          IF (tempBlkVariant <> 0) THEN
            statError := TRUE;
            statStateNumber := statFBState;
            statSubfunctionStatus := TO_WORD(tempBlkVariant);
            statStatus := ERR_MOVE_BLK_VARIANT;
            statFBState := FB_ERROR;
          END_IF;
          
          tempExecute := tempSilentOperationData.functionBlockCommand.%X0;
          
          // Input execute is set during silent operation
          IF (execute = TRUE) AND (statError = FALSE) THEN
            statStatus := WARN_EXECUTE;
            diagnostics.status := statStatus;
          END_IF;
          
        ELSE
          statError := TRUE;
          statStateNumber := statFBState;
          statStatus := ERR_INVALID_DATA_TYPE;
          statFBState := FB_ERROR;
        END_IF;
        *)
        //----------------------------------------------------------------------
        // Processing
        //----------------------------------------------------------------------
        // Rising edge of execute starts functionality
        IF (tempExecute = TRUE) AND (statExecuteOld = FALSE) AND (statBusy = TRUE) THEN
          // Input execute is set during processing
          statStatus := WARN_EXECUTE_SET_DURING_PROCESSING;
          statWarningRetriggering := TRUE;
          
        ELSIF (tempExecute = TRUE) AND (statExecuteOld = FALSE) THEN
          // First call
          // Initialisation
          statDone := FALSE;
          statBusy := TRUE;
          statError := FALSE;
          statCountOfElements := 0;
          statAllocatedIndex := 0;
          statHwId := WORD#16#0;
          statSubfunctionStatus := word#16#0;
          statDoId := byte#0;
          statDataRecordNo := dint#0;
          statStateNumber := SINT#0;
          statDatasetType := SINT#0;
          statFirstParameterError := -1;
          statCmdBusy := FALSE;
          statCmdDone := FALSE;
          statCmdError := FALSE;
          statErrorCount := uint#0;
          statWarningRetriggering := FALSE;
          statFBSubState := FB_BUSY_WRREC;
          statFBState := FB_FIRST_CYCLE;
          
          instIECTimer(signal := FALSE,
                        duration := TIMER_ALLOCATION);
          
          // FB is currently inactive  
        ELSIF (tempExecute = FALSE) AND (statBusy = FALSE)
        THEN
          statError := FALSE;
          statBusy := FALSE;
          statDone := FALSE;
          statFBState := FB_IDLE;
          
          IF ((statStatus = WARN_EXECUTE) AND (execute = FALSE)) OR (statStatus <> WARN_EXECUTE) THEN
            statStatus := STATUS_NO_CALL;
          END_IF;
          
        END_IF; // tempExecute AND statExecuteOld = FALSE

        //----------------------------------------------------------------------
        // State Machine
        //----------------------------------------------------------------------
        
        IF (statBusy = TRUE) AND (statError = FALSE) THEN  // Functionality running
          CASE statFBState OF
            FB_FIRST_CYCLE:  // First cycle state
              
              // Determine which PLC data type for readDataset is in use
             // IF (TypeOf(dataset) = TypeOf(tempDatasetRealValue)) THEN
                statDatasetType := DATA_TYPE_DATASET_REAL;
                (* 
              ELSIF (TypeOf(dataset) = TypeOf(tempDatasetDWordValue)) THEN
                statDatasetType := DATA_TYPE_DATASET_DWORD;
                
              ELSIF (TypeOf(dataset) = LAcycCom_typeDriveSilentOperation) THEN
                statDatasetType := DATA_TYPE_SILENT;
              END_IF;
              *)
              // Clearing the sending buffer
              statReqParameter.header := tempVoidHeader;
              FOR tempLoopIndex := 0 TO typeconstantsint#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM DO
                statReqParameter.parameterAddress[tempLoopIndex] := statReqParameterInit;
              END_FOR;
              
              // Clearing the receive buffer
              statRespParameter.header := tempVoidHeader;
              FOR tempLoopIndex := 0 TO LENGTH_PARAMETER_TELEGRAM_UPPER_LIM DO
                statRespParameter.data[tempLoopIndex] := byte#16#00;
              END_FOR;
              
              // Initialization after start, depending on the used PLC data type
              
              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_DATASET_DWORD) THEN
                IF driveObjectId < 0 THEN // V1.5
                  statDataRecordNo := 16#B02E; // Base Mode Parameter Access local; doId not relevant
                  statDoId := byte#0;
                  
                ELSIF (driveObjectId <= MAX_DRIVE_OBJECT_NO)
                  AND (driveObjectId <> 0)
                THEN // V1.5.2
                  statDataRecordNo := 47; // Data record 47; Base Mode Parameter Access global
                  statDoId := TO_BYTE(driveObjectId);
                  
                ELSE // V1.5.2 
                  // Wrong drive object ID at input
                  statError := TRUE;
                  statStateNumber := statFBState;
                  statStatus := ERR_INVALID_DRIVE_OBJECT_ID;
                  statFBState := FB_ERROR;
                END_IF;
                
                statHwId := hardwareId;
                tempParameterCount := parameterCount;
              ELSE
                IF tempSilentOperationData.driveObjectId < 0 THEN // V1.5
                  statDataRecordNo := 16#B02E; // Base Mode Parameter Access local; doId not relevant
                  statDoId := byte#0;
                ELSE
                  statDataRecordNo := 47; // Data record 47; Base Mode Parameter Access global
                  statDoId := TO_BYTE(tempSilentOperationData.driveObjectId);
                END_IF;
                statHwId := tempSilentOperationData.hardwareId;
                tempParameterCount := tempSilentOperationData.parameterCount;
              END_IF;
              
              diagnostics := tempVoidDiagnostics;
              IF statStatus = WARN_EXECUTE THEN
                diagnostics.status := statStatus;
              END_IF;
              
              diagnostics.driveObjectId := to_usint(statDoId);
              diagnostics.hardwareId := statHwId;
              diagnostics.firstParameterError := statFirstParameterError; // V1.3.2
              diagnostics.errorValue := byte#16#FF; // V1.3.2
              
              // Reference number for next request
              statRefNo := to_byte(to_int(statRefNo) + int#1);
              
              IF statError THEN // V1.5.2: Check if error appeared
                ;
              
              // Next state is depending on the FB mode
              ELSIF (statWithoutResourceManager = FALSE) THEN
                statStatus := STATUS_ALLOCATE;
                statFBState := FB_ALLOCATE;
                
              ELSE
                statStatus := STATUS_BUSY;
                statFBState := FB_BUSY;
                statFBSubState := FB_BUSY_WRREC;
              END_IF;
              
              // Calculates the amount of parameters (only if no error occurs)
               IF (statError = FALSE) THEN
              (*   IF (statDatasetType = DATA_TYPE_SILENT) THEN
                  // Check if 0 < parameterCount <= 18
                  IF (tempParameterCount > 0) AND (tempParameterCount <= SILENT_OPERATION_PARA_UPPER_LIM + 1) THEN
                    statCountofElements := tempParameterCount;
                    diagnostics.parameterCount := statCountOfElements;
                    
                  ELSE
                    statError := TRUE;
                    statStateNumber := statFBState;
                    statStatus := ERR_NO_OF_PARAMETERS;
                    statFBState := FB_ERROR;
                  END_IF; // tempParameterCount <= MAX_NO_OF_PARAMETERS
                  *)
               // ELSE
                  If tempParameterCount > 1 Then
                    statCountOfElements := tempParameterCount;
                    else  
                    FOR tempLoopIndex := 0 TO typeconstantsint#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM DO
                      If dataset[tempLoopIndex].parameterNumber = uint#0 and tempParameterCount <= 0 Then 
                        tempParameterCount := tempLoopIndex;
                        statCountOfElements := tempLoopIndex;
                      end_if;
                    END_FOR;
                  end_IF;
                  // Calculates the count of elements in readDataset if numberOfParameters < 1
      (*             IF (tempParameterCount < 1) AND
                    (statCountElements <= READ_PARAMETERS_UPPER_LIM + 1) AND
                    (typeconstantsint#LACYCCOM_READ_PARAMETERS_UPPER_LIM <= READ_PARAMETERS_UPPER_LIM)
                  THEN
                    statCountOfElements := statCountElements;
                    diagnostics.parameterCount := statCountOfElements;
                    
                  ELSIF (tempParameterCount >= 1) AND  // V1.3.2
                    // Check if numberOfParameters <= 39
                    (tempParameterCount <= READ_PARAMETERS_UPPER_LIM + 1) AND
                    (statCountElements >= tempParameterCount) AND
                    (typeconstantsint#LACYCCOM_READ_PARAMETERS_UPPER_LIM <= READ_PARAMETERS_UPPER_LIM)
                  THEN
                    statCountOfElements := tempParameterCount;
                    diagnostics.parameterCount := statCountOfElements;
                    
                  ELSE
                    statError := TRUE;
                    statStateNumber := statFBState;
                    statStatus := ERR_NO_OF_PARAMETERS;
                    statFBState := FB_ERROR;
                  END_IF;
                //END_IF; // tempDatasetType = DATA_TYPE_SILENT *)
              END_IF; // IF (statError = FALSE)
             // *)
             //statCountOfElements:= 2;
            FB_ALLOCATE:
              // Allocation of a request element
              IF (requestBuffer.header.lockBuffer = FALSE) AND (requestBuffer.header.nextFreeElement >= 0) AND (requestBuffer.header.nextFreeElement <= typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
                requestBuffer.header.lockBuffer := TRUE;
                statAllocatedIndex := requestBuffer.header.nextFreeElement;
                requestBuffer.elements[statAllocatedIndex].state := byte#16#00;
                requestBuffer.elements[statAllocatedIndex].state.%X0 := TRUE;
                requestBuffer.elements[statAllocatedIndex].hardwareId := statHwId;
                requestBuffer.elements[statAllocatedIndex].queueElementNext := -1;
                statTimerStart := FALSE;
                statStatus := STATUS_GET_RESOURCE;
                statFBState := FB_GET_RESOURCE;
                
                // Build up queue
                IF (requestBuffer.header.firstQueueElement >= 0) THEN
                  // Find last queue element 
                  tempLoopIndex := requestBuffer.header.firstQueueElement;
                  WHILE (tempLoopIndex >= 0) DO
                    tempLastQueueElement := tempLoopIndex;
                    tempLoopIndex := requestBuffer.elements[tempLoopIndex].queueElementNext;
                  END_WHILE;
                  
                  // Insert into list after last element
                  requestBuffer.elements[tempLastQueueElement].queueElementNext := statAllocatedIndex;
                  requestBuffer.elements[statAllocatedIndex].queueElementPrevious := tempLastQueueElement;
                ELSE
                  // Element is first element in queue
                  requestBuffer.header.firstQueueElement := statAllocatedIndex;
                  requestBuffer.elements[statAllocatedIndex].queueElementPrevious := -1;
                END_IF;
                
                // Searching for the next free request element
                FOR tempLoopIndex := 0 TO typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM DO
                  IF (requestBuffer.elements[tempLoopIndex].state.%X0 = FALSE) THEN
                    requestBuffer.header.nextFreeElement := tempLoopIndex;
                    EXIT;
                  END_IF;
                  
                  // All request elements are occupied
                  IF (tempLoopIndex = typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
                    requestBuffer.header.nextFreeElement := ALL_ELEMENTS_OCCUPIED;
                  END_IF;
                END_FOR;
                
                requestBuffer.header.lockBuffer := FALSE;
                
                
              ELSIF (instIECTimer.output = TRUE) THEN
                statError := TRUE;
                statStateNumber := statFBState;
                statStatus := ERR_ALLOCATION_TIME;
                statFBState := FB_ERROR;
                
              ELSE
                ; // Waiting until lockbit is reset and a request element is available
              END_IF; // (buffer.lockBuffer = FALSE) AND (buffer.actualWriteIndex >= 0)
              
              instIECTimer(signal := statTimerStart,
                            duration := TIMER_ALLOCATION);
              
              statTimerStart := TRUE;
              IF (instIECTimer.output = TRUE) THEN
                statTimerStart := FALSE;
              END_IF;
              
            FB_GET_RESOURCE:
              
              // Check buffer index for correctness
              IF (statAllocatedIndex < 0) OR (statAllocatedIndex > typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
                statError := TRUE;
                statStateNumber := statFBState;
                statStatus := ERR_INVALID_BUF_INDEX;
                statFBState := FB_ERROR;
                
              ELSE
                IF (requestBuffer.elements[statAllocatedIndex].state.%X0 = FALSE) OR
                  (requestBuffer.elements[statAllocatedIndex].state.%X3 = TRUE)
                THEN
                  // Request was rejected by buffer manager
                  statError := TRUE;
                  statStateNumber := statFBState;
                  statStatus := ERR_REQUEST_REJECTED;
                  statFBState := FB_ERROR;
                  
                ELSIF (requestBuffer.elements[statAllocatedIndex].state.%X2 = TRUE) THEN
                  // Request already released
                  statError := TRUE;
                  statStateNumber := statFBState;
                  statStatus := ERR_RESOURCE_RELEASED;
                  statFBState := FB_ERROR;
                  
                ELSIF (requestBuffer.elements[statAllocatedIndex].state.%X1 = TRUE) THEN
                  // Element is enabled
                  statStatus := STATUS_BUSY;
                  statFBState := FB_BUSY;
                  statFBSubState := FB_BUSY_WRREC;
                  
                ELSE
                  // Element not enabled yet
                  // 
                  statStatus := STATUS_GET_RESOURCE;
                END_IF;
                
              END_IF;
              
            FB_BUSY:
              
              IF ((requestBuffer.elements[statAllocatedIndex].state.%X1 = TRUE) AND (statWithoutResourceManager = FALSE) AND
                (requestBuffer.elements[statAllocatedIndex].state.%X3 = FALSE)) OR (statWithoutResourceManager = TRUE)
              THEN
                CASE statFBSubState OF
                  FB_BUSY_WRREC:  // Writing the dataset configuration into the drive object
                    
                    IF (statCmdBusy = FALSE) THEN
                      // Resets WRREC command
                      instWRREC(request := FALSE,
                                RECORD := atmpRec);
                      // Creating header data
                      statReqParameter.header.refNo := statRefNo; // Telegram reference number
                      statReqParameter.header.reqId := byte#16#01;  // 0x01 = request parameters
                      statReqParameter.header.doId := statDoId;  // Drive object identification number
                      statReqParameter.header.parameterNo := TO_BYTE(statCountOfElements);  // Count of parameters
                      
                      // Copying the dataset into a static variable (depending on the used PLC data type)
                    (*   IF (statDatasetType = DATA_TYPE_SILENT) THEN
                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 DO
                          statParameter[tempLoopIndex].index := tempSilentOperationData.dataset[tempLoopIndex].index;
                          statParameter[tempLoopIndex].parameterNo := tempSilentOperationData.dataset[tempLoopIndex].parameterNumber;
                          statReqParameter.parameterAddress[tempLoopIndex].parameterNo := statParameter[tempLoopIndex].parameterNo;  // Parameter number     
                          statReqParameter.parameterAddress[tempLoopIndex].index := statParameter[tempLoopIndex].index;  // Subindex of parameter
                        END_FOR;
                        
                      ELSIF (statDatasetType = DATA_TYPE_DATASET_REAL) THEN
                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 DO*)
                        //  tempBlkVariant := MOVE_BLK_VARIANT(SRC := dataset, COUNT := 1, SRC_INDEX := tempLoopIndex, DEST_INDEX := 0, DEST => tempActualElementReal);
                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 DO
                          tempActualElementReal := dataset[tempLoopIndex];
                          (* 
                          // Error occurred during MOVE_BLK_VARIANT command
                          IF (tempBlkVariant <> 0) THEN
                            statError := TRUE;
                            statStateNumber := statFBSubState;
                            statSubfunctionStatus := TO_WORD(tempBlkVariant);
                            statStatus := ERR_MOVE_BLK_VARIANT;
                            statFBState := FB_ERROR;
                            diagnostics.firstParameterError := tempLoopIndex;
                            EXIT;
                          END_IF;
                          *)
                          statParameter[tempLoopIndex].index := tempActualElementReal.index;
                          statParameter[tempLoopIndex].parameterNo := tempActualElementReal.parameterNumber;
                          statReqParameter.parameterAddress[tempLoopIndex].parameterNo := statParameter[tempLoopIndex].parameterNo;  // Parameter number    
                          statReqParameter.parameterAddress[tempLoopIndex].index := statParameter[tempLoopIndex].index;  // Subindex of parameter
                       END_FOR;
                      (*   // If DATA_TYPE_DATASET_DWORD is in use   
                      ELSE
                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 DO
                          tempBlkVariant := MOVE_BLK_VARIANT(SRC := dataset, COUNT := 1, SRC_INDEX := tempLoopIndex, DEST_INDEX := 0, DEST => tempActualElementDWord);
                          
                          // Error occurred during MOVE_BLK_VARIANT command
                          IF (tempBlkVariant <> 0) THEN
                            statError := TRUE;
                            statStateNumber := statFBSubState;
                            statSubfunctionStatus := TO_WORD(tempBlkVariant);
                            statStatus := ERR_MOVE_BLK_VARIANT;
                            statFBState := FB_ERROR;
                            diagnostics.firstParameterError := tempLoopIndex;
                            EXIT;
                          END_IF;
                          
                          statParameter[tempLoopIndex].index := tempActualElementDWord.index;
                          statParameter[tempLoopIndex].parameterNo := tempActualElementDWord.parameterNumber;
                          statReqParameter.parameterAddress[tempLoopIndex].parameterNo := statParameter[tempLoopIndex].parameterNo;  // Parameter number    
                          statReqParameter.parameterAddress[tempLoopIndex].index := statParameter[tempLoopIndex].index;  // Subindex of parameter
                        END_FOR;
                      END_IF; *)// tempDatasetType = DATA_TYPE_SILENT
                    END_IF; // statCmdBusy = FALSE
                    SerializeBig(uint#0,
                                statReqParameter,
                                atmpSend );
                    // WRREC command
                    instWRREC(REQUEST := TRUE,                                                 // Transfer data record
                               ID := hardwareId,                                                 // ID number of the hardware component
                               INDEX := statDataRecordNo,                                                     // Data record number
                               LENGTH := uint#0,                                                        // Maximum length of the data record to be transferred in bytes         
                               DONE => statCmdDone,                                            // Data record was transferred          
                               BUSY => statCmdBusy,                                            // The writing process is not yet complete
                               ERROR => statCmdError,                                          // An error occurred during the writing process
                               STATUS => tempCmdStatus,                                        // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                               RECORD := atmpSend);                                    // Data record     
                            
                        
                    // Error occurred
                    IF (statCmdError = TRUE) AND (statError = FALSE) THEN
                      tempStatusWord.%B0 := tempCmdStatus.%B1;
                      tempStatusWord.%B1 := tempCmdStatus.%B2;
                      
                      //Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                      IF (tempStatusWord = word#16#80A1) OR  // Negative acknowledgment when writing to the module
                        (tempStatusWord = word#16#80A7) OR   // DP slave or module is occupied (temporary error)
                        (tempStatusWord = word#16#80B5) OR   // DP slave or module not ready             
                        (tempStatusWord = word#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
                        (tempStatusWord = word#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.      
                        (tempStatusWord = word#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                        (tempStatusWord = word#16#80C3) OR   // The required operating resources are currently occupied.
                        (tempStatusWord = word#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.
                        
                        IF (statErrorCount >= MAX_ERROR_COUNT) THEN
                          statError := TRUE;
                          statStateNumber := statFBSubState;
                          statSubfunctionStatus := tempStatusWord;
                          statStatus := ERR_WRREC_TEMP_COUNTER;
                          statFBState := FB_ERROR;
                        ELSE
                          statErrorCount := statErrorCount + uint#1;  // Increment internal error counter
                          statFBSubStateOld := FB_BUSY_WRREC;
                          statFBSubState := FB_BUSY_WAIT;
                        END_IF;
                      ELSE
                        statError := TRUE;
                        statStateNumber := statFBSubState;
                        statSubfunctionStatus := tempStatusWord;
                        statStatus := ERR_WRREC;
                        statFBState := FB_ERROR;
                      END_IF;
                      
                    ELSIF (statCmdDone = TRUE) AND (statError = FALSE) THEN  // Processing completed without errors
                      statErrorCount := uint#0;  // V1.5.1 Reset error counter
                      statFBSubState := FB_BUSY_RDREC; // WRREC completed and continue with RDREC        
                    END_IF; // statCmdError = TRUE
                    
                  FB_BUSY_RDREC:  // Reading the values from the drive object
                    // Resets RDREC command
                    IF (statCmdBusy = FALSE) THEN
                      instRDREC(REQUEST := FALSE,
                                 RECORD := atmpRec);
                    END_IF;
                    
                    instRDREC(REQUEST := True,                                                 // Transfer data record
                               ID := statHwId,                                                 // ID number of the hardware component        
                               INDEX := statDataRecordNo,                                                     // Data record number
                               MAXLENGTH := uint#0,                                                        // Maximum length in bytes of the data record information to be read
                               VALID => tempCmdValid,                                          // New data record was received and is valid   
                               BUSY => statCmdBusy,                                            // The reading process is not yet complete
                               ERROR => statCmdError,                                          // An error occurred during the reading process
                               STATUS => tempCmdStatus,                                        // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code 
                               RECORD := atmpRec);                                   // Destination area for the data record read

                               
                    DeserializeBig(uint#0,
                               atmpRec,
                               statRespParameter);
                    // Error occurred
                    IF (statCmdError = TRUE) THEN
                      // Get the error information from the status information
                      tempStatusWord.%B0 := tempCmdStatus.%B1;
                      tempStatusWord.%B1 := tempCmdStatus.%B2;
                      
                      //Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                      IF (tempStatusWord = word#16#80A0) OR  // Negative acknowledgment when reading the module
                        (tempStatusWord = word#16#80A7) OR   // DP slave or module is occupied (temporary error)
                        (tempStatusWord = word#16#80B5) OR   // DP slave or module not ready             
                        (tempStatusWord = word#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
                        (tempStatusWord = word#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.      
                        (tempStatusWord = word#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                        (tempStatusWord = word#16#80C3) OR   // The required operating resources are currently occupied.
                        (tempStatusWord = word#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.
                        
                        IF (statErrorCount >= MAX_ERROR_COUNT) THEN
                          statError := TRUE;
                          statStateNumber := statFBSubState;
                          statSubfunctionStatus := tempStatusWord;
                          statStatus := ERR_RDREC_TEMP_COUNTER;
                          statFBState := FB_ERROR;
                        ELSE
                          statErrorCount := statErrorCount + uint#1;  // Increment internal error counter
                          statFBSubStateOld := FB_BUSY_RDREC;
                          // V1.3.2. If error 80A0 then should be retry with WRREC command
                          IF (tempStatusWord = word#16#80A0) THEN
                            statFBSubStateOld := FB_BUSY_WRREC;
                          END_IF;
                          statFBSubState := FB_BUSY_WAIT;
                        END_IF; // statErrorCount >= MAX_ERROR_COUNT
                      ELSE
                        statError := TRUE;
                        statStateNumber := statFBSubState;
                        statSubfunctionStatus := tempStatusWord;
                        statStatus := ERR_RDREC;
                        statFBState := FB_ERROR;
                      END_IF;
                      
                      // Error : Reference number of the request does not match with the response reference number 
                    ELSIF (statCmdBusy = FALSE) AND
                      (statRefNo <> statRespParameter.header.refNo) AND
                      (tempCmdValid = TRUE) THEN
                      
                      statError := TRUE;
                      statStateNumber := statFBSubState;
                      statStatus := ERR_REFERENCE_NO;
                      statFBState := FB_ERROR;
                      
                      // Error : Invalid response from the drive object (reqId: 16#01 - reading parameter successful; 16#81: reading parameter finished with error)  
                    ELSIF NOT (statRespParameter.header.reqId = byte#16#81 OR statRespParameter.header.reqId = byte#16#01) AND
                      (statCmdBusy = FALSE) AND
                      (tempCmdValid = TRUE) THEN
                      statError := TRUE;
                      statStateNumber := statFBSubState;
                      statStatus := ERR_RESPONSE_ID;
                      statFBState := FB_ERROR;
                      
                      // Error : The received number of parameters does not match with the requested number of parameters
                    ELSIF (statCmdBusy = FALSE) AND
                      (statCountOfElements <> TO_INT(statRespParameter.header.parameterNo)) AND
                      (tempCmdValid = TRUE) THEN
                      
                      statError := TRUE;
                      statStateNumber := statFBSubState;
                      statStatus := ERR_PARAMETER_NO;
                      statFBState := FB_ERROR;
                      
                      // Error : The drive object does not match with the responsed DO
                    ELSIF (statCmdBusy = FALSE) AND
                      (statDoId <> statRespParameter.header.doId) AND
                      (tempCmdValid = TRUE) THEN
                      
                      statError := TRUE;
                      statStateNumber := statFBSubState;
                      statStatus := ERR_DRIVE_OBJECT_NO;
                      statFBState := FB_ERROR;
                      
                      // No error occurred during reading parameters
                    ELSIF (tempCmdValid = TRUE) THEN
                      // Analyse of the response buffer
                      tempPointer := 0;
                      FOR tempLoopIndex := 0 TO statCountOfElements - 1 DO
                        statParameter[tempLoopIndex].format := statRespParameter.data[tempPointer];  // Format of the parameter
                        
                        // Format = Error 
                        IF (((TO_SINT(statRespParameter.data[tempPointer]) > FORMAT_DOUBLE_WORD) OR
                          ((TO_SINT(statRespParameter.data[tempPointer]) > FORMAT_FLOATING_POINT) AND (TO_SINT(statRespParameter.data[tempPointer]) < FORMAT_OCTET_STRING)) OR
                          ((TO_SINT(statRespParameter.data[tempPointer]) > FORMAT_OCTET_STRING) AND (TO_SINT(statRespParameter.data[tempPointer]) < FORMAT_TIME_DIFFERENCE)) OR
                          ((TO_SINT(statRespParameter.data[tempPointer]) > FORMAT_TIME_DIFFERENCE) AND (TO_SINT(statRespParameter.data[tempPointer]) < FORMAT_BYTE)) OR
                          (TO_SINT(statRespParameter.data[tempPointer]) < FORMAT_INTEGER_8))) AND (TO_SINT(statRespParameter.data[tempPointer]) <> FORMAT_ZERO)
                        THEN
                          
                          // Format = Error, summarize the first and second error byte in a word error variable for each parameter
                          statParameter[tempLoopIndex].errorValue := statRespParameter.data[tempPointer + 3];
                          IF (statFirstParameterError = NO_PARAMETER_ERROR) THEN
                            diagnostics.firstParameterError := tempLoopIndex;
                            diagnostics.errorValue := statParameter[tempLoopIndex].errorValue; // V1.3.2
                            statFirstParameterError := tempLoopIndex;
                            statError := TRUE;
                            statStateNumber := statFBSubState;
                            statStatus := ERR_PARAMETER;
                            statFBState := FB_ERROR;
                          END_IF;
                          // Points to the next parameter address
                          tempPointer := tempPointer + 6;
                          
                        ELSE
                          
                          CASE TO_SINT(statRespParameter.data[tempPointer]) OF
                            FORMAT_INTEGER_8:
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_SINT(statRespParameter.data[tempPointer + 2]));
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := statRespParameter.data[tempPointer + 2];
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics    
                              tempPointer := tempPointer + 4; // Points to the next parameter address
                            FORMAT_INTEGER_16:
                              tempWord.%B0 := statRespParameter.data[tempPointer + 3];
                              tempWord.%B1 := statRespParameter.data[tempPointer + 2];
                              
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_INT(tempWord));
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := tempWord;
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics
                              tempPointer := tempPointer + 4; // Points to the next parameter address
                            FORMAT_INTEGER_32:
                              tempDWord.%B0 := statRespParameter.data[tempPointer + 5];
                              tempDWord.%B1 := statRespParameter.data[tempPointer + 4];
                              tempDWord.%B2 := statRespParameter.data[tempPointer + 3];
                              tempDWord.%B3 := statRespParameter.data[tempPointer + 2];
                              
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_DINT(tempDWord));
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := tempDWord;
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics
                              tempPointer := tempPointer + 6; // Points to the next parameter address
                            FORMAT_UNSIGNED_8, FORMAT_OCTET_STRING: // V1.5 change OCTET_STRING
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_USINT(statRespParameter.data[tempPointer + 2]));
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := statRespParameter.data[tempPointer + 2];
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics      
                              tempPointer := tempPointer + 4; // Points to the next parameter address
                            FORMAT_UNSIGNED_16:
                              tempWord.%B0 := statRespParameter.data[tempPointer + 3];
                              tempWord.%B1 := statRespParameter.data[tempPointer + 2];
                              
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_UINT(tempWord));
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := tempWord;
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics
                              tempPointer := tempPointer + 4; // Points to the next parameter address
                            FORMAT_UNSIGNED_32, FORMAT_TIME_DIFFERENCE:
                              tempDWord.%B0 := statRespParameter.data[tempPointer + 5];
                              tempDWord.%B1 := statRespParameter.data[tempPointer + 4];
                              tempDWord.%B2 := statRespParameter.data[tempPointer + 3];
                              tempDWord.%B3 := statRespParameter.data[tempPointer + 2];
                              
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_UDINT(tempDWord));
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := tempDWord;
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics
                              tempPointer := tempPointer + 6; // Points to the next parameter address
                            FORMAT_FLOATING_POINT, FORMAT_DOUBLE_WORD:
                              tempDWord.%B0 := statRespParameter.data[tempPointer + 5];
                              tempDWord.%B1 := statRespParameter.data[tempPointer + 4];
                              tempDWord.%B2 := statRespParameter.data[tempPointer + 3];
                              tempDWord.%B3 := statRespParameter.data[tempPointer + 2];
                              
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(tempDWord);
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := tempDWord;
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics
                              tempPointer := tempPointer + 6; // Points to the next parameter address
                            FORMAT_BYTE:
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_DWORD(statRespParameter.data[tempPointer + 2]));
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := statRespParameter.data[tempPointer + 2];
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics      
                              tempPointer := tempPointer + 4; // Points to the next parameter address
                            FORMAT_WORD:
                              tempWord.%B0 := statRespParameter.data[tempPointer + 3];
                              tempWord.%B1 := statRespParameter.data[tempPointer + 2];
                              
                              IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_SILENT) THEN
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_DWORD(tempWord));
                                
                              ELSE
                                statParameter[tempLoopIndex].dwordValue := tempWord;
                              END_IF;
                              
                              statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics
                              tempPointer := tempPointer + 4; // Points to the next parameter address
                              
                            ELSE
                              ;
                          END_CASE;
                          
                        END_IF; // Format = Error
                      END_FOR; // Analyse of the response buffer
                      
                      // Copying parameter data into the dataset (depending on the used PLC data type)
                   //   IF (statDatasetType = DATA_TYPE_DATASET_REAL) THEN
                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                          tempActualElementReal.index := statParameter[tempLoopIndex].index;
                          tempActualElementReal.parameterNumber := statParameter[tempLoopIndex].parameterNo;
                          tempActualElementReal.value := statParameter[tempLoopIndex].realValue;
                          tempActualElementReal.errorValue := statParameter[tempLoopIndex].errorValue;
                         // tempBlkVariant := MOVE_BLK_VARIANT(SRC := tempActualElementReal, COUNT := 1, SRC_INDEX := 0, DEST_INDEX := tempLoopIndex, DEST => dataset);
                          dataset[tempLoopIndex] := tempActualElementReal;
                          // Error occurred during MOVE_BLK_VARIANT command
                          IF (tempBlkVariant <> 0) THEN
                            statError := TRUE;
                            statStateNumber := statFBSubState;
                            statSubfunctionStatus := TO_WORD(tempBlkVariant);
                            statStatus := ERR_MOVE_BLK_VARIANT;
                            statFBState := FB_ERROR;
                            diagnostics.firstParameterError := tempLoopIndex;
                          END_IF;
                        END_FOR;
                        
                   (*    ELSIF (statDatasetType = DATA_TYPE_DATASET_DWORD) THEN
                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                          tempActualElementDWord.index := statParameter[tempLoopIndex].index;
                          tempActualElementDWord.parameterNumber := statParameter[tempLoopIndex].parameterNo;
                          tempActualElementDWord.value := statParameter[tempLoopIndex].dwordValue;
                          tempActualElementDWord.errorValue := statParameter[tempLoopIndex].errorValue;
                          tempBlkVariant := MOVE_BLK_VARIANT(SRC := tempActualElementDWord, COUNT := 1, SRC_INDEX := 0, DEST_INDEX := tempLoopIndex, DEST => dataset);
                          
                          // Error occurred during MOVE_BLK_VARIANT command
                          IF (tempBlkVariant <> 0) THEN
                            statError := TRUE;
                            statStateNumber := statFBSubState;
                            statSubfunctionStatus := TO_WORD(tempBlkVariant);
                            statStatus := ERR_MOVE_BLK_VARIANT;
                            statFBState := FB_ERROR;
                            diagnostics.firstParameterError := tempLoopIndex;
                          END_IF;
                        END_FOR;
                        
                      ELSE
                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                          tempSilentOperationData.dataset[tempLoopIndex].index := statParameter[tempLoopIndex].index;
                          tempSilentOperationData.dataset[tempLoopIndex].parameterNumber := statParameter[tempLoopIndex].parameterNo;
                          tempSilentOperationData.dataset[tempLoopIndex].value := statParameter[tempLoopIndex].realValue;
                          tempSilentOperationData.dataset[tempLoopIndex].errorValue := statParameter[tempLoopIndex].errorValue;
                        END_FOR;
                      END_IF;
                      *)
                      statCmdBusy := FALSE;
                      statCmdError := FALSE;
                      
                      // Next state is depending on the FB mode
                      IF (statWithoutResourceManager = FALSE) AND (statError = FALSE) THEN
                        statStatus := STATUS_RELEASE;
                        statFBState := FB_RELEASE;
                        
                      ELSIF (statError = FALSE) THEN
                        statStatus := STATUS_EXECUTION_FINISHED;
                        statFBState := FB_DONE;
                        
                      END_IF; // statMode = MODE_WITH_BUFFER_MANAGER
                    END_IF; // statCmdError = TRUE
                    
                  FB_BUSY_WAIT:
                    // Timer for temporary errors 
                    instIECTimer(signal := statTimerStart,
                                  duration := TIMER_TEMP_ERROR);
                    
                    statTimerStart := TRUE;
                    IF (instIECTimer.output = TRUE) THEN
                      statTimerStart := FALSE;
                      statFBSubState := statFBSubStateOld;
                    END_IF;
                    
                  ELSE
                    statError := TRUE;
                    statStatus := ERR_UNDEFINED_SUBSTATE;
                    statStateNumber := statFBState;
                    statFBState := FB_ERROR;
                END_CASE;
                
              ELSE
                statError := TRUE;
                statStatus := ERR_COMMAND_TIMEOUT;
                statStateNumber := statFBState;
                statFBState := FB_ERROR;
              END_IF; // ((buffer.element[statAllocatedIndex].enable = TRUE) AND (statMode = MODE_WITH_BUFFER_MANAGER)) OR statMode = MODE_WITHOUT_BUFFER_MANAGER
              
            FB_RELEASE:
              // Check buffer index for correctness
              IF (statAllocatedIndex < 0) OR (statAllocatedIndex > typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
                statError := TRUE;
                statStatus := ERR_INVALID_BUF_INDEX;
                statStateNumber := statFBState;
                statFBState := FB_ERROR;
                
              ELSIF (requestBuffer.header.lockBuffer = FALSE) THEN // V1.5.1
                requestBuffer.header.lockBuffer := TRUE;
                IF (requestBuffer.elements[statAllocatedIndex].state.%X0 = TRUE) THEN
                  requestBuffer.elements[statAllocatedIndex].state.%X2 := TRUE;
                ELSE
                  ;
                END_IF;
                requestBuffer.header.lockBuffer := FALSE;
                statStatus := STATUS_EXECUTION_FINISHED;
                statFBState := FB_DONE;
                
              END_IF;
              
            ELSE
              statError := TRUE;
              statStatus := ERR_UNDEFINED_STATE;
              statStateNumber := statFBState;
              statFBState := FB_ERROR;
          END_CASE;
          
          // If input execute is set during processing
          IF statWarningRetriggering = TRUE AND statError = FALSE THEN
            statStatus := WARN_EXECUTE_SET_DURING_PROCESSING;
          END_IF;
          
        END_IF;

        //----------------------------------------------------------------------
        // Error handling and write outputs
        //----------------------------------------------------------------------
        
        // Edge detection
         statExecuteOld := tempExecute;
        
        IF (statFBState = FB_ERROR) THEN
          // Release the allocated element when error occurs
          IF (statStateNumber <> FB_FIRST_CYCLE) AND (statStateNumber <> FB_ALLOCATE)
            AND (statBusy = TRUE) AND (statWithoutResourceManager = FALSE)
          THEN
            IF requestBuffer.header.lockBuffer = FALSE THEN // V1.5.1
              requestBuffer.header.lockBuffer := TRUE;
              IF (requestBuffer.elements[statAllocatedIndex].state.%X0 = TRUE) THEN
                requestBuffer.elements[statAllocatedIndex].state.%X2 := TRUE;
              ELSE
                ;
              END_IF;
              requestBuffer.header.lockBuffer := FALSE;
              
              // Write diagnostics
              diagnostics.stateNumber := statStateNumber;
              diagnostics.subfunctionStatus := statSubfunctionStatus;
              diagnostics.status := statStatus;
              statBusy := FALSE;
              statDone := FALSE;
              
            END_IF;
            
          ELSE
            // Write diagnostics
            diagnostics.stateNumber := statStateNumber;
            diagnostics.subfunctionStatus := statSubfunctionStatus;
            diagnostics.status := statStatus;
            statBusy := FALSE;
            statDone := FALSE;
          END_IF;
          
          // FB finished request  
        ELSIF (statFBState = FB_DONE) THEN
          
          // Output for one cycle minimum
          IF (tempExecute = FALSE) AND (statDone = TRUE) THEN
            statDone := FALSE;
            statStatus := STATUS_NO_CALL;
            statFBState := FB_IDLE;
          ELSE
            statDone := TRUE;
            statBusy := FALSE;
          END_IF;
          // If input execute is set during processing
          IF statWarningRetriggering = TRUE THEN
            statStatus := ERR_AMBIGUOUS_FB_CALL;
            diagnostics.status := statStatus;
            statError := TRUE;
            statDone := FALSE;
          END_IF;
        END_IF;
  
        // Write static values to outputs
     (*   IF (TypeOf(dataset) = TypeOf(tempDatasetRealValue)) OR (TypeOf(dataset) = TypeOf(tempDatasetDWordValue)) THEN
          ;
        ELSIF (TypeOf(dataset) = LAcycCom_typeDriveSilentOperation) THEN
          IF (tempSilentOperationData.functionBlockCommand = typeconstantsbyte#LACYCCOM_NO_COMMAND) OR (tempSilentOperationData.functionBlockCommand = typeconstantsbyte#LACYCCOM_READ_COMMAND) THEN // 16#00: no command; 16#01: read command  
            tempSilentOperationData.error := statError;
            tempSilentOperationData.busy := statBusy;
            tempSilentOperationData.done := statDone;
            tempSilentOperationData.status := statStatus;
            tempSilentOperationData.lifeSignCheckFBRead := tempSilentOperationData.lifeSignCheckFBRead + uint#1;  // Life sign counter to monitor that the FB is enabled
            tempBlkVariant := MOVE_BLK_VARIANT(SRC := tempSilentOperationData, COUNT := 1, SRC_INDEX := 0, DEST_INDEX := 0, DEST => dataset);
            
            // Error occurred during MOVE_BLK_VARIANT command
            IF (tempBlkVariant <> 0) THEN
              statError := TRUE;
              statStateNumber := statFBState;
              statSubfunctionStatus := TO_WORD(tempBlkVariant);
              statStatus := ERR_MOVE_BLK_VARIANT;
              statFBState := FB_ERROR;
            END_IF;
          END_IF;
          
        ELSE
          statError := TRUE;
          statStatus := ERR_INVALID_DATA_TYPE;
          statFBState := FB_ERROR;
        END_IF;*)
        
        IF statBusy = FALSE OR statError = FALSE
        THEN  // V1.5.1
          error := statError;
          status := statStatus;
        END_IF;
        
        busy := statBusy;
        done := statDone;

    END_FUNCTION_BLOCK
END_NAMESPACE    
    