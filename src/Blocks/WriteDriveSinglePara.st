using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom

FUNCTION_BLOCK LAcycCom_WriteDriveSingleParam

   VAR_INPUT 
      execute : Bool;   // TRUE: Rising edge starts the functionality once
      driveObjectId  : Int := -1;   // Optional: Identification number of the drive object (value <0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
      hardwareId : HW_IO;   // Hardware identifier of the hardware module
      parameterNumber : UInt;   // Number of the parameter
      index : UInt;   // Parameter index
      value : Real;   // Parameter value (real value)
      dWordValue : DWord;   // Parameter value (dword value); only used if input 'value' = 0.0
   END_VAR

   VAR_OUTPUT 
      done   : Bool;   // TRUE: Finished writing the parameter
      busy   : Bool;   // TRUE: FB is not finished and new output values can be expected
      error   : Bool;   // TRUE: Rising edge informs that an error occurred during the execution of the FB
      status   : Word :=  STATUS_NO_CALL;   // Status identifier
      errorValue   : Byte := byte#16#FF;   // Error number (16#FF: no error; else: see error list)
      diagnostics   : LAcycCom_typeDriveDiagnostics;   // Diagnostics structure
   END_VAR

   VAR_IN_OUT 
      requestBuffer : LAcycCom_typeRequestBuffer;   // Connection to the request buffer of the resource manager. All LAcycCom blocks have to use the same request buffer
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
      statDoId   : Byte := byte#16#00;   // Intern identification number of the drive object
      statHwId   : HW_IO :=  HW_IO#default;   // Intern hardware identifier of the hardware module
      statRefNo   : Byte := byte#16#00;   // Reference number of request
      statStatus   : Word :=  STATUS_NO_CALL;   // Static value for output status
      statSubfunctionStatus   : Word := Word#16#0000;   // Block status or error information
      statWithoutResourceManager   : Bool := FALSE;   // TRUE: No resource manager available; FALSE: Resource manager available
      statFBState   : SInt :=  FB_IDLE;   // States in the function block state machine
      statFBSubState   : SInt :=  FB_BUSY_WRREC_1;   // States in the function block during processing (busy state)
      statFBSubStateOld   : SInt :=  FB_BUSY_WRREC_1;   // Previous state when temporary error occurs
      statStateNumber   : SInt := SINT#0;   // State of the FB when error occurred
      statErrorCount   : UInt := uint#16#0000;   // Error counter of retry request
      statParameterNumber   : UInt := uint#0;   // Static value for input parameterNumber
      statParameterIndex   : UInt := uint#0;   // Static value for input parameterIndex
      statAllocatedIndex   : Int := 0;   // Allocated element index in the buffer DB
      statFirstParameterError   : Int := -1;   // Number of parameter at which the error occurred (-1: no parameter with error)
      statWarningRetriggering   : Bool;   // TRUE: Input execute is set during processing
      statDataRecordNo   : DInt;   // Used data record
      statParameter   : Array[0..typeconstantsint#WRITE_PARAMETERS_UPPER_LIM_SINGLE] of LAcycCom_TypestatstatParameter;
      statReqReadParameter   : LAcycCom_TypestatReqReadParameter;   // Request telegram to read the format of parameters
      statReqParameterInit   : LAcycCom_TypestatparameterAddress :=(attribute := byte#16#10, elementNo  := byte#16#01, parameterNo := uint#0, index := uint#0);
      statReqWriteParameter   : LAcycCom_TypestatRespParameter;
      statRespParameter   : LAcycCom_TypestatRespParameter;   // List of parameter

      instWRREC : writerecord;   // WRREC command
      instRDREC : readrecord;   // RDREC command
      instIECTimer : ondelay;   // IEC-Timer
	  
	  atmpSend : ARRAY[0..237]of BYTE ;
	  atmpRec  : ARRAY[0..237]of BYTE ;
   END_VAR


   VAR_TEMP 
      tempCmdValid : Bool;   // TRUE: New data record was received and is valid
      tempStatusWord : Word;   // Temporary status
      tempLoopIndex : Int;   // Temporary loop index variable
      tempLastQueueElement : Int;   // Last element in queue
      tempCmdStatus : DWord;   // Temporary status of WRREC and RDREC command
      tempDWord : DWord;   // Temporary DWord variable
      tempVoidDiagnostics : LAcycCom_typeDriveDiagnostics;   // Temporary empty diagnostics structure
      tempVoidHeader : LAcycCom_Typestatheader;   // Temporary empty header structure
   END_VAR

   VAR CONSTANT 
      NO_PARAMETER_ERROR : Int := -1;   // No parameter error in response telegram
      ALL_ELEMENTS_OCCUPIED : Int := -1;   // All buffer elements are occupied
      FB_IDLE : SInt := SINT#0;   // Idle state in FB
      FB_FIRST_CYCLE : SInt := SINT#1;   // First cycle state in FB
      FB_ALLOCATE : SInt := SINT#2;   // Allocating a request element in request buffer DB
      FB_GET_RESOURCE : SInt := SINT#3;   // State to check if the communication to the drive object can be established
      FB_BUSY : SInt := SINT#4;   // Busy state in FB
      FB_RELEASE : SInt := SINT#5;   // State to return the allocated index
      FB_DONE : SInt := SINT#6;   // Done state in FB
      FB_ERROR : SInt := SINT#7;   // Error state in FB
      FB_BUSY_WRREC_1 : SInt := SINT#8;   // WRREC (getting format of parameters) in busy state
      FB_BUSY_WRREC_2 : SInt := SINT#9;   // WRREC (changing parameters) in busy state
      FB_BUSY_RDREC_1 : SInt := SINT#10;   // RDREC in busy state
      FB_BUSY_RDREC_2 : SInt := SINT#11;   // RDREC (telegram after writing parameters) in busy state
      FB_BUSY_WAIT : SInt := SINT#12;   // State when temporary error occurred
      FORMAT_INTEGER_8 : SInt := SINT#2;   // Identifier for Integer8 format
      FORMAT_INTEGER_16 : SInt := SINT#3;   // Identifier for Integer16 format
      FORMAT_INTEGER_32 : SInt := SINT#4;   // Identifier for Integer32 format
      FORMAT_UNSIGNED_8 : SInt := SINT#5;   // Identifier for Unsigned8 format
      FORMAT_UNSIGNED_16 : SInt := SINT#6;   // Identifier for Unsigned16 format
      FORMAT_UNSIGNED_32 : SInt := SINT#7;   // Identifier for Unsigned32 format
      FORMAT_FLOATING_POINT : SInt := SINT#8;   // Identifier for Floating Point format
      FORMAT_OCTET_STRING : SInt := SINT#10;   // Identifier for OctetString format
      FORMAT_TIME_DIFFERENCE : SInt := SINT#13;   // Identifier for TimeDifference format
      FORMAT_ZERO : SInt := SINT#64;   // Identifier for void telegram
      FORMAT_BYTE : SInt := SINT#65;   // Identifier for Byte format
      FORMAT_WORD : SInt := SINT#66;   // Identifier for Word format
      FORMAT_DOUBLE_WORD : SInt := SINT#67;   // Identifier for Double Word format
      FORMAT_ERROR : Byte := byte#16#44;   // Identifier for a format error
      //WRITE_PARAMETERS_UPPER_LIM : Int := 0;   // Maximum count of parameters
      LENGTH_WRITE_TELEGRAM_UPPER_LIM : Int := 11;   // Maximum length of parameter information when using WRREC
      LENGTH_READ_TELEGRAM_UPPER_LIM : Int := 5;   // Maximum length of telegram for parameter information in Byte
      MAX_ERROR_COUNT : UInt := uint#40;   // Maximum error counter
      TIMER_TEMP_ERROR : Time := T#200MS;   // Waiting time until next system function block call
      TIMER_ALLOCATION : Time := T#10S;   // Timer limit for allocating a request element
      MAX_DRIVE_OBJECT_NO : Int := 254;   // Maximum drive object number limited by SINAMICS p101
      STATUS_EXECUTION_FINISHED : Word := word#16#0000;   // Execution finished without errors
      STATUS_NO_CALL : Word := word#16#7000;   // No call of FB
      STATUS_ALLOCATE : Word := word#16#7001;   // FB is currently allocating a request element
      STATUS_GET_RESOURCE : Word := word#16#7002;   // FB is waiting until it has “speaking rights”
      STATUS_BUSY : Word := word#16#7003;   // FB is currently in processing
      STATUS_RELEASE : Word := word#16#7004;   // FB is releasing the allocated element
      WARN_EXECUTE_SET_DURING_PROCESSING : Word := word#16#7101;   // Execute input set during processing
      ERR_REQUEST_REJECTED : Word := word#16#8004;   // Request rejected
      ERR_RESOURCE_RELEASED : Word := word#16#8005;   // Request is already released
      ERR_AMBIGUOUS_FB_CALL : Word := word#16#8006;   // Execute input set during processing (possible inconsistent data at output)
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
      ERR_UNDEFINED_STATE : Word := word#16#8611;   // Error due to an undefined state
      ERR_UNDEFINED_SUBSTATE : Word := word#16#8612;   // Error due to an undefined substate
      ERR_PARAMETER : Word := word#16#8619;   // Error during writing the parameter (see: errorValue)
   END_VAR

	
	//----------------------------------------------------------------------
	// Processing
	//----------------------------------------------------------------------
	// Rising edge of execute starts functionality
	IF (execute = TRUE) AND (statExecuteOld = FALSE) AND (statBusy = TRUE) THEN
	  // Input execute is set during processing
	   statStatus :=  WARN_EXECUTE_SET_DURING_PROCESSING;
	   statWarningRetriggering := TRUE;
	  
	ELSIF (execute = TRUE) AND (statExecuteOld = FALSE) THEN
	  // First call
	  // Initialisation
	   statDone := FALSE;
	   statBusy := TRUE;
	   statError := FALSE;
	   statAllocatedIndex := 0;
	   statHwId :=  HW_IO#default;
	   statSubfunctionStatus := word#16#0;
	   statDoId := byte#0;
	   statDataRecordNo := 0;
	   statStateNumber := sint#0;
	   statFirstParameterError := -1;
	   statCmdBusy := FALSE;
	   statCmdDone := FALSE;
	   statCmdError := FALSE;
	   statErrorCount := uint#0;
	   statWarningRetriggering := FALSE;
	   statFBSubState :=  FB_BUSY_WRREC_1;
	   statFBState :=  FB_FIRST_CYCLE;
	  
	   instIECTimer(signal := FALSE,
	   				duration :=  TIMER_ALLOCATION);
	  
	  // FB is currently inactive  
	ELSIF (execute = FALSE) AND (statBusy = FALSE) AND
	  (statError = TRUE OR  statDone = TRUE)
	THEN
	  IF  statError THEN
	    // Reset output
	     errorValue := byte#16#FF;
	  END_IF;
	   statError := FALSE;
	   statBusy := FALSE;
	   statDone := FALSE;
	   statFBState :=  FB_IDLE;
	   statStatus :=  STATUS_NO_CALL;
	  
	END_IF; //  tempExecute AND NOT  statExecuteOld
	
	//----------------------------------------------------------------------
	// State Machine
	//----------------------------------------------------------------------
	
	IF (statBusy = TRUE) AND (statError = FALSE) THEN  // Functionality running
	  CASE  statFBState OF
	     FB_FIRST_CYCLE:  // First cycle state
	      
	      // Clearing the sending read buffer
	       statReqReadParameter.header :=  tempVoidHeader;
	       statReqReadParameter.parameterAddress[0] :=  statReqParameterInit;
	      
	      // Clearing the sending write buffer
	       statReqWriteParameter.header :=  tempVoidHeader;
	      FOR  tempLoopIndex := 0 TO  LENGTH_WRITE_TELEGRAM_UPPER_LIM DO
	         statReqWriteParameter.data[tempLoopIndex] := byte#16#00;
	      END_FOR;
	      
	      // Clearing the receive buffer
	       statRespParameter.header :=  tempVoidHeader;
	      FOR  tempLoopIndex := 0 TO  LENGTH_READ_TELEGRAM_UPPER_LIM DO
	         statRespParameter.data[tempLoopIndex] := byte#16#00;
	      END_FOR;
	      
	      // Initialization after start, depending on the used PLC data type
	      IF  driveObjectId < 0 THEN // V1.5
	         statDataRecordNo := 16#B02E; // Base Mode Parameter Access local; doId not relevant
	         statDoId := byte#0;
	        
	      ELSIF (driveObjectId <=  MAX_DRIVE_OBJECT_NO)
	        AND (driveObjectId <> 0)
	      THEN // V1.5.2
	         statDataRecordNo := 47; // Data record 47; Base Mode Parameter Access global
	         statDoId := TO_BYTE(driveObjectId);
	        
	      ELSE // V1.5.2 
	        // Wrong drive object ID at input
	         statError := TRUE;
	         statStateNumber :=  statFBState;
	         statStatus :=  ERR_INVALID_DRIVE_OBJECT_ID;
	         statFBState :=  FB_ERROR;
	      END_IF;
	      
	       statHwId :=  hardwareId;
	       statParameterNumber :=  parameterNumber;
	       statParameterIndex :=  index;
	       statParameter[0].realValue :=  value;
	       statParameter[0].dwordValue :=  dWordValue;
	      
	       diagnostics :=  tempVoidDiagnostics;
	       diagnostics.driveObjectId :=  to_usint(statDoId);
	       diagnostics.hardwareId :=  statHwId;
	       diagnostics.parameterCount := 1;
	       diagnostics.firstParameterError :=  statFirstParameterError; // V1.3.2
	       diagnostics.errorValue := byte#16#FF; // V1.3.2
	
	      // Reference number for next request
	       statRefNo :=  to_byte(to_uint(statRefNo) + uint#1);
	      
	      
	      IF  statError THEN // V1.5.2: Check if error appeared
	        ;
	        
	        // Next state is depending on the FB mode
	      ELSIF (statWithoutResourceManager = FALSE) THEN
	         statStatus :=  STATUS_ALLOCATE;
	         statFBState :=  FB_ALLOCATE;
	        
	      ELSE
	         statStatus :=  STATUS_BUSY;
	         statFBState :=  FB_BUSY;
	         statFBSubState :=  FB_BUSY_WRREC_1;
	      END_IF; //  statMode =  MODE_WITH_BUFFER_MANAGER
	
	     FB_ALLOCATE:
	      
	      // Allocation of a request element
	      IF (requestBuffer.header.lockBuffer = FALSE) AND (requestBuffer.header.nextFreeElement >= 0) AND (requestBuffer.header.nextFreeElement <= typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
	         requestBuffer.header.lockBuffer := TRUE;
	         statAllocatedIndex :=  requestBuffer.header.nextFreeElement;
	         requestBuffer.elements[statAllocatedIndex].state := byte#16#00;
	         requestBuffer.elements[statAllocatedIndex].state.%X0 := TRUE;
	         requestBuffer.elements[statAllocatedIndex].hardwareId :=  statHwId;
	         requestBuffer.elements[statAllocatedIndex].queueElementNext := -1;
	         statTimerStart := FALSE;
	         statStatus :=  STATUS_GET_RESOURCE;
	         statFBState :=  FB_GET_RESOURCE;
	        
	        // Build up queue
	        IF (requestBuffer.header.firstQueueElement >= 0) THEN
	          // Find last queue element 
	           tempLoopIndex :=  requestBuffer.header.firstQueueElement;
	          WHILE (tempLoopIndex >= 0) DO
	             tempLastQueueElement :=  tempLoopIndex;
	             tempLoopIndex :=  requestBuffer.elements[tempLoopIndex].queueElementNext;
	          END_WHILE;
	          
	          // Insert into list after last element
	           requestBuffer.elements[tempLastQueueElement].queueElementNext :=  statAllocatedIndex;
	           requestBuffer.elements[statAllocatedIndex].queueElementPrevious :=  tempLastQueueElement;
	        ELSE
	          // Element is first element in queue
	           requestBuffer.header.firstQueueElement :=  statAllocatedIndex;
	           requestBuffer.elements[statAllocatedIndex].queueElementPrevious := -1;
	        END_IF;
	        
	        // Searching for the next free request element
	        FOR  tempLoopIndex := 0 TO typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM DO
	          IF (requestBuffer.elements[tempLoopIndex].state.%X0 = FALSE) THEN
	             requestBuffer.header.nextFreeElement :=  tempLoopIndex;
	            EXIT;
	          END_IF;
	          
	          // All request elements are occupied
	          IF (tempLoopIndex = typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
	             requestBuffer.header.nextFreeElement :=  ALL_ELEMENTS_OCCUPIED;
	          END_IF;
	        END_FOR;
	        
	         requestBuffer.header.lockBuffer := FALSE;
	        
	      ELSIF (instIECTimer.output = TRUE) THEN
	         statError := TRUE;
	         statStateNumber :=  statFBState;
	         statStatus :=  ERR_ALLOCATION_TIME;
	         statFBState :=  FB_ERROR;
	        
	      ELSE
	        ; // Waiting until lockbit is reset and a request element is available
	      END_IF; // (buffer.lockBuffer = FALSE) AND (buffer.actualWriteIndex >= 0)
	      
	       instIECTimer(signal :=  statTimerStart,
	                    duration :=  TIMER_ALLOCATION);
	      
	       statTimerStart := TRUE;
	      IF (instIECTimer.output = TRUE) THEN
	         statTimerStart := FALSE;
	      END_IF;
	      
	     FB_GET_RESOURCE:
	      
	      // Check buffer index for correctness
	      IF (statAllocatedIndex < 0) OR (statAllocatedIndex > typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
	         statError := TRUE;
	         statStateNumber :=  statFBState;
	         statStatus :=  ERR_INVALID_BUF_INDEX;
	         statFBState :=  FB_ERROR;
	        
	      ELSE
	        IF (requestBuffer.elements[statAllocatedIndex].state.%X0 = FALSE) OR
	          (requestBuffer.elements[statAllocatedIndex].state.%X3 = TRUE)
	        THEN
	          // Request was rejected by buffer manager
	           statError := TRUE;
	           statStateNumber :=  statFBState;
	           statStatus :=  ERR_REQUEST_REJECTED;
	           statFBState :=  FB_ERROR;
	          
	        ELSIF (requestBuffer.elements[statAllocatedIndex].state.%X2 = TRUE) THEN
	          // Request already released
	           statError := TRUE;
	           statStateNumber :=  statFBState;
	           statStatus :=  ERR_RESOURCE_RELEASED;
	           statFBState :=  FB_ERROR;
	          
	        ELSIF (requestBuffer.elements[statAllocatedIndex].state.%X1 = TRUE) THEN
	          // Element is enabled
	           statStatus :=  STATUS_BUSY;
	           statFBState :=  FB_BUSY;
	           statFBSubState :=  FB_BUSY_WRREC_1;
	          
	        ELSE
	          // Element not enabled yet
	          // 
	           statStatus :=  STATUS_GET_RESOURCE;
	        END_IF;
	        
	      END_IF;
	      
	     FB_BUSY:
	      
	      IF ((requestBuffer.elements[statAllocatedIndex].state.%X1 = TRUE) AND (statWithoutResourceManager = FALSE)
	        AND (requestBuffer.elements[statAllocatedIndex].state.%X3 = FALSE)) OR (statWithoutResourceManager = TRUE)
	      THEN
	        
	        CASE  statFBSubState OF
	           FB_BUSY_WRREC_1,  FB_BUSY_WRREC_2:  // Writing the dataset configuration into the drive object
	            
	            IF (statCmdBusy = FALSE) AND (statFBSubState =  FB_BUSY_WRREC_1) AND (statError = FALSE) THEN
	              // Resets WRREC command
	               instWRREC(request := FALSE,
				   			  RECORD := atmpSend);
	              
	              // Creating header data
	               statReqReadParameter.header.refNo :=  statRefNo; // Telegram reference number
	               statReqReadParameter.header.reqId := byte#16#01;  // 0x01 = request parameters
	               statReqReadParameter.header.doId :=  statDoId;  // Drive object identification number
	               statReqReadParameter.header.parameterNo := byte#16#01;  // Count of parameters
	              
	              // Copying the dataset into a static variable 
	               statParameter[0].index := uint#0;
	               statParameter[0].parameterNo :=  statParameterNumber;
	              //  statParameter[0].realValue :=  statParameterValue; --> V1.5.2: Moved to first cycle
	               statReqReadParameter.parameterAddress[0].parameterNo :=  statParameter[0].parameterNo;  // Parameter number   
	               statReqReadParameter.parameterAddress[0].index :=  statParameter[0].index;  // Subindex of parameter
	              
	            ELSIF (statCmdBusy = FALSE) AND (statFBSubState =  FB_BUSY_WRREC_2) AND (statError = FALSE) THEN
	              // Resets WRREC command
	               instWRREC(request := FALSE,
				   			  RECORD := atmpSend);
	              
	              // Creating header data
	               statReqWriteParameter.header.refNo :=  statRefNo; // Telegram reference number
	               statReqWriteParameter.header.reqId := byte#16#02;  // 0x02 = change parameters
	               statReqWriteParameter.header.doId :=  statDoId;  // Drive object identification number
	               statReqWriteParameter.header.parameterNo := byte#16#01;  // Count of parameters
	              
	              // Creating parameter address - parameter number and parameter index
	               statReqWriteParameter.data[0] := byte#16#10; // Attribute of parameters (0x10=Value, 0x30=Text)
	               statReqWriteParameter.data[1] := byte#16#01; // No. of elements (for single elements=1)        
	               statParameter[0].index :=  statParameterIndex;
	               statParameter[0].parameterNo :=  statParameterNumber;
	              
	              // Parameter number                               
	               statReqWriteParameter.data[3] :=  statParameter[0].parameterNo.%B0;
	               statReqWriteParameter.data[2] :=  statParameter[0].parameterNo.%B1;
	              
	              // Subindex of parameter
	               statReqWriteParameter.data[5] :=  statParameter[0].index.%B0;
	               statReqWriteParameter.data[4] :=  statParameter[0].index.%B1;
	              
	              
	              // Creating parameter address - data
	              IF (statParameter[0].format =  FORMAT_ERROR) THEN
	                 statParameter[0].format := TO_BYTE(FORMAT_FLOATING_POINT);
	              END_IF;
	              
	               statReqWriteParameter.data[6] :=  statParameter[0].format; // Format of parameter
	               statReqWriteParameter.data[7] := byte#16#01; // Count of values
	              
	              
	              CASE TO_SINT(statParameter[0].format) OF
	                 FORMAT_INTEGER_8:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(TO_SINT(statParameter[0].realValue));
	                  END_IF;
	                  
	                   statReqWriteParameter.data[9] :=  tempDWord.%B1;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B0;
	                  
	                 FORMAT_INTEGER_16:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(TO_DINT(statParameter[0].realValue));
	                  END_IF;
	                  
	                   statReqWriteParameter.data[9] :=  tempDWord.%B0;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B1;
	                  
	                 FORMAT_INTEGER_32:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(TO_DINT(statParameter[0].realValue));
	                  END_IF;
	                  
	                   statReqWriteParameter.data[11] :=  tempDWord.%B0;
	                   statReqWriteParameter.data[10] :=  tempDWord.%B1;
	                   statReqWriteParameter.data[9] :=  tempDWord.%B2;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B3;
	                  
	                 FORMAT_UNSIGNED_8,  FORMAT_OCTET_STRING: // V1.5 change OCTET_STRING:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(TO_USINT(statParameter[0].realValue));
	                  END_IF;
	                  
	                   statReqWriteParameter.data[9] :=  tempDWord.%B1;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B0;
	                  
	                 FORMAT_UNSIGNED_16:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(TO_UDINT(statParameter[0].realValue));
	                  END_IF;
	                  
	                   statReqWriteParameter.data[9] :=  tempDWord.%B0;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B1;
	                  
	                 FORMAT_UNSIGNED_32,  FORMAT_TIME_DIFFERENCE:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(TO_UDINT(statParameter[0].realValue));
	                  END_IF;
	                  
	                   statReqWriteParameter.data[11] :=  tempDWord.%B0;
	                   statReqWriteParameter.data[10] :=  tempDWord.%B1;
	                   statReqWriteParameter.data[9] :=  tempDWord.%B2;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B3;
	                  
	                 FORMAT_FLOATING_POINT,  FORMAT_DOUBLE_WORD:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(statParameter[0].realValue);
	                  END_IF;
	                  
	                   statReqWriteParameter.data[11] :=  tempDWord.%B0;
	                   statReqWriteParameter.data[10] :=  tempDWord.%B1;
	                   statReqWriteParameter.data[9] :=  tempDWord.%B2;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B3;
	                  
	                 FORMAT_BYTE:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(statParameter[0].realValue);
	                  END_IF;
	                  
	                   statReqWriteParameter.data[9] :=  tempDWord.%B1;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B0;
	                  
	                 FORMAT_WORD:
	                  // V1.5.2: Added using of dword value input
	                  IF (statParameter[0].realValue = 0.0) THEN
	                     tempDWord :=  statParameter[0].dwordValue;
	                  ELSE
	                     tempDWord := TO_DWORD(statParameter[0].realValue);
	                  END_IF;
	                  
	                   statReqWriteParameter.data[9] :=  tempDWord.%B0;
	                   statReqWriteParameter.data[8] :=  tempDWord.%B1;
	                  
	                ELSE
	                  ;
	              END_CASE;
	            END_IF; //  statCmdBusy = FALSE AND  statParameterConfig = TRUE
	            
	            IF (statFBSubState =  FB_BUSY_WRREC_1) AND (statError = FALSE) THEN
	              // WRREC command
                             // Data record     
				  SerializeBig(uint#0,
				 				statReqReadParameter,
				  				atmpSend );

	               instWRREC(request := TRUE,                                                // Transfer data record
	                         ID :=  statHwId,                                                // ID number of the hardware component
	                         INDEX :=  statDataRecordNo,                                                    // Data record number
	                         LENGTH := uint#0,                                                       // Maximum length of the data record to be transferred in bytes         
	                         DONE =>  statCmdDone,                                           // Data record was transferred          
	                         BUSY =>  statCmdBusy,                                           // The writing process is not yet complete
	                         ERROR =>  statCmdError,                                         // An error occurred during the writing process
	                         STATUS =>  tempCmdStatus,                                       // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
	                         RECORD :=  atmpSend);                               // Data record     
					
							 
                                   // Data record     
				
	            ELSIF (statFBSubState =  FB_BUSY_WRREC_2) AND (statError = FALSE) THEN
	              // WRREC command
				  SerializeBig(uint#0,
				  statReqWriteParameter,
				  atmpSend );

	               instWRREC(request := TRUE,                                                // Transfer data record
	                         ID :=  statHwId,                                                // ID number of the hardware component
	                         INDEX :=  statDataRecordNo,                                                    // Data record number
	                         LENGTH := uint#0,                                                       // Maximum length of the data record to be transferred in bytes         
	                         DONE =>  statCmdDone,                                           // Data record was transferred          
	                         BUSY =>  statCmdBusy,                                           // The writing process is not yet complete
	                         ERROR =>  statCmdError,                                         // An error occurred during the writing process
	                         STATUS =>  tempCmdStatus,                                       // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
	                         RECORD :=  atmpSend);                              // Data record    
	            END_IF;
	            
	            // Error occurred
	            IF (statCmdError = TRUE) AND (statError = FALSE) THEN
	              // Get the error information from the status information
	               tempStatusWord.%B0 :=  tempCmdStatus.%B1;
	               tempStatusWord.%B1 :=  tempCmdStatus.%B2;
	              
	              // Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
	              IF (tempStatusWord = word#16#80A1) OR  // Negative acknowledgment when writing to the module
	                (tempStatusWord = word#16#80A7) OR   // DP slave or module is occupied (temporary error)
	                (tempStatusWord = word#16#80B5) OR   // DP slave or module not ready             
	                (tempStatusWord = word#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
	                (tempStatusWord = word#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.      
	                (tempStatusWord = word#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
	                (tempStatusWord = word#16#80C3) OR   // The required operating resources are currently occupied.
	                (tempStatusWord = word#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.
	                
	                IF (statErrorCount >=  MAX_ERROR_COUNT) THEN
	                   statError := TRUE;
	                   statStateNumber :=  statFBSubState;
	                   statSubfunctionStatus :=  tempStatusWord;
	                   statStatus :=  ERR_WRREC_TEMP_COUNTER;
	                   statFBState :=  FB_ERROR;
	                ELSE
	                   statErrorCount :=  statErrorCount + usint#1;  // Increment internal error counter
	                   statFBSubStateOld :=  statFBSubState;
	                   statFBSubState :=  FB_BUSY_WAIT;
	                END_IF;
	              ELSE
	                 statError := TRUE;
	                 statStateNumber :=  statFBSubState;
	                 statSubfunctionStatus :=  tempStatusWord;
	                 statStatus :=  ERR_WRREC;
	                 statFBState :=  FB_ERROR;
	              END_IF; // Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
	              
	            ELSIF (statCmdBusy = FALSE) AND (statCmdDone = TRUE) AND (statError = FALSE) AND (statFBSubState =  FB_BUSY_WRREC_1) THEN  // Processing completed without errors
	               statErrorCount := uint#0;  // V1.5.1 Reset error counter
	               statFBSubState :=  FB_BUSY_RDREC_1; // WRREC completed and continue with RDREC
	              
	            ELSIF (statCmdBusy = FALSE) AND (statCmdDone = TRUE) AND (statError = FALSE) AND (statFBSubState =  FB_BUSY_WRREC_2) THEN  // Processing completed without errors
	               statErrorCount := uint#0;  // V1.5.1 Reset error counter
	               statFBSubState :=  FB_BUSY_RDREC_2; // WRREC completed and continue with RDREC  
	            END_IF; //  statCmdError = TRUE
	            
	           FB_BUSY_RDREC_1,  FB_BUSY_RDREC_2:  // Reading the values from the drive object
	            
	            // Resets RDREC command
	            IF (statCmdBusy = FALSE) THEN
	               instRDREC(request := FALSE,
	                         RECORD :=  atmpRec);
	            END_IF;
	            
	             instRDREC(request := TRUE,                                                 // Transfer data record
	                       ID :=  statHwId,                                                 // ID number of the hardware component        
	                       INDEX :=  statDataRecordNo,                                                     // Data record number
	                       MAXLENGTH := uint#0,                                                       // Maximum length in bytes of the data record information to be read
	                       VALID =>  tempCmdValid,                                          // New data record was received and is valid   
	                       BUSY =>  statCmdBusy,                                            // The reading process is not yet complete
	                       ERROR =>  statCmdError,                                          // An error occurred during the reading process
	                       STATUS =>  tempCmdStatus,                                        // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code 
	                       RECORD :=  atmpRec);                                   // Destination area for the data record read
						 
						   DeserializeBig(uint#0,
						   atmpRec,
						   statRespParameter);		                                  // Destination area for the data record read

	            // Error occurred
	            IF (statCmdError = TRUE) AND (statError = FALSE) THEN
	              // Get the error information from the status information
	               tempStatusWord.%B0 :=  tempCmdStatus.%B1;
	               tempStatusWord.%B1 :=  tempCmdStatus.%B2;
	              
	              // Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
	              IF (tempStatusWord = word#16#80A0) OR  // Negative acknowledgment when reading the module
	                (tempStatusWord = word#16#80A7) OR   // DP slave or module is occupied (temporary error)
	                (tempStatusWord = word#16#80B5) OR   // DP slave or module not ready             
	                (tempStatusWord = word#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
	                (tempStatusWord = word#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.      
	                (tempStatusWord = word#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
	                (tempStatusWord = word#16#80C3) OR   // The required operating resources are currently occupied.
	                (tempStatusWord = word#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.
	                
	                
	                IF (statErrorCount >=  MAX_ERROR_COUNT) THEN
	                   statError := TRUE;
	                   statStateNumber :=  statFBSubState;
	                   statSubfunctionStatus :=  tempStatusWord;
	                   statStatus :=  ERR_RDREC_TEMP_COUNTER;
	                   statFBState :=  FB_ERROR;
	                ELSE
	                   statErrorCount :=  statErrorCount + usint#1;  // Increment internal error counter
	                   statFBSubStateOld :=  statFBSubState;
	                  // V1.3.2. If error 80A0 then should be retry with WRREC command
	                  IF (tempStatusWord = word#16#80A0) AND  statFBSubState =  FB_BUSY_RDREC_1 THEN
	                     statFBSubStateOld :=  FB_BUSY_WRREC_1;
	                  ELSIF (tempStatusWord = word#16#80A0) AND  statFBSubState =  FB_BUSY_RDREC_2 THEN
	                     statFBSubStateOld :=  FB_BUSY_WRREC_2;
	                  END_IF;
	                   statFBSubState :=  FB_BUSY_WAIT;
	                END_IF;
	              ELSE
	                 statError := TRUE;
	                 statStateNumber :=  statFBSubState;
	                 statSubfunctionStatus :=  tempStatusWord;
	                 statStatus :=  ERR_RDREC;
	                 statFBState :=  FB_ERROR;
	              END_IF; // Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
	              
	              // Error : Reference number of the request does not match with the response reference number 
	            ELSIF (statCmdBusy = FALSE) AND
	              (statRefNo <> statRespParameter.header.refNo) AND
	              (tempCmdValid = TRUE) THEN
	              
	               statError := TRUE;
	               statStateNumber :=  statFBSubState;
	               statStatus :=  ERR_REFERENCE_NO;
	               statFBState :=  FB_ERROR;
	              
	              // Error : Invalid response from the drive object (reqId: 16#01 - reading parameter successful; 16#81: reading parameter finished with error; 16#02: writing parameter sucessful; 16#82: writing parameter finished with error)  
	            ELSIF (statCmdBusy = FALSE) AND
	              NOT (statRespParameter.header.reqId = byte#16#81 OR  statRespParameter.header.reqId = byte#16#01 OR  statRespParameter.header.reqId = byte#16#02 OR  statRespParameter.header.reqId = byte#16#82) AND
	              (tempCmdValid = TRUE) THEN
	              
	               statError := TRUE;
	               statStateNumber :=  statFBSubState;
	               statStatus :=  ERR_RESPONSE_ID;
	               statFBState :=  FB_ERROR;
	              
	              // Error : The received number of parameters does not match with the requested number of parameters
	            ELSIF (statCmdBusy = FALSE) AND
	              (TO_INT(statRespParameter.header.parameterNo) <> 1) AND
	              (tempCmdValid = TRUE) THEN
	              
	               statError := TRUE;
	               statStateNumber :=  statFBSubState;
	               statStatus :=  ERR_PARAMETER_NO;
	               statFBState :=  FB_ERROR;
	              
	              // Error : The drive object does not match with the responsed DO
	            ELSIF (statCmdBusy = FALSE) AND
	              (statDoId <>  statRespParameter.header.doId) AND
	              (tempCmdValid = TRUE) THEN
	              
	               statError := TRUE;
	               statStateNumber :=  statFBSubState;
	               statStatus :=  ERR_DRIVE_OBJECT_NO;
	               statFBState :=  FB_ERROR;
	              
	              // No error occurred during reading parameters
	            ELSIF (statCmdBusy = FALSE) AND (tempCmdValid = TRUE) AND (statError = FALSE) THEN
	              
	              IF (statFBSubState =  FB_BUSY_RDREC_1) THEN
	                
	                // Analyse of the response buffer
	                 statParameter[0].format :=  statRespParameter.data[0];  // Format of the parameter
	                
	                // Format = Error 
	                IF (((TO_SINT(statRespParameter.data[0]) >  FORMAT_DOUBLE_WORD) OR
	                  ((TO_SINT(statRespParameter.data[0]) >  FORMAT_FLOATING_POINT) AND (TO_SINT(statRespParameter.data[0]) <  FORMAT_OCTET_STRING)) OR
	                  ((TO_SINT(statRespParameter.data[0]) >  FORMAT_OCTET_STRING) AND (TO_SINT(statRespParameter.data[0]) <  FORMAT_TIME_DIFFERENCE)) OR
	                  ((TO_SINT(statRespParameter.data[0]) >  FORMAT_TIME_DIFFERENCE) AND (TO_SINT(statRespParameter.data[0]) <  FORMAT_BYTE)) OR
	                  (TO_SINT(statRespParameter.data[0]) <  FORMAT_INTEGER_8))) AND (TO_SINT(statRespParameter.data[0]) <>  FORMAT_ZERO)
	                THEN
	                   statParameter[0].errorValue :=  statRespParameter.data[3];
	                  
	                ELSE
	                   statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostic
	                   errorValue :=  statParameter[0].errorValue;
	                END_IF; // Format = Error 
	                
	                 statCmdBusy := FALSE;
	                 statCmdError := FALSE;
	                 statFBState :=  FB_BUSY;
	                 statFBSubState :=  FB_BUSY_WRREC_2;
	                
	              ELSE
	                // Error occurred during writing process (changing parameter values) 
	                IF (statRespParameter.header.reqId = byte#16#82) THEN  // reqId: 16#82 (Error occurred during writing paramaters)
	                  
	                  // Parameter error
	                  IF (statRespParameter.data[0] =  FORMAT_ERROR) THEN
	                    
	                    // Save first parameter error in telegram
	                    IF (statFirstParameterError =  NO_PARAMETER_ERROR) THEN
	                       statFirstParameterError := 0;
	                       diagnostics.firstParameterError :=  statFirstParameterError;
	                       statError := TRUE;
	                       statStateNumber :=  statFBSubState;
	                       statStatus :=  ERR_PARAMETER;
	                       statFBState :=  FB_ERROR;
	                    END_IF;
	                    
	                     statParameter[0].errorValue :=  statRespParameter.data[3];
	                     diagnostics.errorValue :=  statParameter[0].errorValue; // V1.3.2
	                    
	                    // Parameter without errors  
	                  ELSE
	                     statParameter[0].errorValue := byte#16#FF;
	                  END_IF;
	                  
	                   errorValue :=  statParameter[0].errorValue;
	                END_IF; // Error occurred during writing process (changing parameter values)
	                
	                 statCmdBusy := FALSE;
	                 statCmdError := FALSE;
	                 statFBSubState :=  FB_BUSY_WRREC_1;
	                
	                // Next state is depending on the FB mode
	                IF (statWithoutResourceManager = FALSE) AND (statError = FALSE) THEN
	                   statStatus :=  STATUS_RELEASE;
	                   statFBState :=  FB_RELEASE;
	                  
	                ELSIF (statError = FALSE) THEN
	                   statStatus :=  STATUS_EXECUTION_FINISHED;
	                   statFBState :=  FB_DONE;
	                END_IF; //  statMode =  MODE_WITH_BUFFER_MANAGER
	              END_IF; //  statParameterConfig = TRUE
	            END_IF; //  statCmdError = TRUE
	            
	           FB_BUSY_WAIT:
	            // Timer for temporary errors
	             instIECTimer(signal :=  statTimerStart,
				 			duration :=  TIMER_TEMP_ERROR);
	            
	             statTimerStart := TRUE;
	            IF (instIECTimer.output = TRUE) THEN
	               statTimerStart := FALSE;
	               statFBSubState :=  statFBSubStateOld;
	            END_IF;
	            
	          ELSE
	             statError := TRUE;
	             statStatus :=  ERR_UNDEFINED_SUBSTATE;
	             statStateNumber :=  statFBState;
	             statFBState :=  FB_ERROR;
	        END_CASE;
	        
	      ELSE
	         statError := TRUE;
	         statStatus :=  ERR_COMMAND_TIMEOUT;
	         statStateNumber :=  statFBState;
	         statFBState :=  FB_ERROR;
	      END_IF; // ((buffer.element[statAllocatedIndex].enable = TRUE) AND (statMode =  MODE_WITH_BUFFER_MANAGER)) OR  statMode =  MODE_WITHOUT_BUFFER_MANAGER
	      
	     FB_RELEASE:
	      // Check buffer index for correctness
	      IF (statAllocatedIndex < 0) OR (statAllocatedIndex > typeconstantsint#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
	         statError := TRUE;
	         statStatus :=  ERR_INVALID_BUF_INDEX;
	         statStateNumber :=  statFBState;
	         statFBState :=  FB_ERROR;
	        
	      ELSIF (requestBuffer.header.lockBuffer = FALSE) THEN // V1.5.1
	         requestBuffer.header.lockBuffer := TRUE;
	        IF (requestBuffer.elements[statAllocatedIndex].state.%X0 = TRUE) THEN
	           requestBuffer.elements[statAllocatedIndex].state.%X2 := TRUE;
	        ELSE
	          ;
	        END_IF;
	         requestBuffer.header.lockBuffer := FALSE;
	         statStatus :=  STATUS_EXECUTION_FINISHED;
	         statFBState :=  FB_DONE;
	        
	      END_IF;
	      
	    ELSE
	       statError := TRUE;
	       statStatus :=  ERR_UNDEFINED_STATE;
	       statStateNumber :=  statFBState;
	       statFBState :=  FB_ERROR;
	  END_CASE;
	  
	  // If input execute is set during processing
	  IF  statWarningRetriggering = TRUE AND  statError = FALSE THEN
	     statStatus :=  WARN_EXECUTE_SET_DURING_PROCESSING;
	  END_IF;
	  
	END_IF; //  statBusy = TRUE
	
	
	//----------------------------------------------------------------------
	// Error handling and write outputs
	//----------------------------------------------------------------------
	
	// Edge detection
	statExecuteOld :=  execute;
	
	IF (statFBState =  FB_ERROR) THEN
	  // Release the allocated element when error occurs
	  IF (statStateNumber <>  FB_FIRST_CYCLE) AND (statStateNumber <>  FB_ALLOCATE)
	    AND (statBusy = TRUE) AND (statWithoutResourceManager = FALSE)
	  THEN
	    IF  requestBuffer.header.lockBuffer = FALSE THEN  // V1.5.1
	       requestBuffer.header.lockBuffer := TRUE;
	      IF (requestBuffer.elements[statAllocatedIndex].state.%X0 = TRUE) THEN
	         requestBuffer.elements[statAllocatedIndex].state.%X2 := TRUE;
	      ELSE
	        ;
	      END_IF;
	       requestBuffer.header.lockBuffer := FALSE;
	      
	      // Write diagnostics
	       diagnostics.stateNumber :=  statStateNumber;
	       diagnostics.subfunctionStatus :=  statSubfunctionStatus;
	       diagnostics.status :=  statStatus;
	       statBusy := FALSE;
	       statDone := FALSE;
	      
	    END_IF;
	    
	  ELSE
	    // Write diagnostics
	     diagnostics.stateNumber :=  statStateNumber;
	     diagnostics.subfunctionStatus :=  statSubfunctionStatus;
	     diagnostics.status :=  statStatus;
	     statBusy := FALSE;
	     statDone := FALSE;
	  END_IF;
	  
	  // FB finished request  
	ELSIF (statFBState =  FB_DONE) THEN
	  
	  // Output for one cycle minimum
	  IF (execute = FALSE) AND (statDone = TRUE) THEN
	     statDone := FALSE;
	     errorValue := byte#16#FF;
	     statStatus :=  STATUS_NO_CALL;
	     statFBState :=  FB_IDLE;
	  ELSE
	     statDone := TRUE;
	     statBusy := FALSE;
	  END_IF;
	  // If input execute is set during processing
	  IF  statWarningRetriggering = TRUE THEN
	     statStatus :=  ERR_AMBIGUOUS_FB_CALL;
	     diagnostics.status :=  statStatus;
	     statError := TRUE;
	     statDone := FALSE;
	  END_IF;
	END_IF;
	
	// Write static values to outputs
	IF  statBusy = FALSE OR  statError = FALSE
	THEN  // V1.5.1
	   error :=  statError;
	   status :=  statStatus;
	END_IF;
	
	busy :=  statBusy;
	done :=  statDone;
END_FUNCTION_BLOCK

END_NAMESPACE