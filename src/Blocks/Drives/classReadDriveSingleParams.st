using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom
    CLASS LAcycCom_classReadDriveSingleParams EXTENDS ReadWriteParameter
        var Private
            statparameterNumber : UInt;   // Number of the parameter
            statindex : UInt;   // Parameter index
            statParameter   : Array[0..READ_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatstatParameter;   // Parameter dataset
            parameterAddress   : Array[0..READ_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatparameterAddress;   // Parameter data in telegram
        end_VAR
       
        VAR CONSTANT
          READ_PARAMETERS_UPPER_LIM : int := 0;
        end_var

        METHOD OVERRIDE BUSY
            VAR_TEMP
                tempCmdValid : Bool;   // TRUE: New data record was received and is valid
                tempStatusWord : Word;   // Temporary status
                tempWord : Word;   // Temporary word variable
                tempPointer : Int;   // Temporary pointer variable
                tempLoopIndex : Int;   // Temporary loop index variable
                tempBlkVariant : Int;   // Temporary result of MOVE_BLK_VARIANT
                tempCmdStatus : DWord;   // Temporary status of WRREC and RDREC command
                tempDWord : DWord;   // Temporary DWord variable
                tempVoidHeader : LAcycCom_Typestatheader;   // Temporary empty header structure
                tempActualElementReal : LAcycCom_typeDriveDataset;   // Temporary element of the dataset (real values)
             END_VAR
             IF (statrequestBuffer.GetRessource(statAllocatedIndex)=LAcycCom_ResourceManagerRetval#STATUS_BUSY) THEN

               CASE statFBSubState OF
                LAcycCom_ReadWriteStatus#FB_GET_SUBSTATE:
                    statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;

                LAcycCom_ReadWriteStatus#FB_BUSY_WRREC:  // Writing the dataset configuration into the drive object

                   IF  (statCmdBusy = FALSE) THEN
                     // Resets WRREC command
                     instWRREC(request := FALSE,
                               RECORD := atmpSend);


                     // Creating header data
                     statReqParameter.header.refNo := statRefNo; // Telegram reference number
                     statReqParameter.header.reqId := byte#16#01;  // 0x01 = request parameters
                     statReqParameter.header.doId := statDoId;  // Drive object identification number
                     statReqParameter.header.parameterNo := byte#16#01;  // Count of parameters

                     // Copying the dataset into a static variable
                     statParameter[tempLoopIndex].index := statindex;
                     statParameter[tempLoopIndex].parameterNo := statParameterNumber;
                     statReqParameter.parameterAddress[tempLoopIndex].parameterNo := statParameter[tempLoopIndex].parameterNo;  // Parameter number
                     statReqParameter.parameterAddress[tempLoopIndex].index := statParameter[tempLoopIndex].index;  // Subindex of parameter

                   END_IF; // statCmdBusy = FALSE

                   // WRREC command
                 SerializeBig(uint#0,
                             statReqParameter,
                             atmpSend );

                   instWRREC(REQUEST := TRUE,                                                 // Transfer data record
                              ID := statHwId,                                                 // ID number of the hardware component
                              INDEX := statDataRecordNo,                                                     // Data record number
                              LENGTH := uint#0,                                                        // Maximum length of the data record to be transferred in bytes
                              DONE => statCmdDone,                                            // Data record was transferred
                              BUSY => statCmdBusy,                                            // The writing process is not yet complete
                              ERROR => statCmdError,                                          // An error occurred during the writing process
                              STATUS => tempCmdStatus,                                        // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                              RECORD := atmpSend);                                    // Data record



                   // Error occurred
                   IF  (statCmdError = TRUE) AND   not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                     tempStatusWord.%B0 := tempCmdStatus.%B1;
                     tempStatusWord.%B1 := tempCmdStatus.%B2;

                     // Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                     IF  (tempStatusWord = word#16#80A1) OR  // Negative acknowledgment when writing to the module
                        (tempStatusWord = word#16#80A7) OR   // DP slave or module is occupied (temporary error)
                        (tempStatusWord = word#16#80B5) OR   // DP slave or module not ready
                        (tempStatusWord = word#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
                        (tempStatusWord = word#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.
                        (tempStatusWord = word#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                        (tempStatusWord = word#16#80C3) OR   // The required operating resources are currently occupied.
                        (tempStatusWord = word#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.

                       IF  (statErrorCount >= MAX_ERROR_COUNT) THEN

                         statStateNumber := statFBSubState;
                         statSubfunctionStatus := tempStatusWord;
                         statStatus := ERR_WRREC_TEMP_COUNTER;
                         statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;
                       ELSE
                         statErrorCount := statErrorCount + uint#1;  // Increment internal error counter
                         statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
                         statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WAIT;
                       END_IF;
                     ELSE

                       statStateNumber := statFBSubState;
                       statSubfunctionStatus := tempStatusWord;
                       statStatus := ERR_WRREC;
                       statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;
                     END_IF;

                   ELSIF  (statCmdDone = TRUE) AND   not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN  // Processing completed without errors
                     statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_RDREC; // WRREC completed and continue with RDREC
                     statErrorCount := UINT#0;  // V1.5.1 Reset error counter
                   END_IF; // statCmdError = TRUE

                   LAcycCom_ReadWriteStatus#FB_BUSY_RDREC:  // Reading the values from the drive object
                   // Resets RDREC command
                   IF  (statCmdBusy = FALSE) THEN
                     instRDREC(request := FALSE,
                                RECORD := atmpRec);
                   END_IF;

                   instRDREC(REQUEST := True,                                                 // Transfer data record
                              ID := statHwId,                                                 // ID number of the hardware component
                              INDEX := statDataRecordNo,                                      // Data record number
                              MAXLENGTH := uint#0,                                            // Maximum length in bytes of the data record information to be read
                              VALID => tempCmdValid,                                          // New data record was received and is valid
                              BUSY => statCmdBusy,                                            // The reading process is not yet complete
                              ERROR => statCmdError,                                          // An error occurred during the reading process
                              STATUS => tempCmdStatus,                                        // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                              RECORD := atmpRec);                                             // Destination area for the data record read

                             DeserializeBig(uint#0,
                              atmpRec,
                              statRespParameter);

                               // Destination aapaarea for the data record read

                   // Error occurred
                   IF  (statCmdError = TRUE) THEN
                     // Get the error information from the status information
                     tempStatusWord.%B0 := tempCmdStatus.%B1;
                     tempStatusWord.%B1 := tempCmdStatus.%B2;

                     // Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                     IF  (tempStatusWord = word#16#80A0) OR  // Negative acknowledgment when reading the module
                        (tempStatusWord = word#16#80A7) OR   // DP slave or module is occupied (temporary error)
                        (tempStatusWord = word#16#80B5) OR   // DP slave or module not ready
                        (tempStatusWord = word#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
                        (tempStatusWord = word#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.
                        (tempStatusWord = word#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                        (tempStatusWord = word#16#80C3) OR   // The required operating resources are currently occupied.
                        (tempStatusWord = word#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.

                       IF  (statErrorCount >= MAX_ERROR_COUNT) THEN

                         statStateNumber := statFBSubState;
                         statSubfunctionStatus := tempStatusWord;
                         statStatus := ERR_RDREC_TEMP_COUNTER;
                         statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;
                       ELSE
                         statErrorCount := statErrorCount + uint#1;  // Increment internal error counter
                         statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_RDREC;
                         // V1.3.2. If error 80A0 then should be retry with WRREC command
                         IF  (tempStatusWord = word#16#80A0) THEN
                           statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
                         END_IF;
                         statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WAIT;
                       END_IF; // statErrorCount >= MAX_ERROR_COUNT
                     ELSE

                       statStateNumber := statFBSubState;
                       statSubfunctionStatus := tempStatusWord;
                       statStatus := ERR_RDREC;
                       statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;
                     END_IF;

                     // Error : Reference number of the request does not match with the response reference number
                   ELSIF  (statCmdBusy = FALSE) AND
                      (statRefNo <> statRespParameter.header.refNo) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_REFERENCE_NO;
                     statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;

                     // Error : Invalid response from the drive object (reqId: 16#01 - reading parameter successful; 16#81: reading parameter finished with error)
                   ELSIF NOT  (statRespParameter.header.reqId = byte#16#81 OR statRespParameter.header.reqId = byte#16#01) AND
                      (statCmdBusy = FALSE) AND
                      (tempCmdValid = TRUE) THEN

                     statStateNumber := statFBSubState;
                     statStatus := ERR_RESPONSE_ID;
                     statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;

                     // Error : The received number of parameters does not match with the requested number of parameters
                   ELSIF  (statCmdBusy = FALSE) AND
                     (TO_INT(statRespParameter.header.parameterNo) <> 1) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_PARAMETER_NO;
                     statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;

                     // Error : The drive object does not match with the responsed DO
                   ELSIF  (statCmdBusy = FALSE) AND
                      (statDoId <> statRespParameter.header.doId) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_DRIVE_OBJECT_NO;
                     statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;

                     // No error occurred during reading parameters
                   ELSIF  (tempCmdValid = TRUE) THEN
                     // Analyse of the response buffer
                     statParameter[0].format := statRespParameter.data[0];  // Format of the parameter

                     // Format = Error
                     IF (((TO_SINT (statRespParameter.data[0]) > FORMAT_DOUBLE_WORD) OR
                       ((TO_SINT (statRespParameter.data[0]) > FORMAT_FLOATING_POINT) AND (TO_SINT (statRespParameter.data[0]) < FORMAT_OCTET_STRING)) OR
                       ((TO_SINT (statRespParameter.data[0]) > FORMAT_OCTET_STRING) AND (TO_SINT (statRespParameter.data[0]) < FORMAT_TIME_DIFFERENCE)) OR
                       ((TO_SINT (statRespParameter.data[0]) > FORMAT_TIME_DIFFERENCE) AND (TO_SINT (statRespParameter.data[0]) < FORMAT_BYTE)) OR
                       (TO_SINT (statRespParameter.data[0]) < FORMAT_INTEGER_8))) AND (TO_SINT (statRespParameter.data[0]) <> FORMAT_ZERO)
                     THEN

                       // Format = Error, summarize the first and second error byte in a word error variable for each parameter
                       statParameter[0].errorValue := statRespParameter.data[3];
                       statParameter[0].dwordValue := dword#16#0;
                       statParameter[0].realValue := real#0.0;
                       statdiagnostics.errorValue := statParameter[0].errorValue; // V1.3.2

                       IF  (statFirstParameterError = NO_PARAMETER_ERROR) THEN
                         statdiagnostics.firstParameterError := 0;
                         statFirstParameterError := 0;

                         statStateNumber := statFBSubState;
                         statStatus := ERR_PARAMETER;
                         statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;
                       END_IF;

                     ELSE
                       CASE TO_SINT (statRespParameter.data[0]) OF
                         FORMAT_INTEGER_8:
                           statParameter[0].realValue := TO_REAL(TO_SINT (statRespParameter.data[2]));
                           statParameter[0].dwordValue := statRespParameter.data[2];
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         FORMAT_INTEGER_16:
                           tempWord.%B0 := statRespParameter.data[3];
                           tempWord.%B1 := statRespParameter.data[2];

                           statParameter[0].realValue := TO_REAL(TO_INT (tempWord));
                           statParameter[0].dwordValue := tempWord;
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         FORMAT_INTEGER_32:
                           tempDWord.%B0 := statRespParameter.data[5];
                           tempDWord.%B1 := statRespParameter.data[4];
                           tempDWord.%B2 := statRespParameter.data[3];
                           tempDWord.%B3 := statRespParameter.data[2];

                           statParameter[0].realValue := TO_REAL(TO_DINT (tempDWord));
                           statParameter[0].dwordValue := tempDWord;
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         FORMAT_UNSIGNED_8, FORMAT_OCTET_STRING: // V1.5 change OCTET_STRING:
                           statParameter[0].realValue := TO_REAL(TO_USINT (statRespParameter.data[2]));
                           statParameter[0].dwordValue := statRespParameter.data[2];
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         FORMAT_UNSIGNED_16:
                           tempWord.%B0 := statRespParameter.data[3];
                           tempWord.%B1 := statRespParameter.data[2];

                           statParameter[0].realValue := TO_REAL(TO_UINT (tempWord));
                           statParameter[0].dwordValue := tempWord;
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         FORMAT_UNSIGNED_32, FORMAT_TIME_DIFFERENCE:
                           tempDWord.%B0 := statRespParameter.data[5];
                           tempDWord.%B1 := statRespParameter.data[4];
                           tempDWord.%B2 := statRespParameter.data[3];
                           tempDWord.%B3 := statRespParameter.data[2];

                           statParameter[0].realValue := TO_REAL(TO_UDINT (tempDWord));
                           statParameter[0].dwordValue := tempDWord;
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         FORMAT_FLOATING_POINT, FORMAT_DOUBLE_WORD:
                           tempDWord.%B0 := statRespParameter.data[5];
                           tempDWord.%B1 := statRespParameter.data[4];
                           tempDWord.%B2 := statRespParameter.data[3];
                           tempDWord.%B3 := statRespParameter.data[2];

                           statParameter[0].realValue := TO_REAL (tempDWord);
                           statParameter[0].dwordValue := tempDWord;
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         FORMAT_BYTE:
                           statParameter[0].realValue := TO_REAL(TO_DWORD (statRespParameter.data[2]));
                           statParameter[0].dwordValue := statRespParameter.data[2];
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         FORMAT_WORD:
                           tempWord.%B0 := statRespParameter.data[3];
                           tempWord.%B1 := statRespParameter.data[2];

                           statParameter[0].realValue := TO_REAL(TO_DWORD (tempWord));
                           statParameter[0].dwordValue := tempWord;
                           statParameter[0].errorValue := byte#16#FF; // Sets the error status and diagnostics

                         ELSE
                           ;
                       END_CASE;

                     END_IF; // Format = Error

                     statdiagnostics.errorValue := statParameter[0].errorValue;

                     statCmdBusy := FALSE;
                     statCmdError := FALSE;

                          // Next state is depending on the FB mode
                          IF not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                            statStatus := STATUS_RELEASE;
                            statFBState := LAcycCom_ReadWriteStatus#FB_RELEASE;

                          END_IF; // statMode = MODE_WITH_BUFFER_MANAGER
                   END_IF; // statCmdError = TRUE

                   LAcycCom_ReadWriteStatus#FB_BUSY_WAIT:
                   // Timer for temporary errors
                   instIECTimer(signal := statTimerStart,
                                 duration := TIMER_TEMP_ERROR);

                   statTimerStart := TRUE;
                   IF  (instIECTimer.output = TRUE) THEN
                     statTimerStart := FALSE;
                     statFBSubState := statFBSubStateOld;
                   END_IF;

                 ELSE

                   statStatus := ERR_UNDEFINED_SUBSTATE;
                   statStateNumber := statFBState;
                   statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;
               END_CASE;

             ELSE

               statStatus := ERR_COMMAND_TIMEOUT;
               statStateNumber := statFBState;
               statFBState :=  LAcycCom_ReadWriteStatus#FB_ERROR;
             END_IF; // ( (buffer.element[statAllocatedIndex].enable = TRUE) AND  (statMode = MODE_WITH_BUFFER_MANAGER)) OR statMode = MODE_WITHOUT_BUFFER_MANAGER

        END_METHOD

        Method public GetValueREAL : REAL
            GetValueREAL := statParameter[0].realValue;
        end_method

        Method public GetValueDWORD : DWORD
            GetValueDWORD := statParameter[0].dwordValue;
        end_method

        METHOD PUBLIC Start : bool
            VAR_INPUT
                driveObjectId  : UInt := UINT#0;   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                hardwareId : HW_IO;   // Hardware identifier of the hardware module
                parameterNumber : UInt;   // Number of the parameter
                index : UInt;   // Parameter index
             END_VAR

             statparameterNumber := parameterNumber;
             statindex := index;
             statDoId := to_byte(driveObjectId);
             statHwId := hardwareId;

             // starts functionality
             IF not ((statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                 statFBState = LAcycCom_ReadWriteStatus#FB_DONE or 
                 statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND
                 statrequestBuffer <> NULL) THEN
                   Start := False;
             ELSE
               // Initialisation
               Start := TRUE;
               statAllocatedIndex := -1;
               statSubfunctionStatus :=  word#16#0000;
               statDataRecordNo := dint#0;
               statStateNumber := LAcycCom_ReadWriteStatus#FB_IDLE;
               statDatasetType := SINT#0;
               statFirstParameterError := -1;
               statErrorCount := uint#0;
               statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
               statFBState := LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE;

               instIECTimer(signal := FALSE,
                             duration := TIMER_ALLOCATION);


             END_IF;
        END_METHOD

    END_CLASS
END_NAMESPACE    