using System.Timer;
using siemens.Simatic.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom
    CLASS LAcycCom_classWriteDriveParams EXTENDS ReadWriteParameter
        VAR PRIVATE
            statparameterCount   : INT := -1;
            dataset              : Array[0..LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_typeDriveDataset;          // Dataset with all parameters to be read
            statReqWriteParameter: LAcycCom_TypestatReqWriteParameter;                                                                       // Request telegram to change the parameter values
            statReqReadParameter : LAcycCom_TypestatstatReqParameter;                                                                        // Request telegram
            statParameter        : Array[0..LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatstatParameter;     // Parameter dataset
            parameterAddress     : Array[0..LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatparameterAddress;  // Parameter data in telegram
        END_VAR

        VAR CONSTANT
          WRITE_PARAMETERS_UPPER_LIM : INT := 18;   // Maximum count of parameters
          LENGTH_WRITE_TELEGRAM_UPPER_LIM : INT := 227;   // Maximum length of parameter information when using WRREC
        END_VAR

        METHOD OVERRIDE BUSY
            VAR_TEMP
                tempCmdValid         : BOOL;                       // TRUE: New data record was received and is valid
                tempStatusWord       : WORD;                       // Temporary status
                tempWord             : WORD;                       // Temporary WORD variable
                tempPointer          : INT;                        // Temporary pointer variable
                tempLoopIndex        : INT;                        // Temporary loop index variable
                tempBlkVariant       : INT;                        // Temporary result of MOVE_BLK_VARIANT
                tempCmdStatus        : DWORD;                      // Temporary status of WRREC and RDREC command
                tempDWord            : DWORD;                      // Temporary DWORD variable
                tempVoidHeader       : LAcycCom_Typestatheader;    // Temporary empty header structure
                tempActualElementReal: LAcycCom_typeDriveDataset;  // Temporary element of the dataset (REAL values)
             END_VAR
             IF (statrequestBuffer.GetRessource(statAllocatedIndex) = LAcycCom_ResourceManagerRetval#STATUS_BUSY) THEN
                CASE statFBSubState OF
                    LAcycCom_ReadWriteStatus#FB_GET_SUBSTATE:
                      statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;

                      // Clearing the sending write buffer
                      statReqWriteParameter.header := tempVoidHeader;
                      FOR tempLoopIndex := 0 TO LENGTH_WRITE_TELEGRAM_UPPER_LIM DO
                      statReqWriteParameter.data[tempLoopIndex] := BYTE#16#00;
                      END_FOR;

                      FOR tempLoopIndex := 0 TO LENGTH_WRITE_TELEGRAM_UPPER_LIM DO
                         THIS.atmpRec[tempLoopIndex] := BYTE#0;
                      END_FOR;

                    LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1, LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2:  // Writing the dataset configuration into the drive object

                    IF (statCmdBusy = FALSE) AND (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      // Resets WRREC command
                      instWRREC(request := FALSE,
                      RECORD := THIS.atmpRec);

                      // Creating header data
                     statReqReadParameter.header.refNo := statRefNo; // Telegram reference number
                     statReqReadParameter.header.reqId := BYTE#16#01;  // 0x01 = request parameters
                     statReqReadParameter.header.doId := TO_BYTE(statDoId);  // Drive object identification number
                     statReqReadParameter.header.parameterNo := TO_BYTE(statCountOfElements);  // Count of parameters

                      // Copying the dataset into a static variable (depending on the used PLC data type)

                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                         tempActualElementReal:= dataset[tempLoopIndex];
                         statParameter[tempLoopIndex].index := UINT#0;
                         statParameter[tempLoopIndex].parameterNo := tempActualElementReal.parameterNumber;
                         statParameter[tempLoopIndex].realValue := tempActualElementReal.Rvalue;
                         statParameter[tempLoopIndex].dwordValue := tempActualElementReal.DWvalue;
                         statReqReadParameter.parameterAddress[tempLoopIndex].parameterNo := statParameter[tempLoopIndex].parameterNo;  // Parameter number
                         statReqReadParameter.parameterAddress[tempLoopIndex].index := statParameter[tempLoopIndex].index;  // Subindex of parameter
                        END_FOR;


                    ELSIF (statCmdBusy = FALSE) AND (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      // Resets WRREC command
                      instWRREC(request := FALSE,
                                 RECORD := THIS.atmpRec);

                       tempPointer := 0;
                      // Creating header data
                     statReqWriteParameter.header.refNo := statRefNo; // Telegram reference number
                     statReqWriteParameter.header.reqId := BYTE#16#02;  // 0x02 = change parameters
                     statReqWriteParameter.header.doId := TO_BYTE(statDoId);  // Drive object identification number
                     statReqWriteParameter.header.parameterNo := TO_BYTE(statCountOfElements);  // Count of parameters

                      FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                       statReqWriteParameter.data [tempPointer] := BYTE#16#10; // Attribute of parameters (0x10=Value, 0x30=Text)
                       statReqWriteParameter.data [tempPointer + 1] := BYTE#16#01; // No. of elements (for single elements=1)


                        // Parameter number
                       statReqWriteParameter.data [tempPointer + 3] := statParameter[tempLoopIndex].parameterNo.%B0;
                       statReqWriteParameter.data [tempPointer + 2] := statParameter[tempLoopIndex].parameterNo.%B1;

                        // Subindex of parameter
                       statReqWriteParameter.data [tempPointer + 5] := statParameter[tempLoopIndex].index.%B0;
                       statReqWriteParameter.data [tempPointer + 4] := statParameter[tempLoopIndex].index.%B1;

                        // Points to the next parameter address
                         tempPointer := tempPointer + 6;
                      END_FOR;

                      // Creating parameter address
                      FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO

                        IF (statParameter[tempLoopIndex].format = FORMAT_ERROR) THEN
                         statParameter[tempLoopIndex].format := TO_BYTE(FORMAT_FLOATING_POINT);
                        END_IF;

                       statReqWriteParameter.data [tempPointer] := statParameter[tempLoopIndex].format; // Format of parameter
                       statReqWriteParameter.data [tempPointer + 1] := BYTE#16#01; // Count of values

                        CASE TO_SINT(statParameter[tempLoopIndex].format) OF
                          FORMAT_INTEGER_8:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_SINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B0;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_INTEGER_16:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_DINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B0;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B1;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_INTEGER_32:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_DINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 5] := tempDWord.%B0;
                           statReqWriteParameter.data [tempPointer + 4] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B2;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B3;

                             tempPointer := tempPointer + 6; // Points to the next parameter address

                          FORMAT_UNSIGNED_8, FORMAT_OCTET_STRING: // V1.5 change OCTET_STRING:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_USINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B0;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_UNSIGNED_16:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_UDINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B0;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B1;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_UNSIGNED_32, FORMAT_TIME_DIFFERENCE:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_UDINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 5] := tempDWord.%B0;
                           statReqWriteParameter.data [tempPointer + 4] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B2;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B3;

                             tempPointer := tempPointer + 6; // Points to the next parameter address
                          FORMAT_FLOATING_POINT, FORMAT_DOUBLE_WORD:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(statParameter[tempLoopIndex].realValue);

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 5] := tempDWord.%B0;
                           statReqWriteParameter.data [tempPointer + 4] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B2;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B3;

                             tempPointer := tempPointer + 6;  // Points to the next parameter address
                          FORMAT_BYTE:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(statParameter[tempLoopIndex].realValue);

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B0;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_WORD:
                            IF NOT (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(statParameter[tempLoopIndex].realValue);

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B0;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B1;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          ELSE
                            ;
                        END_CASE;
                      END_FOR; // // Creating parameter address
                    END_IF; // statCmdBusy = FALSE AND statParameterConfig = TRUE

                    SerializeBig(UINT#0,
                    statReqReadParameter,
                    THIS.atmpSend );

                    IF (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      SerializeBig(UINT#0,
                        statReqReadParameter,
                        THIS.atmpSend );
                      // WRREC command
                      instWRREC(REQUEST := TRUE,                                                // Transfer data record
                                 hardwareID := statHwId,           // ID number of the hardware component
                                 INDEX  := statDataRecordNo,   // Data record number
                                 LENGTH := UINT#0,             // Maximum length of the data record to be transferred in bytes
                                 DONE   => statCmdDone,        // Data record was transferred
                                 BUSY   => statCmdBusy,        // The writing process is NOT yet complete
                                 ERROR  => statCmdError,       // An error occurred during the writing process
                                 STATUS =>  tempCmdStatus,     // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                                 RECORD := THIS.atmpSend);     // Data record

                    ELSIF (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      SerializeBig(UINT#0,
                        statReqWriteParameter,
                        THIS.atmpSend );
                        // WRREC command
                      instWRREC(REQUEST := TRUE,                                                // Transfer data record
                                 hardwareID := statHwId,           // ID number of the hardware component
                                 INDEX  := statDataRecordNo,   // Data record number
                                 LENGTH := UINT#0,             // Maximum length of the data record to be transferred in bytes
                                 DONE   => statCmdDone,        // Data record was transferred
                                 BUSY   => statCmdBusy,        // The writing process is NOT yet complete
                                 ERROR  => statCmdError,       // An error occurred during the writing process
                                 STATUS =>  tempCmdStatus,     // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                                 RECORD := THIS.atmpSend);     // Data record
                    END_IF;


                    // Error occurred
                    IF (statCmdError = TRUE) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      // Get the error information from the status information
                       tempStatusWord.%B0 := tempCmdStatus.%B1;
                       tempStatusWord.%B1 := tempCmdStatus.%B2;

                      // Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                      IF (tempStatusWord = WORD#16#80A1) OR  // Negative acknowledgment when writing to the module
                        (tempStatusWord = WORD#16#80A7) OR   // DP slave OR module is occupied (temporary error)
                        (tempStatusWord = WORD#16#80B5) OR   // DP slave OR module NOT ready
                        (tempStatusWord = WORD#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is NOT possible. You can only write the data online with PG/PC.
                        (tempStatusWord = WORD#16#80C1) OR   // The data of the previous write job on the module for the same data record have NOT yet been processed by the module.
                        (tempStatusWord = WORD#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                        (tempStatusWord = WORD#16#80C3) OR   // The required operating resources are currently occupied.
                        (tempStatusWord = WORD#16#80C4) THEN // Internal temporary error. Job could NOT be executed. Repeat the job. IF this error occurs often, check your installation for sources of electrical interference.

                        IF (statErrorCount >= MAX_ERROR_COUNT) THEN
                         statStateNumber := statFBSubState;
                         statSubfunctionStatus := tempStatusWord;
                         statStatus := ERR_WRREC_TEMP_COUNTER;
                         statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                        ELSE
                         statErrorCount := statErrorCount + UINT#1;  // Increment internal error counter
                         statFBSubStateOld := statFBSubState;
                         statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WAIT;
                        END_IF;
                      ELSE
                       statStateNumber := statFBSubState;
                       statSubfunctionStatus := tempStatusWord;
                       statStatus := ERR_WRREC;
                       statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                      END_IF; // Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command

                    ELSIF (statCmdBusy = FALSE) AND (statCmdDone = TRUE) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1) THEN  // Processing completed without errors
                     statErrorCount := UINT#0;  // V1.5.1 Reset error counter
                     statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_1; // WRREC completed and continue with RDREC

                    ELSIF (statCmdBusy = FALSE) AND (statCmdDone = TRUE) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2) THEN  // Processing completed without errors
                     statErrorCount := UINT#0;  // V1.5.1 Reset error counter
                     statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_2; // WRREC completed and continue with RDREC
                      // Clearing the receive buffer
                     statRespParameter.header := tempVoidHeader;
                      FOR tempLoopIndex := 0 TO LENGTH_READ_TELEGRAM_UPPER_LIM DO
                       statRespParameter.data[tempLoopIndex] := BYTE#16#00;
                      END_FOR;
                    END_IF; // statCmdError = TRUE

                    LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_1, LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_2:  // Reading the values from the drive object

                    // Resets RDREC command
                    IF (statCmdBusy = FALSE) THEN
                      instRDREC(request := FALSE,
                                 RECORD := THIS.atmpRec);

                    END_IF;

                    instRDREC(request := TRUE,                                                 // Transfer data record
                               hardwareID := statHwId,           // ID number of the hardware component
                               INDEX     := statDataRecordNo,   // Data record number
                               MAXLENGTH := UINT#0,             // Maximum length in bytes of the data record information to be read
                               VALID     =>  tempCmdValid,      // New data record was received and is valid
                               BUSY      => statCmdBusy,        // The reading process is NOT yet complete
                               ERROR     => statCmdError,       // An error occurred during the reading process
                               STATUS    =>  tempCmdStatus,     // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                               RECORD    := THIS.atmpRec);      // Destination area for the data record read

                    DeserializeBig(UINT#0,
                                THIS.atmpRec,
                                statRespParameter);

                    // Error occurred
                    IF (statCmdError = TRUE) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      // Get the error information from the status information
                       tempStatusWord.%B0 := tempCmdStatus.%B1;
                       tempStatusWord.%B1 := tempCmdStatus.%B2;

                      // Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                      IF (tempStatusWord = WORD#16#80A0) OR  // Negative acknowledgment when reading the module
                        (tempStatusWord = WORD#16#80A7) OR   // DP slave OR module is occupied (temporary error)
                        (tempStatusWord = WORD#16#80B5) OR   // DP slave OR module NOT ready
                        (tempStatusWord = WORD#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is NOT possible. You can only write the data online with PG/PC.
                        (tempStatusWord = WORD#16#80C1) OR   // The data of the previous write job on the module for the same data record have NOT yet been processed by the module.
                        (tempStatusWord = WORD#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                        (tempStatusWord = WORD#16#80C3) OR   // The required operating resources are currently occupied.
                        (tempStatusWord = WORD#16#80C4) THEN // Internal temporary error. Job could NOT be executed. Repeat the job. IF this error occurs often, check your installation for sources of electrical interference.


                        IF (statErrorCount >= MAX_ERROR_COUNT) THEN

                         statStateNumber := statFBSubState;
                         statSubfunctionStatus := tempStatusWord;
                         statStatus := ERR_RDREC_TEMP_COUNTER;
                         statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                        ELSE
                         statErrorCount := statErrorCount + UINT#1;  // Increment internal error counter
                         statFBSubStateOld := statFBSubState;
                          // V1.3.2. IF error 80A0 THEN should be retry with WRREC command
                          IF (tempStatusWord = WORD#16#80A0) AND statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_1 THEN
                           statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;
                          ELSIF (tempStatusWord = WORD#16#80A0) AND statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_2 THEN
                           statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2;
                          END_IF;
                         statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WAIT;
                        END_IF;
                      ELSE

                       statStateNumber := statFBSubState;
                       statSubfunctionStatus := tempStatusWord;
                       statStatus := ERR_RDREC;
                       statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                      END_IF; // Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command

                      // Error : Reference number of the request does NOT match with the response reference number
                    ELSIF (statCmdBusy = FALSE) AND
                      (statRefNo <> statRespParameter.header.refNo) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_REFERENCE_NO;
                     statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                      // Error : Invalid response from the drive object (reqId: 16#01 - reading parameter successful; 16#81: reading parameter finished with error; 16#02: writing parameter sucessful; 16#82: writing parameter finished with error)
                    ELSIF (statCmdBusy = FALSE) AND
                      NOT (statRespParameter.header.reqId = BYTE#16#81 OR statRespParameter.header.reqId = BYTE#16#01 OR statRespParameter.header.reqId = BYTE#16#02 OR statRespParameter.header.reqId = BYTE#16#82) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_RESPONSE_ID;
                     statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                      // Error : The received number of parameters does NOT match with the requested number of parameters
                    ELSIF (statCmdBusy = FALSE) AND
                      (statCountOfElements <> TO_INT(statRespParameter.header.parameterNo)) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_PARAMETER_NO;
                     statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                      // Error : The drive object does NOT match with the responsed DO
                    ELSIF (statCmdBusy = FALSE) AND
                      (TO_BYTE(statDoId) <> statRespParameter.header.doId) AND
                      (tempCmdValid = TRUE) THEN

                     statStateNumber := statFBSubState;
                     statStatus := ERR_DRIVE_OBJECT_NO;
                     statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                      // No error occurred during reading parameters
                    ELSIF (statCmdBusy = FALSE) AND (tempCmdValid = TRUE) AND  NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN

                      IF (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_1) THEN

                        // Analyse of the response buffer
                         tempPointer := 0;
                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 DO
                         statParameter[tempLoopIndex].format := statRespParameter.data [tempPointer];  // Format of the parameter

                          // Format = Error
                          IF (((TO_SINT(statRespParameter.data [tempPointer]) > FORMAT_DOUBLE_WORD) OR
                            ((TO_SINT(statRespParameter.data [tempPointer]) > FORMAT_FLOATING_POINT) AND (TO_SINT(statRespParameter.data [tempPointer]) < FORMAT_OCTET_STRING)) OR
                            ((TO_SINT(statRespParameter.data [tempPointer]) > FORMAT_OCTET_STRING) AND (TO_SINT(statRespParameter.data [tempPointer]) < FORMAT_TIME_DIFFERENCE)) OR
                            ((TO_SINT(statRespParameter.data [tempPointer]) > FORMAT_TIME_DIFFERENCE) AND (TO_SINT(statRespParameter.data [tempPointer]) < FORMAT_BYTE)) OR
                            (TO_SINT(statRespParameter.data [tempPointer]) < FORMAT_INTEGER_8))) AND (TO_SINT(statRespParameter.data [tempPointer]) <> FORMAT_ZERO)
                          THEN

                           statParameter[tempLoopIndex].errorValue := statRespParameter.data [tempPointer + 3];
                            // Points to the next parameter address
                             tempPointer := tempPointer + 6;

                          ELSE
                            CASE TO_SINT(statRespParameter.data [tempPointer]) OF
                              FORMAT_INTEGER_8, FORMAT_UNSIGNED_8, FORMAT_BYTE, FORMAT_INTEGER_16, FORMAT_UNSIGNED_16, FORMAT_OCTET_STRING, FORMAT_WORD:
                               statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostic
                                 tempPointer := tempPointer + 4; // Points to the next parameter address

                              FORMAT_INTEGER_32, FORMAT_UNSIGNED_32, FORMAT_TIME_DIFFERENCE, FORMAT_FLOATING_POINT, FORMAT_DOUBLE_WORD:
                               statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                 tempPointer := tempPointer + 6; // Points to the next parameter address

                              ELSE
                                ;
                            END_CASE;
                          END_IF; // Format = Error
                        END_FOR; // Analyse of the response buffer

                       statCmdBusy := FALSE;
                       statCmdError := FALSE;
                       statFBState := LAcycCom_ReadWriteStatus#FB_BUSY;
                       statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2;
                      ELSE

                        // Error occurred during writing process (changing parameter values)
                        IF (statRespParameter.header.reqId = BYTE#16#82) THEN  // reqId: 16#82 (Error occurred during writing paramaters)
                           tempPointer := 0;

                          FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                            // Parameter error
                            IF (statRespParameter.data [tempPointer] = FORMAT_ERROR) THEN

                             statParameter[tempLoopIndex].errorValue := statRespParameter.data [tempPointer + 3]; // V1.3.2
                              // Save first parameter error in telegram
                              IF (statFirstParameterError = NO_PARAMETER_ERROR) THEN
                               statFirstParameterError := tempLoopIndex;
                                statdiagnostics.firstParameterError := statFirstParameterError;
                                statdiagnostics.errorValue := statParameter[tempLoopIndex].errorValue; // V1.3.2

                               statStateNumber := statFBSubState;
                               statStatus := ERR_PARAMETER;
                               statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                              END_IF;

                               tempPointer := tempPointer + 6;  // Points to the next parameter address

                              // Parameter without errors
                            ELSE
                             statParameter[tempLoopIndex].errorValue := BYTE#16#FF;
                               tempPointer := tempPointer + 2;
                            END_IF;
                            dataset[tempLoopIndex]:=tempActualElementReal;
                          END_FOR;
                        END_IF; // Error occurred during writing process (changing parameter values)

                       statCmdBusy := FALSE;
                       statCmdError := FALSE;
                       statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;

                          // Next state is depending on the FB mode
                          IF NOT(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                            statStatus := STATUS_RELEASE;
                            statFBState := LAcycCom_ReadWriteStatus#FB_RELEASE;

                          END_IF; // statMode = MODE_WITH_BUFFER_MANAGER
                      END_IF; // statParameterConfig = TRUE
                    END_IF; // statCmdError = TRUE

                    LAcycCom_ReadWriteStatus#FB_BUSY_WAIT:
                    // Timer for temporary errors
                    instIECTimer(signal := statTimerStart,
                    duration := TIMER_TEMP_ERROR);

                   statTimerStart := TRUE;
                    IF (instIECTimer.output = TRUE) THEN
                     statTimerStart := FALSE;
                     statFBSubState := statFBSubStateOld;
                    END_IF;

                  ELSE

                   statStatus := ERR_UNDEFINED_SUBSTATE;
                   statStateNumber := statFBState;
                   statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                END_CASE;

              ELSE

               statStatus := ERR_COMMAND_TIMEOUT;
               statStateNumber := statFBState;
               statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
              END_IF; // ((buffer.element [statAllocatedIndex].enable = TRUE) AND (statMode = MODE_WITH_BUFFER_MANAGER)) OR statMode = MODE_WITHOUT_BUFFER_MANAGER

        END_METHOD

        //data type of driveobjectid has been changed from uint to int. This extra start method keeps compability to old versions of LAcycCom
        METHOD PUBLIC Start : BOOL
            VAR_INPUT
              driveObjectId : UINT;
              hardwareId    : HW_IO;      
              parameterCount: INT := -1;  
            END_VAR
            Start := THIS.Start(driveObjectId := TO_INT(driveObjectId), hardwareId := hardwareId, parameterCount := parameterCount);
          END_METHOD
          //data type of driveobjectid has been changed from uint to int. This extra start method can be used, if direct hw id is used and drive object is not used (equivalent to driveobjectid = -1)
          METHOD PUBLIC Start : BOOL
            VAR_INPUT
              hardwareId    : HW_IO;      
              parameterCount: INT := -1;  
          END_VAR
          Start := THIS.Start(driveObjectId := -1, hardwareId := hardwareId, parameterCount := parameterCount);
        END_METHOD


        METHOD PUBLIC Start : BOOL
            VAR_INPUT
                driveObjectId : INT := -1;  // Optional: Identification number of the drive object (value =-1: driveObjectId is NOT used, i.e. the corresponding drive object is only addressed via the hardwareId)
                hardwareId    : HW_IO;           // Hardware identifier of the hardware module
                parameterCount: INT := -1;       // Count of parameters to read (-1: read all parameter in dataset)
            END_VAR

             statparameterCount := parameterCount;
             statDoId := driveObjectId;
             statHwId := hardwareId;

             // starts functionality
             IF NOT ((statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                 statFBState = LAcycCom_ReadWriteStatus#FB_DONE OR 
                 statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND
                 statrequestBuffer <> NULL) THEN
                   Start := FALSE;
             ELSE
               // Initialisation
               Start := TRUE;
               statAllocatedIndex := -1;
               statSubfunctionStatus :=  WORD#16#0000;
               statDataRecordNo := DINT#0;
               statStateNumber := LAcycCom_ReadWriteStatus#FB_IDLE;
               statDatasetType := SINT#0;
               statFirstParameterError := -1;
               statErrorCount := UINT#0;
               statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
               statFBState := LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE;

               instIECTimer(signal := FALSE,
                             duration := TIMER_ALLOCATION);


             END_IF;
        END_METHOD

        METHOD PUBLIC DeleteList
            Var
                z : INT;
            END_VAR

            For z := 0 to LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM do
                dataset[z].DWvalue  := DWORD#0;
                dataset[z].errorValue := BYTE#0;
                dataset[z].index    := UINT#0;
                dataset[z].parameterNumber := UINT#0;
                dataset[z].Rvalue    := REAL#0.0;
            end_FOR;

            statCountOfElements := 0;

          END_METHOD

          METHOD PUBLIC AddatasetItem : INT //Rückgabewert = anzahl der Listeneinträge
            VAR_INPUT
                datasetItem : LAcycCom_typeDriveDataset;
                element_no  : INT := INT#-1; //-1 element an die liste anhängen. >=0 element überschreiben
            END_VAR

            IF element_no = -1 and statCountOfElements < LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM THEN
                    dataset[statCountOfElements] :=datasetItem;
                AddatasetItem := statCountOfElements;
                statCountOfElements := statCountOfElements + 1;

            ELSIF element_no > -1 and
                element_no < LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM and
                element_no <= statCountOfElements THEN
                    dataset[element_no] :=datasetItem;
                IF element_no = statCountOfElements THEN
                    statCountOfElements := statCountOfElements + 1;
                END_IF;
            ELSE
                AddatasetItem := -1;
            END_IF;

          END_METHOD

        METHOD PUBLIC ReaddatasetItem : LAcycCom_typeDriveDataset
          VAR_INPUT
              element_no  : INT := INT#0;
          END_VAR

          IF element_no >= 0 and element_no <= LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM THEN
              ReaddatasetItem := dataset[element_no];
          END_IF;

        END_METHOD

    END_CLASS
END_NAMESPACE    