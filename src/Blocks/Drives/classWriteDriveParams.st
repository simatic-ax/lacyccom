using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom
    CLASS LAcycCom_classWriteDriveParams EXTENDS ReadWriteParameter
        var Private
            statparameterCount : Int := -1;
            dataset : Array[0..LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_typeDriveDataset;   // Dataset with all parameters to be read
            statReqWriteParameter  : LAcycCom_TypestatReqWriteParameter;   // Request telegram to change the parameter values
            statReqReadParameter   : LAcycCom_TypestatstatReqParameter;   // Request telegram
            statParameter   : Array[0..LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatstatParameter;   // Parameter dataset
            parameterAddress   : Array[0..LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatparameterAddress;   // Parameter data in telegram
        end_VAR

        VAR CONSTANT
          WRITE_PARAMETERS_UPPER_LIM : Int := 18;   // Maximum count of parameters
          LENGTH_WRITE_TELEGRAM_UPPER_LIM : Int := 227;   // Maximum length of parameter information when using WRREC
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
                      statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;
                                    // Clearing the sending buffer
                      statReqParameter.header := tempVoidHeader;
                      // Clearing the sending read buffer
                      statReqReadParameter.header := tempVoidHeader;
                      FOR tempLoopIndex := 0 TO WRITE_PARAMETERS_UPPER_LIM DO
                      statReqReadParameter.parameterAddress[tempLoopIndex] := statReqParameterInit;
                      END_FOR;

                      // Clearing the sending write buffer
                      statReqWriteParameter.header := tempVoidHeader;
                      FOR tempLoopIndex := 0 TO LENGTH_WRITE_TELEGRAM_UPPER_LIM DO
                      statReqWriteParameter.data[tempLoopIndex] := byte#16#00;
                      END_FOR;

                      // Clearing the receive buffer
                      statRespParameter.header := tempVoidHeader;
                      FOR tempLoopIndex := 0 TO LENGTH_READ_TELEGRAM_UPPER_LIM DO
                      statRespParameter.data[tempLoopIndex] := byte#16#00;
                      END_FOR;

                      // Initialization after start, depending on the used PLC data type
                      IF (statDatasetType = DATA_TYPE_DATASET_REAL) OR (statDatasetType = DATA_TYPE_DATASET_DWORD) THEN
                        IF statDoId < byte#0 THEN // V1.5
                        statDataRecordNo := 16#B02E; // Base Mode Parameter Access local; doId not relevant
                        statDoId := byte#0;

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

                      ELSE
                        ;
                      END_IF;
                      FOR tempLoopIndex := 0 TO LENGTH_WRITE_TELEGRAM_UPPER_LIM DO
                         atmpRec[tempLoopIndex] := byte#0;
                      END_FOR;

                    LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1, LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2:  // Writing the dataset configuration into the drive object

                    IF (statCmdBusy = FALSE) AND (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      // Resets WRREC command
                      instWRREC(request := FALSE,
                      RECORD := atmpRec);

                      // Creating header data
                     statReqReadParameter.header.refNo := statRefNo; // Telegram reference number
                     statReqReadParameter.header.reqId := byte#16#01;  // 0x01 = request parameters
                     statReqReadParameter.header.doId := statDoId;  // Drive object identification number
                     statReqReadParameter.header.parameterNo := TO_BYTE(statCountOfElements);  // Count of parameters

                      // Copying the dataset into a static variable (depending on the used PLC data type)

                        FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                         tempActualElementReal:= dataset[tempLoopIndex];
                         statParameter[tempLoopIndex].index := uint#0;
                         statParameter[tempLoopIndex].parameterNo := tempActualElementReal.parameterNumber;
                         statParameter[tempLoopIndex].realValue := tempActualElementReal.Rvalue;
                         statParameter[tempLoopIndex].dwordValue := tempActualElementReal.DWvalue;
                         statReqReadParameter.parameterAddress[tempLoopIndex].parameterNo := statParameter[tempLoopIndex].parameterNo;  // Parameter number
                         statReqReadParameter.parameterAddress[tempLoopIndex].index := statParameter[tempLoopIndex].index;  // Subindex of parameter
                        END_FOR;


                    ELSIF (statCmdBusy = FALSE) AND (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      // Resets WRREC command
                      instWRREC(request := FALSE,
                                 RECORD := atmpRec);

                       tempPointer := 0;
                      // Creating header data
                     statReqWriteParameter.header.refNo := statRefNo; // Telegram reference number
                     statReqWriteParameter.header.reqId := byte#16#02;  // 0x02 = change parameters
                     statReqWriteParameter.header.doId := statDoId;  // Drive object identification number
                     statReqWriteParameter.header.parameterNo := TO_BYTE(statCountOfElements);  // Count of parameters

                      FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                       statReqWriteParameter.data [tempPointer] := byte#16#10; // Attribute of parameters (0x10=Value, 0x30=Text)
                       statReqWriteParameter.data [tempPointer + 1] := byte#16#01; // No. of elements (for single elements=1)


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
                       statReqWriteParameter.data [tempPointer + 1] := byte#16#01; // Count of values

                        CASE TO_SINT(statParameter[tempLoopIndex].format) OF
                          FORMAT_INTEGER_8:
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_SINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B0;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_INTEGER_16:
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_DINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B0;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B1;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_INTEGER_32:
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
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
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_USINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B0;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_UNSIGNED_16:
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(TO_UDINT(statParameter[tempLoopIndex].realValue));

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B0;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B1;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_UNSIGNED_32, FORMAT_TIME_DIFFERENCE:
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
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
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
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
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
                               tempDWord := TO_DWORD(statParameter[tempLoopIndex].realValue);

                            ELSE
                               tempDWord := statParameter[tempLoopIndex].dwordValue;
                            END_IF;

                           statReqWriteParameter.data [tempPointer + 3] := tempDWord.%B1;
                           statReqWriteParameter.data [tempPointer + 2] := tempDWord.%B0;
                             tempPointer := tempPointer + 4;  // Points to the next parameter address

                          FORMAT_WORD:
                            IF not (statParameter[tempLoopIndex].realValue = 0.0) THEN
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

                    SerializeBig(uint#0,
                    statReqReadParameter,
                    atmpSend );

                    IF (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      SerializeBig(uint#0,
                        statReqReadParameter,
                        atmpSend );
                      // WRREC command
                      instWRREC(REQUEST := TRUE,                                                // Transfer data record
                                 ID := statHwId,                                                // ID number of the hardware component
                                 INDEX := statDataRecordNo,                                                    // Data record number
                                 LENGTH := uint#0,                                                       // Maximum length of the data record to be transferred in bytes
                                 DONE => statCmdDone,                                           // Data record was transferred
                                 BUSY => statCmdBusy,                                           // The writing process is not yet complete
                                 ERROR => statCmdError,                                         // An error occurred during the writing process
                                 STATUS =>  tempCmdStatus,                                       // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                                 RECORD := atmpSend);                               // Data record

                    ELSIF (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      SerializeBig(uint#0,
                        statReqWriteParameter,
                        atmpSend );
                        // WRREC command
                      instWRREC(REQUEST := TRUE,                                                // Transfer data record
                                 ID := statHwId,                                                // ID number of the hardware component
                                 INDEX := statDataRecordNo,                                                    // Data record number
                                 LENGTH := uint#0,                                                       // Maximum length of the data record to be transferred in bytes
                                 DONE => statCmdDone,                                           // Data record was transferred
                                 BUSY => statCmdBusy,                                           // The writing process is not yet complete
                                 ERROR => statCmdError,                                         // An error occurred during the writing process
                                 STATUS =>  tempCmdStatus,                                       // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                                 RECORD := atmpSend);                              // Data record
                    END_IF;


                    // Error occurred
                    IF (statCmdError = TRUE) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      // Get the error information from the status information
                       tempStatusWord.%B0 := tempCmdStatus.%B1;
                       tempStatusWord.%B1 := tempCmdStatus.%B2;

                      // Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                      IF (tempStatusWord = word#16#80A1) OR  // Negative acknowledgment when writing to the module
                        (tempStatusWord = word#16#80A7) OR   // DP slave or module is occupied (temporary error)
                        (tempStatusWord = word#16#80B5) OR   // DP slave or module not ready
                        (tempStatusWord = word#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
                        (tempStatusWord = word#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.
                        (tempStatusWord = word#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                        (tempStatusWord = word#16#80C3) OR   // The required operating resources are currently occupied.
                        (tempStatusWord = word#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.

                        IF (statErrorCount >= MAX_ERROR_COUNT) THEN
                         statStateNumber := statFBSubState;
                         statSubfunctionStatus := tempStatusWord;
                         statStatus := ERR_WRREC_TEMP_COUNTER;
                         statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                        ELSE
                         statErrorCount := statErrorCount + uint#1;  // Increment internal error counter
                         statFBSubStateOld := statFBSubState;
                         statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WAIT;
                        END_IF;
                      ELSE
                       statStateNumber := statFBSubState;
                       statSubfunctionStatus := tempStatusWord;
                       statStatus := ERR_WRREC;
                       statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                      END_IF; // Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command

                    ELSIF (statCmdBusy = FALSE) AND (statCmdDone = TRUE) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1) THEN  // Processing completed without errors
                     statErrorCount := uint#0;  // V1.5.1 Reset error counter
                     statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_1; // WRREC completed and continue with RDREC

                    ELSIF (statCmdBusy = FALSE) AND (statCmdDone = TRUE) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) AND (statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_2) THEN  // Processing completed without errors
                     statErrorCount := uint#0;  // V1.5.1 Reset error counter
                     statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_2; // WRREC completed and continue with RDREC
                      // Clearing the receive buffer
                     statRespParameter.header := tempVoidHeader;
                      FOR tempLoopIndex := 0 TO LENGTH_READ_TELEGRAM_UPPER_LIM DO
                       statRespParameter.data[tempLoopIndex] := byte#16#00;
                      END_FOR;
                    END_IF; // statCmdError = TRUE

                    LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_1, LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_2:  // Reading the values from the drive object

                    // Resets RDREC command
                    IF (statCmdBusy = FALSE) THEN
                      instRDREC(request := FALSE,
                                 RECORD := atmpRec);

                    END_IF;

                    instRDREC(request := TRUE,                                                 // Transfer data record
                               ID := statHwId,                                                 // ID number of the hardware component
                               INDEX := statDataRecordNo,                                                     // Data record number
                               MAXLENGTH := uint#0,                                                        // Maximum length in bytes of the data record information to be read
                               VALID =>  tempCmdValid,                                          // New data record was received and is valid
                               BUSY => statCmdBusy,                                            // The reading process is not yet complete
                               ERROR => statCmdError,                                          // An error occurred during the reading process
                               STATUS =>  tempCmdStatus,                                        // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                               RECORD := atmpRec);                                   // Destination area for the data record read

                    DeserializeBig(uint#0,
                                atmpRec,
                                statRespParameter);

                    // Error occurred
                    IF (statCmdError = TRUE) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                      // Get the error information from the status information
                       tempStatusWord.%B0 := tempCmdStatus.%B1;
                       tempStatusWord.%B1 := tempCmdStatus.%B2;

                      // Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                      IF (tempStatusWord = word#16#80A0) OR  // Negative acknowledgment when reading the module
                        (tempStatusWord = word#16#80A7) OR   // DP slave or module is occupied (temporary error)
                        (tempStatusWord = word#16#80B5) OR   // DP slave or module not ready
                        (tempStatusWord = word#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
                        (tempStatusWord = word#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.
                        (tempStatusWord = word#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                        (tempStatusWord = word#16#80C3) OR   // The required operating resources are currently occupied.
                        (tempStatusWord = word#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.


                        IF (statErrorCount >= MAX_ERROR_COUNT) THEN

                         statStateNumber := statFBSubState;
                         statSubfunctionStatus := tempStatusWord;
                         statStatus := ERR_RDREC_TEMP_COUNTER;
                         statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                        ELSE
                         statErrorCount := statErrorCount + uint#1;  // Increment internal error counter
                         statFBSubStateOld := statFBSubState;
                          // V1.3.2. If error 80A0 then should be retry with WRREC command
                          IF (tempStatusWord = word#16#80A0) AND statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_1 THEN
                           statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;
                          ELSIF (tempStatusWord = word#16#80A0) AND statFBSubState = LAcycCom_ReadWriteStatus#FB_BUSY_RDREC_2 THEN
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

                      // Error : Reference number of the request does not match with the response reference number
                    ELSIF (statCmdBusy = FALSE) AND
                      (statRefNo <> statRespParameter.header.refNo) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_REFERENCE_NO;
                     statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                      // Error : Invalid response from the drive object (reqId: 16#01 - reading parameter successful; 16#81: reading parameter finished with error; 16#02: writing parameter sucessful; 16#82: writing parameter finished with error)
                    ELSIF (statCmdBusy = FALSE) AND
                      NOT (statRespParameter.header.reqId = byte#16#81 OR statRespParameter.header.reqId = byte#16#01 OR statRespParameter.header.reqId = byte#16#02 OR statRespParameter.header.reqId = byte#16#82) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_RESPONSE_ID;
                     statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                      // Error : The received number of parameters does not match with the requested number of parameters
                    ELSIF (statCmdBusy = FALSE) AND
                      (statCountOfElements <> TO_INT(statRespParameter.header.parameterNo)) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_PARAMETER_NO;
                     statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                      // Error : The drive object does not match with the responsed DO
                    ELSIF (statCmdBusy = FALSE) AND
                      (statDoId <> statRespParameter.header.doId) AND
                      (tempCmdValid = TRUE) THEN


                     statStateNumber := statFBSubState;
                     statStatus := ERR_DRIVE_OBJECT_NO;
                     statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                      // No error occurred during reading parameters
                    ELSIF (statCmdBusy = FALSE) AND (tempCmdValid = TRUE) AND  not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN

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
                               statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostic
                                 tempPointer := tempPointer + 4; // Points to the next parameter address

                              FORMAT_INTEGER_32, FORMAT_UNSIGNED_32, FORMAT_TIME_DIFFERENCE, FORMAT_FLOATING_POINT, FORMAT_DOUBLE_WORD:
                               statParameter[tempLoopIndex].errorValue := byte#16#FF; // Sets the error status and diagnostics
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
                        IF (statRespParameter.header.reqId = byte#16#82) THEN  // reqId: 16#82 (Error occurred during writing paramaters)
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
                             statParameter[tempLoopIndex].errorValue := byte#16#FF;
                               tempPointer := tempPointer + 2;
                            END_IF;
                            dataset[tempLoopIndex]:=tempActualElementReal;
                          END_FOR;
                        END_IF; // Error occurred during writing process (changing parameter values)

                       statCmdBusy := FALSE;
                       statCmdError := FALSE;
                       statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC_1;

                          // Next state is depending on the FB mode
                          IF not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
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
// TODO config in Start ausser requestBuffer
        METHOD PUBLIC Start : bool

            VAR_INPUT
                driveObjectId  : UInt := UINT#0;   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                hardwareId : HW_IO;   // Hardware identifier of the hardware module
                parameterCount : Int := -1;   // Count of parameters to read (-1: read all parameter in dataset)
            END_VAR

             statparameterCount := parameterCount;
             statDoId := to_byte(driveObjectId);
             statHwId := hardwareId;

             // starts functionality
             IF not ((statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                 statFBState = LAcycCom_ReadWriteStatus#FB_DONE) AND
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

        Method public DeleteList : bool
            Var
                z : Int;
            END_VAR

            For z := 0 to LAcycComConstantsInt#LACYCCOM_WRITE_PARAMETERS_UPPER_LIM do
                dataset[z].DWvalue  := DWORD#0;
                dataset[z].errorValue := BYTE#0;
                dataset[z].index    := UINT#0;
                dataset[z].parameterNumber := UINT#0;
                dataset[z].Rvalue    := real#0.0;
            end_FOR;

        End_Method

        Method public AddatasetItem : int //Rückgabewert = anzahl der Listeneinträge
            VAR_INPUT
                datasetItem : LAcycCom_typeDriveDataset;
                element_no  : int := int#-1; //-1 element an die liste anhängen. >=0 element überschreiben
            end_VAR
            VAR_TEMP
                tempLoopIndex : Int;
            end_VAR
            If element_no = -1 and statCountOfElements < LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM Then
                    dataset[statCountOfElements] :=datasetItem;
                AddatasetItem := statCountOfElements;
                statCountOfElements := statCountOfElements + 1;

            elsif element_no > -1 and
                element_no < LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM and
                element_no <= statCountOfElements Then
                    dataset[element_no] :=datasetItem;
                If element_no = statCountOfElements Then
                    statCountOfElements := statCountOfElements + 1;
                end_IF;
            else
                AddatasetItem := -1;
            end_if;

        End_Method
    END_CLASS
END_NAMESPACE    