USING system.timer;

NAMESPACE Simatic.Ax.LAcycCom

  CLASS OOPLAcycCom_ResourceManager
    IMPLEMENTS IResourcemanager
    VAR PRIVATE
      statResourceAddInfo    : ARRAY[0..RESOURCES_ARRAY_UPPER_LIM] OF LAcycCom_TypestatResourceAddInfo;
      instBufferLockWatchdog : ondelay;                                                                  // Watchdog timer for request buffer lock bit
      instRuntime            : ondelay;                                                                  // Timer for runtime measurement
      instCycleTime          : ondelay;                                                                  // Timer for detecting cycle time
      statIM0Data            : Typedata;                                                                 // Identification and maintanance data
      statNoOfUsedResources  : INT := 0;                                                                 // Number of used resources
      statUpperLimResources  : INT := 0;                                                                 // Upper limit of resources for acyclic communication
      statErrorUserCleared   : BOOL := FALSE;                                                            // Error occurred that can only be solved by user; rising edge at enable input is necessary
      statErrorAutoCleared   : BOOL := FALSE;                                                            // Error occurred that can be acknowledged by FB
      statEnableOld          : BOOL := FALSE;                                                            // Old value of enable for edge detection
      statDisabling          : BOOL := FALSE;                                                            // FB is disabled and currently finishing all requests
      instGetIMData          : Get_IM_Data;                                                              // Reading identification and maintanance data
      requestBuffer          : LAcycCom_typeRequestBuffer;                                               // Connection to the request buffer of the resource manager. All LAcycCom blocks have to use the same request buffer
      statdiagnostics        : LAcycCom_typeResourceManagerDiag;                                         // Diagnostics information
      status                 : WORD := STATUS_NO_CALL;                                                   // Current status of FB
      enable                 : BOOL := TRUE;                                                             // TRUE: Enable functionality of FB
    END_VAR
    VAR CONSTANT
      TIME_RUNTIME_TIMER          : TIME := T#1D;          // Maximum time for runtime timer
      STATUS_NO_CALL              : WORD := WORD#16#7000;  // No call of FB
      STATUS_FIRST_CALL           : WORD := WORD#16#7001;  // First call of FB after enabling
      STATUS_SUBSEQUENT_CALL      : WORD := WORD#16#7002;  // Subsequent call of FB
      STATUS_BUFFER_FULL          : WORD := WORD#16#7003;  // Buffer is full; no more elements can be added
      WARN_BUFFER_LOCKED          : WORD := WORD#16#7100;  // Buffer lock time expired; lock is reset by FB
      WARN_WRONG_HARDWARE_ID      : WORD := WORD#16#7101;  // Internal called system instruction LOG2GEO returned an error (The address specified at the LADDR parameter is invalid)
      MAX_NO_OF_RESOURCES_1200_V4 : INT  := 4;             // Maximum number of resources for acyclic communication when using a 1200 CPU (Firmware V4.x)
      MAX_NO_OF_RESOURCES_1500_V1 : INT  := 10;            // Maximum number of resources for acyclic communication when using a 1500 CPU (Firmware V1.x)
      MAX_NO_OF_RESOURCES_1500_V2 : INT  := 20;            // Maximum number of resources for acyclic communication when using a 1500 CPU (Firmware V2.x)
      RESOURCES_ARRAY_UPPER_LIM   : INT  := 19;            // Upper limit of actualEnableIndexes array in PLC data type LAcycCom_typeRequestBuffer
    END_VAR

    METHOD PUBLIC execute
      VAR_INPUT
        config : LAcycCom_typeResourceManagerConf; // Configuration structure of ResourceManager FB
      END_VAR
      VAR_TEMP
        tempCurGeoAddr           : typeGEOADDR;                       // Current Geo Address information
        tempCurReqState          : LAcycCom_TypestattempCurReqState;  // Current state of the request
        tempCurRuntime           : TIME;                              // Current runtime for FB
        tempCycleTime            : TIME;                              // Current cycle time
        tempCurQueueTime         : TIME;                              // Current queue time
        tempNoOfRequests         : INT;                               // Number of requests
        tempFirstQueueElement    : INT;                               // First element in current queue
        tempIndex                : INT;                               // Index for loop handling
        tempNoOfFreeResources    : INT;                               // Number of free resources
        tempActBufferIndex       : INT;                               // Actual index of buffer element
        tempQueueElementPrevious : INT;                               // Queue element before current element
        tempQueueElementNext     : INT;                               // Queue element after current element
        tempRetVal               : INT;                               // Return value of system functions
        tempByte                 : BYTE;                              // Temporary byte variable for slice command
        tempStationInUse         : BOOL;                              // Station is already processing with acyclic communication
      END_VAR
      //Check if FB is been disabled
      IF NOT enable AND statEnableOld THEN
        //Check if no request is executed at the moment
        IF (statNoOfUsedResources <= 0) OR statErrorUserCleared THEN
          requestBuffer.header.lockBuffer := TRUE;
          requestBuffer.header.numberOfRequests := -1;
          requestBuffer.header.nextFreeElement := -1;
          FOR tempIndex := 0 TO RESOURCES_ARRAY_UPPER_LIM DO
            requestBuffer.header.activeRequests[tempIndex].bufferIndex := -1;
            requestBuffer.header.activeRequests[tempIndex].maxAssignedTime := config.maxAssignedTime;
            statResourceAddInfo[tempIndex].IOSystem := -1;
            statResourceAddInfo[tempIndex].station := -1;
          END_FOR;
          //Error outputs are reset with falling edge of enable input
          statErrorUserCleared := FALSE;
          statErrorAutoCleared := FALSE;
          statDisabling := FALSE;
          status := STATUS_NO_CALL;
          //Set old value of enable for edge detection and end execution
          statEnableOld := enable;
          RETURN;
        ELSE
          // Wait for requests to be finished
          statDisabling := TRUE;
        END_IF;
//Check if FB is enabled
      ELSIF (enable AND NOT statEnableOld AND NOT statDisabling) THEN
        requestBuffer.header.lockBuffer := TRUE;
        requestBuffer.header.numberOfRequests := 0;
        requestBuffer.header.nextFreeElement := 0;
        requestBuffer.header.firstQueueElement := -1;
        instRuntime(signal := FALSE, duration := TIME_RUNTIME_TIMER);
        instCycleTime(signal := FALSE, duration := TIME_RUNTIME_TIMER);
        instBufferLockWatchdog(signal := FALSE, duration := TIME_RUNTIME_TIMER);
        statdiagnostics.maxNoOfRequests := UINT#0;
        statdiagnostics.maxRuntime := t#0s;
        FOR tempIndex := 0 TO LAcycComConstantsInt#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM DO
          requestBuffer.elements[tempIndex].state := BYTE#16#00;
          requestBuffer.elements[tempIndex].hardwareId := HW_IO#default;
          requestBuffer.elements[tempIndex].queueElementNext := -1;
          requestBuffer.elements[tempIndex].queueElementPrevious := -1;
          requestBuffer.elements[tempIndex].queueTime := T#0s;
        END_FOR;
        FOR tempIndex := 0 TO RESOURCES_ARRAY_UPPER_LIM DO
          requestBuffer.header.activeRequests[tempIndex].bufferIndex := -1;
          requestBuffer.header.activeRequests[tempIndex].maxAssignedTime := config.maxAssignedTime;
          statResourceAddInfo[tempIndex].IOSystem := -1;
          statResourceAddInfo[tempIndex].station := -1;
        END_FOR;
        REPEAT
          // Set maximum number of resources from I&M Data
          instGetIMData(LADDR := word#50, IM_TYPE := UINT#0, DATA := statIM0Data);
        UNTIL (instGetIMData.DONE) OR (instGetIMData.ERROR) END_REPEAT;
        IF instGetIMData.DONE THEN
          IF (statIM0Data.Order_ID[6] = '2') THEN
            // Order ID of 1200 CPU detected
            statUpperLimResources := MAX_NO_OF_RESOURCES_1200_V4 - 1;
          ELSE
            // If no 1200 CPU it have to be a 1500 CPU or a 1500 Software controller
            IF (statIM0Data.Software_Revision.Functional >= 2) THEN
              statUpperLimResources := MAX_NO_OF_RESOURCES_1500_V2 - 1; // Firmware V2.x
            ELSE
              statUpperLimResources := MAX_NO_OF_RESOURCES_1500_V1 - 1; // Firmware V1.x
            END_IF;
          END_IF;
        ELSE
          // If no I&M data coul be read, use the lower number of resources
          statUpperLimResources := MAX_NO_OF_RESOURCES_1200_V4 - 1;
        END_IF;
        // Check if resource array is shorter then possible resources
        IF (statUpperLimResources > RESOURCES_ARRAY_UPPER_LIM) THEN
          statUpperLimResources := RESOURCES_ARRAY_UPPER_LIM;
        END_IF;
        requestBuffer.header.lockBuffer := FALSE;
        status := STATUS_FIRST_CALL; //Set status for first call
        statEnableOld := enable; //Set old value of enable for edge detection and end execution
        RETURN;
//Check if user cleared error in FB occurred
      ELSIF statErrorUserCleared THEN
        statEnableOld := enable;
        //No set of status necessary, because status already set when error occurred
        RETURN;
//Check if function block is disabled
      ELSIF NOT enable AND NOT statDisabling THEN
        status := STATUS_NO_CALL;
        statEnableOld := enable;
        RETURN;
      ELSE
        // Reset automatically cleared errors
        statErrorAutoCleared := FALSE;
        //Detect edge for disabling
        statEnableOld := enable;
      END_IF;
      //----------------------------------------------------------------------------------------------
      // Get current runtime
      instRuntime(signal := TRUE, duration := TIME_RUNTIME_TIMER);
      // Cycle time measurement
      instCycleTime(signal := TRUE, duration := TIME_RUNTIME_TIMER);
      tempCycleTime := TO_TIME(instCycleTime.elapsedTime);
      instCycleTime(signal := FALSE, duration := TIME_RUNTIME_TIMER);
      instCycleTime(signal := TRUE, duration := TIME_RUNTIME_TIMER);
      // Watchdog for lock of complete buffer DB
      instBufferLockWatchdog(signal := requestBuffer.header.lockBuffer, duration := config.timeoutBufferLock);
      // Check if buffer was locked too long
      IF instBufferLockWatchdog.output THEN
        statErrorAutoCleared := TRUE;
        requestBuffer.header.lockBuffer := FALSE;
        status := WARN_BUFFER_LOCKED;
      ELSIF requestBuffer.header.lockBuffer THEN
        ; // Do nothing until buffer is unlocked
      ELSE
        requestBuffer.header.lockBuffer := TRUE;
        //----------------------------------------------------------------------------------------------
        // Release elements blocking resources
        //----------------------------------------------------------------------------------------------
        statNoOfUsedResources := 0;
        tempFirstQueueElement := requestBuffer.header.firstQueueElement;
        // Check and release buffer items
        FOR tempIndex := 0 TO statUpperLimResources DO
          tempActBufferIndex := requestBuffer.header.activeRequests[tempIndex].bufferIndex;
          // Check if current index is used for a resource
          IF (tempActBufferIndex >= 0) THEN
            tempByte := requestBuffer.elements[tempActBufferIndex].state;
            tempCurReqState.allocated := tempByte.%X0;
            tempCurReqState.assigned := tempByte.%X1;
            tempCurReqState.release := tempByte.%X2;
            tempCurReqState.rejected := tempByte.%X3;
            // Check if resource can be released
            IF tempCurReqState.release THEN
              tempQueueElementPrevious := requestBuffer.elements[tempActBufferIndex].queueElementPrevious;
              tempQueueElementNext := requestBuffer.elements[tempActBufferIndex].queueElementNext;
              IF (tempQueueElementPrevious = -1) AND (tempQueueElementNext = -1) THEN
                // Only element in queue; Reset pointer for first element
                tempFirstQueueElement := -1;
                requestBuffer.header.firstQueueElement := -1;
              ELSIF (tempQueueElementPrevious = -1) THEN
                // Element was first element in queue
                requestBuffer.elements[tempQueueElementNext].queueElementPrevious := -1;
                requestBuffer.header.firstQueueElement := tempQueueElementNext;
                tempFirstQueueElement := tempQueueElementNext;
              ELSIF (tempQueueElementNext = -1) THEN
                // Element was last element in queue
                requestBuffer.elements[tempQueueElementPrevious].queueElementNext := -1;
              ELSE
                // Current element has a previous and next element
                requestBuffer.elements[tempQueueElementNext].queueElementPrevious := tempQueueElementPrevious;
                requestBuffer.elements[tempQueueElementPrevious].queueElementNext := tempQueueElementNext;
              END_IF;
              requestBuffer.elements[tempActBufferIndex].state := BYTE#16#00;
              requestBuffer.elements[tempActBufferIndex].hardwareId := HW_IO#default;
              requestBuffer.elements[tempActBufferIndex].queueElementPrevious := -1;
              requestBuffer.elements[tempActBufferIndex].queueElementNext := -1;
              requestBuffer.elements[tempActBufferIndex].queueTime := T#0s;
              requestBuffer.header.activeRequests[tempIndex].bufferIndex := -1;
              requestBuffer.header.activeRequests[tempIndex].maxAssignedTime := config.maxAssignedTime;
              statResourceAddInfo[tempIndex].IOSystem := -1;
              statResourceAddInfo[tempIndex].station := -1;
              // Check if buffer was full when last element tries to allocate
              IF (requestBuffer.header.nextFreeElement < 0) THEN
                // Set actual write index to current released element
                requestBuffer.header.nextFreeElement := tempActBufferIndex;
              END_IF;
            ELSE
              statNoOfUsedResources := statNoOfUsedResources + 1;
            END_IF; // tempCurReqState.release
          ELSE
            ; // Check next resource
          END_IF; // (tempActBufferIndex >= 0)
        END_FOR;
        tempNoOfFreeResources := statUpperLimResources - statNoOfUsedResources; // Calculate free resources
        //----------------------------------------------------------------------------------------------
        // Release other elements and assign resources to elements
        //----------------------------------------------------------------------------------------------
        tempActBufferIndex := tempFirstQueueElement;
        tempNoOfRequests := 0;
        WHILE (tempActBufferIndex >= 0) DO
          tempQueueElementNext := requestBuffer.elements[tempActBufferIndex].queueElementNext; // Set next element
          tempByte := requestBuffer.elements[tempActBufferIndex].state;
          tempCurReqState.allocated := tempByte.%X0;
          tempCurReqState.assigned := tempByte.%X1;
          tempCurReqState.release := tempByte.%X2;
          tempCurReqState.rejected := tempByte.%X3;
          // Check if resource can be released
          IF tempCurReqState.release THEN
            tempQueueElementPrevious := requestBuffer.elements[tempActBufferIndex].queueElementPrevious;
            IF (tempQueueElementPrevious = -1) AND (tempQueueElementNext = -1) THEN
              // Only element in queue; Reset pointer for first element
              tempFirstQueueElement := -1;
              requestBuffer.header.firstQueueElement := -1;
            ELSIF (tempQueueElementPrevious = -1) THEN
              // Element was first element in queue
              requestBuffer.elements[tempQueueElementNext].queueElementPrevious := -1;
              tempFirstQueueElement := tempQueueElementNext;
              requestBuffer.header.firstQueueElement := tempQueueElementNext;
            ELSIF (tempQueueElementNext = -1) THEN
              // Element was last element in queue
              requestBuffer.elements[tempQueueElementPrevious].queueElementNext := -1;
            ELSE
              // Current element has a previous and next element
              requestBuffer.elements[tempQueueElementNext].queueElementPrevious := tempQueueElementPrevious;
              requestBuffer.elements[tempQueueElementPrevious].queueElementNext := tempQueueElementNext;
            END_IF;
            requestBuffer.elements[tempActBufferIndex].state := Byte#16#00;
            requestBuffer.elements[tempActBufferIndex].hardwareId := HW_IO#default;
            requestBuffer.elements[tempActBufferIndex].queueElementPrevious := -1;
            requestBuffer.elements[tempActBufferIndex].queueElementNext := -1;
            requestBuffer.elements[tempActBufferIndex].queueTime := T#0s;
            FOR tempIndex := 0 TO RESOURCES_ARRAY_UPPER_LIM DO // V1.1.2
              IF requestBuffer.header.activeRequests[tempIndex].bufferIndex = tempActBufferIndex THEN
                requestBuffer.header.activeRequests[tempIndex].bufferIndex := -1;
                requestBuffer.header.activeRequests[tempIndex].maxAssignedTime := config.maxAssignedTime;
                statResourceAddInfo[tempIndex].IOSystem := -1;
                statResourceAddInfo[tempIndex].station := -1;
                EXIT;
              END_IF;
            END_FOR;
            // Check if buffer was full when last element tries to allocate
            IF (requestBuffer.header.nextFreeElement < 0) THEN
              // Set actual write index to current released element
              requestBuffer.header.nextFreeElement := tempActBufferIndex;
            END_IF;
          ELSE // NOT  tempCurReqState.release
            // Count elements and go to next element
            tempNoOfRequests := tempNoOfRequests + 1;
            // Calculate queue time of current request
            tempCurQueueTime := tempCycleTime + requestBuffer.elements[tempActBufferIndex].queueTime;
            requestBuffer.elements[tempActBufferIndex].queueTime := tempCurQueueTime;
            // Check if resource was already assigned
            IF tempCurReqState.assigned THEN
              FOR tempIndex := 0 TO statUpperLimResources DO
                IF (requestBuffer.header.activeRequests[tempIndex].bufferIndex = tempActBufferIndex) THEN
                  // Choose maxAssignedTime of resource
                  IF (requestBuffer.header.activeRequests[tempIndex].maxAssignedTime >= config.maxAssignedTime) THEN
                    ; // do nothing
// Choose global maxAssignedTime
                  ELSE
                    requestBuffer.header.activeRequests[tempIndex].maxAssignedTime := config.maxAssignedTime;
                  END_IF;
                  EXIT;
                END_IF;
              END_FOR;
              IF (tempCurQueueTime < requestBuffer.header.activeRequests[tempIndex].maxAssignedTime) THEN
                ; // Everything okay
              ELSIF (tempCurQueueTime < (requestBuffer.header.activeRequests[tempIndex].maxAssignedTime + config.delayReleaseAfterReject)) THEN
                // Current element is over queue time
                requestBuffer.elements[tempActBufferIndex].state.%X3 := TRUE; // Request rejected
              ELSE
                // Current element is over queue time and is released in next cycle
                requestBuffer.elements[tempActBufferIndex].state.%X2 := TRUE; // Request release
              END_IF;
// Check if block is disabled and reject all new requests
            ELSIF (statDisabling) THEN
              // Current element is rejected cause function block is disabled
              requestBuffer.elements[tempActBufferIndex].state.%X3 := TRUE; // Request rejected
              // If current time is over the delay, release the request asap
              IF (tempCurQueueTime > config.delayReleaseAfterReject) THEN
                requestBuffer.elements[tempActBufferIndex].state.%X2 := TRUE; // Request release
              END_IF;
            ELSE
              // Check if device for hardware address is already in used by a other request
              tempRetVal := LOG2GEO(LADDR := requestBuffer.elements[tempActBufferIndex].hardwareId, GEOADDR => tempCurGeoAddr);
              // Check if everything is okay
              IF tempRetVal <> 0 THEN
                requestBuffer.elements[tempActBufferIndex].state.%X3 := TRUE; // Request rejected because of error in system function
                statErrorAutoCleared := TRUE;
                status := WARN_WRONG_HARDWARE_ID;
              ELSE
                ; // Everything okay
              END_IF;
              // Check if hardware is already in use
              tempStationInUse := FALSE;
              FOR tempIndex := 0 TO statUpperLimResources DO
                // Check if station is already in use by a request
                IF (statResourceAddInfo[tempIndex].IOSystem = TO_INT(tempCurGeoAddr.IOSYSTEM)) AND (statResourceAddInfo[tempIndex].station = TO_INT(tempCurGeoAddr.STATION)) THEN
                  tempStationInUse := TRUE;
                  EXIT;
                ELSE
                  ; // Check next element
                END_IF;
              END_FOR;
              // Check if station can be enabled
              IF NOT tempStationInUse THEN
                // Search for free resource
                FOR tempIndex := 0 TO statUpperLimResources DO
                  // Check for free slot
                  IF (statResourceAddInfo[tempIndex].IOSystem = -1) AND (statResourceAddInfo[tempIndex].station = -1) THEN
                    // Set information and enable request
                    statResourceAddInfo[tempIndex].IOSystem := TO_INT(tempCurGeoAddr.IOSYSTEM);
                    statResourceAddInfo[tempIndex].station := TO_INT(tempCurGeoAddr.STATION);
                    requestBuffer.elements[tempActBufferIndex].queueTime := T#0s;
                    requestBuffer.elements[tempActBufferIndex].state.%X1 := TRUE; // Resource assigned to request
                    requestBuffer.header.activeRequests[tempIndex].bufferIndex := tempActBufferIndex;
                    statNoOfUsedResources := statNoOfUsedResources + 1;
                    tempNoOfFreeResources := tempNoOfFreeResources - 1;
                    EXIT;
                  ELSE
                    ; // Check next element
                  END_IF;
                END_FOR;
              ELSE
                // Current request can not be added, because other request is active on station
                IF (tempCurQueueTime < config.maxQueueTime) THEN
                  ; // Everything okay
                ELSIF (tempCurQueueTime < (config.maxQueueTime + config.delayReleaseAfterReject)) THEN
                  // Current element is over queue time
                  requestBuffer.elements[tempActBufferIndex].state.%X3 := TRUE; // Request rejected
                ELSE
                  // Current element is over queue time and is released in next cycle
                  requestBuffer.elements[tempActBufferIndex].state.%X2 := TRUE; // Request released
                END_IF;
              END_IF; // tempCurReqState.assigned
            END_IF; // NOT tempStationInUse
          END_IF; //  tempCurReqState.release
          tempActBufferIndex := tempQueueElementNext; // Switch to next buffer element
        END_WHILE;
        requestBuffer.header.lockBuffer := FALSE;
        // Check if block can be disabled
        IF (statDisabling AND (tempNoOfRequests = 0)) THEN
          statDisabling := FALSE; // Reset disabling bit
          // Initialize buffer and FB
          requestBuffer.header.lockBuffer := TRUE;
          requestBuffer.header.numberOfRequests := -1;
          requestBuffer.header.nextFreeElement := -1;
          FOR tempIndex := 0 TO RESOURCES_ARRAY_UPPER_LIM DO
            requestBuffer.header.activeRequests[tempIndex].bufferIndex := -1;
            requestBuffer.header.activeRequests[tempIndex].maxAssignedTime := config.maxAssignedTime;
            statResourceAddInfo[tempIndex].IOSystem := -1;
            statResourceAddInfo[tempIndex].station := -1;
          END_FOR;
          //Error outputs are reset with falling edge of enable input
          statErrorUserCleared := FALSE;
          statErrorAutoCleared := FALSE;
          status := STATUS_NO_CALL;
        ELSE
          requestBuffer.header.numberOfRequests := tempNoOfRequests;
        END_IF;
        // Calculate runtime
        instRuntime(signal := TRUE, duration := TIME_RUNTIME_TIMER);
        tempCurRuntime := TO_TIME(instRuntime.elapsedTime);
        instRuntime(signal := FALSE, duration := TIME_RUNTIME_TIMER);
        statdiagnostics.curRuntime := tempCurRuntime;
        IF (tempCurRuntime > statdiagnostics.maxRuntime) THEN
          statdiagnostics.maxRuntime := tempCurRuntime;
        END_IF;
        // Set maximum number of requests
        IF (tempNoOfRequests > TO_INT(statdiagnostics.maxNoOfRequests)) THEN
          statdiagnostics.maxNoOfRequests := TO_UINT(tempNoOfRequests);
        END_IF;
      END_IF; // statFBBufferWatchdog.Q
      //----------------------------------------------------------------------------------------------
      //Error handling
      //----------------------------------------------------------------------------------------------
      IF statErrorUserCleared THEN
        ;
        RETURN;
      ELSIF statErrorAutoCleared THEN
        ;
        RETURN;
      ELSE
        //Process normal output values
        IF (tempNoOfRequests > LAcycComConstantsInt#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
          status := STATUS_BUFFER_FULL; // Buffer is full at the moment
        ELSE
          status := STATUS_SUBSEQUENT_CALL; //Set status for subsequent call
        END_IF;
      END_IF;
      statdiagnostics.status := status;
      //----------------------------------------------------------------------------------------------
      IF status = STATUS_NO_CALL THEN
        enable := TRUE;
      END_IF;
    END_METHOD

    METHOD Reset // Disable Funkction, function get automatic enabled
      enable := FALSE;
    END_METHOD

    METHOD PUBLIC Allocate : INT //AllocatedIndex
      VAR_INPUT
        hardwareId : HW_IO := HW_IO#default; // Hardware identifier of the hardware module
      END_VAR
      VAR_TEMP
        tempLoopIndex : INT;
        tempLastQueueElement : INT;
      END_VAR
      IF (requestBuffer.header.lockBuffer = FALSE) AND (requestBuffer.header.nextFreeElement >= 0) AND (requestBuffer.header.nextFreeElement <= LAcycComConstantsInt#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
        requestBuffer.header.lockBuffer := TRUE;
        Allocate := requestBuffer.header.nextFreeElement;
        requestBuffer.elements[Allocate].state := byte#16#00;
        requestBuffer.elements[Allocate].state.%X0 := TRUE;
        requestBuffer.elements[Allocate].hardwareId := hardwareId;
        requestBuffer.elements[Allocate].queueElementNext := -1;
        // Build up queue
        IF (requestBuffer.header.firstQueueElement >= 0) THEN
          // Find last queue element
          tempLoopIndex := requestBuffer.header.firstQueueElement;
          WHILE (tempLoopIndex >= 0) DO
            tempLastQueueElement := tempLoopIndex;
            tempLoopIndex := requestBuffer.elements[tempLoopIndex].queueElementNext;
          END_WHILE;
          // Insert into list after last element
          requestBuffer.elements[tempLastQueueElement].queueElementNext := Allocate;
          requestBuffer.elements[Allocate].queueElementPrevious := tempLastQueueElement;
        ELSE
          // Element is first element in queue
          requestBuffer.header.firstQueueElement := Allocate;
          requestBuffer.elements[Allocate].queueElementPrevious := -1;
        END_IF;
        // Searching for the next free request element
        FOR tempLoopIndex := 0 TO LAcycComConstantsInt#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM DO
          IF (requestBuffer.elements[tempLoopIndex].state.%X0 = FALSE) THEN
            requestBuffer.header.nextFreeElement := tempLoopIndex;
            EXIT;
          END_IF;
          // All request elements are occupied
          IF (tempLoopIndex = LAcycComConstantsInt#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
            requestBuffer.header.nextFreeElement := LAcycComConstantsInt#ALL_ELEMENTS_OCCUPIED;
          END_IF;
        END_FOR;
        requestBuffer.header.lockBuffer := FALSE;
      ELSE
        Allocate := -1; // Waiting until lockbit is reset and a request element is available
      END_IF; // (buffer.lockBuffer = FALSE) AND (buffer.actualWriteIndex >= 0)
    END_METHOD

    METHOD PUBLIC GetRessource : LAcycCom_ResourceManagerRetval
      VAR_INPUT
        AllocatedIndex : INT := -1;
      END_VAR
      // Check buffer index for correctness
      IF (AllocatedIndex < 0) OR (AllocatedIndex > LAcycComConstantsInt#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
        GetRessource := LAcycCom_ResourceManagerRetval#ERR_INVALID_BUF_INDEX;
      ELSE
        IF (requestBuffer.elements[AllocatedIndex].state.%X0 = FALSE) OR (requestBuffer.elements[AllocatedIndex].state.%X3 = TRUE) THEN
          // Request was rejected by buffer manager
          GetRessource := LAcycCom_ResourceManagerRetval#ERR_REQUEST_REJECTED;
        ELSIF (requestBuffer.elements[AllocatedIndex].state.%X2 = TRUE) THEN
          // Request already released
          GetRessource := LAcycCom_ResourceManagerRetval#ERR_RESOURCE_RELEASED;
        ELSIF (requestBuffer.elements[AllocatedIndex].state.%X1 = TRUE) THEN
          // Element is enabled
          GetRessource := LAcycCom_ResourceManagerRetval#STATUS_BUSY;
        ELSE
          // Element not enabled yet
          GetRessource := LAcycCom_ResourceManagerRetval#STATUS_GET_RESOURCE;
        END_IF;
      END_IF;
    END_METHOD

    METHOD PUBLIC Release : LAcycCom_ResourceManagerRetval
      VAR_INPUT
        AllocatedIndex : INT;
      END_VAR
      IF (AllocatedIndex < 0) OR (AllocatedIndex > LAcycComConstantsInt#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM) THEN
        Release := LAcycCom_ResourceManagerRetval#ERR_INVALID_BUF_INDEX;
      ELSIF (requestBuffer.header.lockBuffer = FALSE) THEN // V1.5.1
        requestBuffer.header.lockBuffer := TRUE;
        IF (requestBuffer.elements[AllocatedIndex].state.%X0 = TRUE) THEN
          requestBuffer.elements[AllocatedIndex].state.%X2 := TRUE;
        ELSE
          ;
        END_IF;
        Release := LAcycCom_ResourceManagerRetval#STATUS_EXECUTION_FINISHED;
        requestBuffer.header.lockBuffer := FALSE;
      END_IF;
    END_METHOD

    METHOD PUBLIC diagnostics : LAcycCom_typeResourceManagerDiag
      ;
      diagnostics := statdiagnostics;
    END_METHOD
  END_CLASS

END_NAMESPACE
