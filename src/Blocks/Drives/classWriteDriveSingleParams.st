using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom
    CLASS LAcycCom_classWriteDriveSingleParams EXTENDS ReadWriteParameter
        var Private
            statparameterNumber : UInt;   // Number of the parameter
            statindex : UInt;   // Parameter index
            statParameterValue : REAL;
            statParameterDWValue : DWORD;
            statReqWriteParameter  : LAcycCom_TypestatReqWriteParameter;   // Request telegram to change the parameter values
            statReqReadParameter   : LAcycCom_TypestatstatReqParameter;   // Request telegram
        end_VAR

        VAR CONSTANT
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
             IF (statrequestBuffer.GetRessource(statAllocatedIndex)=OOP_ResourceManager_retval#STATUS_BUSY) THEN

                CASE  statFBSubState OF
                    OOP_ReadWriteStatus#FB_GET_SUBSTATE:
                        statFBSubState := OOP_ReadWriteStatus#FB_BUSY_WRREC_1;
                        statReqReadParameter.parameterAddress[0] := statReqParameterInit;
                        FOR tempLoopIndex := 0 TO LENGTH_WRITE_TELEGRAM_UPPER_LIM DO
                           atmpRec[tempLoopIndex] := byte#0;
                        END_FOR;

                    OOP_READWRITESTATUS#FB_BUSY_WRREC_1,  OOP_READWRITESTATUS#FB_BUSY_WRREC_2:  // Writing the dataset configuration into the drive object

                    IF (statCmdBusy = FALSE) AND (statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_WRREC_1) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) THEN
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
                       statParameter[0].realValue :=  statParameterValue;
                       statParameter[0].dwordValue := statParameterDWValue;
                       statReqReadParameter.parameterAddress[0].parameterNo :=  statParameter[0].parameterNo;  // Parameter number
                       statReqReadParameter.parameterAddress[0].index :=  statParameter[0].index;  // Subindex of parameter

                    ELSIF (statCmdBusy = FALSE) AND (statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_WRREC_2) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) THEN
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
                       statParameter[0].index :=  statindex;
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

                    IF (statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_WRREC_1) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) THEN
                      // WRREC command
                                 // Data record
                      SerializeBig(uint#0,
                                     statReqReadParameter,
                                      atmpSend );

                       instWRREC(request := TRUE,                                                // Transfer data record
                                 ID :=  statHwId,                                                // ID number of the hardware component
                                 INDEX :=  statDataRecordNo,                                     // Data record number
                                 LENGTH := uint#0,                                               // Maximum length of the data record to be transferred in bytes
                                 DONE =>  statCmdDone,                                           // Data record was transferred
                                 BUSY =>  statCmdBusy,                                           // The writing process is not yet complete
                                 ERROR =>  statCmdError,                                         // An error occurred during the writing process
                                 STATUS =>  tempCmdStatus,                                       // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                                 RECORD :=  atmpSend);                                           // Data record


                                       // Data record

                    ELSIF (statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_WRREC_2) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) THEN
                      // WRREC command
                      SerializeBig(uint#0,
                      statReqWriteParameter,
                      atmpSend );

                       instWRREC(request := TRUE,                                                // Transfer data record
                                 ID :=  statHwId,                                                // ID number of the hardware component
                                 INDEX :=  statDataRecordNo,                                     // Data record number
                                 LENGTH := uint#0,                                               // Maximum length of the data record to be transferred in bytes
                                 DONE =>  statCmdDone,                                           // Data record was transferred
                                 BUSY =>  statCmdBusy,                                           // The writing process is not yet complete
                                 ERROR =>  statCmdError,                                         // An error occurred during the writing process
                                 STATUS =>  tempCmdStatus,                                       // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                                 RECORD :=  atmpSend);                                           // Data record
                    END_IF;

                    // Error occurred
                    IF (statCmdError = TRUE) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) THEN
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

                           statStateNumber :=  statFBSubState;
                           statSubfunctionStatus :=  tempStatusWord;
                           statStatus :=  ERR_WRREC_TEMP_COUNTER;
                           statFBState :=   OOP_READWRITESTATUS#FB_ERROR;
                        ELSE
                           statErrorCount :=  statErrorCount + usint#1;  // Increment internal error counter
                           statFBSubStateOld :=  statFBSubState;
                           statFBSubState :=  OOP_READWRITESTATUS#FB_BUSY_WAIT;
                        END_IF;
                      ELSE
                         statStateNumber :=  statFBSubState;
                         statSubfunctionStatus :=  tempStatusWord;
                         statStatus :=  ERR_WRREC;
                         statFBState :=   OOP_READWRITESTATUS#FB_ERROR;
                      END_IF; // Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command

                    ELSIF (statCmdBusy = FALSE) AND (statCmdDone = TRUE) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) AND (statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_WRREC_1) THEN  // Processing completed without errors
                       statErrorCount := uint#0;  // V1.5.1 Reset error counter
                       statFBSubState :=  OOP_READWRITESTATUS#FB_BUSY_RDREC_1; // WRREC completed and continue with RDREC

                    ELSIF (statCmdBusy = FALSE) AND (statCmdDone = TRUE) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) AND (statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_WRREC_2) THEN  // Processing completed without errors
                       statErrorCount := uint#0;  // V1.5.1 Reset error counter
                       statFBSubState :=  OOP_READWRITESTATUS#FB_BUSY_RDREC_2; // WRREC completed and continue with RDREC
                    END_IF; //  statCmdError = TRUE

                    OOP_READWRITESTATUS#FB_BUSY_RDREC_1,  OOP_READWRITESTATUS#FB_BUSY_RDREC_2:  // Reading the values from the drive object


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
                    IF (statCmdError = TRUE) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) THEN
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

                           statStateNumber :=  statFBSubState;
                           statSubfunctionStatus :=  tempStatusWord;
                           statStatus :=  ERR_RDREC_TEMP_COUNTER;
                           statFBState :=   OOP_READWRITESTATUS#FB_ERROR;
                        ELSE
                           statErrorCount :=  statErrorCount + usint#1;  // Increment internal error counter
                           statFBSubStateOld :=  statFBSubState;
                          // V1.3.2. If error 80A0 then should be retry with WRREC command
                          IF (tempStatusWord = word#16#80A0) AND  statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_RDREC_1 THEN
                             statFBSubStateOld :=  OOP_READWRITESTATUS#FB_BUSY_WRREC_1;
                          ELSIF (tempStatusWord = word#16#80A0) AND  statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_RDREC_2 THEN
                             statFBSubStateOld :=  OOP_READWRITESTATUS#FB_BUSY_WRREC_2;
                          END_IF;
                           statFBSubState :=  OOP_READWRITESTATUS#FB_BUSY_WAIT;
                        END_IF;
                      ELSE

                         statStateNumber :=  statFBSubState;
                         statSubfunctionStatus :=  tempStatusWord;
                         statStatus :=  ERR_RDREC;
                         statFBState :=   OOP_READWRITESTATUS#FB_ERROR;
                      END_IF; // Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command

                      // Error : Reference number of the request does not match with the response reference number
                    ELSIF (statCmdBusy = FALSE) AND
                      (statRefNo <> statRespParameter.header.refNo) AND
                      (tempCmdValid = TRUE) THEN


                       statStateNumber :=  statFBSubState;
                       statStatus :=  ERR_REFERENCE_NO;
                       statFBState :=   OOP_READWRITESTATUS#FB_ERROR;

                      // Error : Invalid response from the drive object (reqId: 16#01 - reading parameter successful; 16#81: reading parameter finished with error; 16#02: writing parameter sucessful; 16#82: writing parameter finished with error)
                    ELSIF (statCmdBusy = FALSE) AND
                      NOT (statRespParameter.header.reqId = byte#16#81 OR  statRespParameter.header.reqId = byte#16#01 OR  statRespParameter.header.reqId = byte#16#02 OR  statRespParameter.header.reqId = byte#16#82) AND
                      (tempCmdValid = TRUE) THEN


                       statStateNumber :=  statFBSubState;
                       statStatus :=  ERR_RESPONSE_ID;
                       statFBState :=   OOP_READWRITESTATUS#FB_ERROR;

                      // Error : The received number of parameters does not match with the requested number of parameters
                    ELSIF (statCmdBusy = FALSE) AND
                      (TO_INT(statRespParameter.header.parameterNo) <> 1) AND
                      (tempCmdValid = TRUE) THEN


                       statStateNumber :=  statFBSubState;
                       statStatus :=  ERR_PARAMETER_NO;
                       statFBState :=   OOP_READWRITESTATUS#FB_ERROR;

                      // Error : The drive object does not match with the responsed DO
                    ELSIF (statCmdBusy = FALSE) AND
                      (statDoId <>  statRespParameter.header.doId) AND
                      (tempCmdValid = TRUE) THEN


                       statStateNumber :=  statFBSubState;
                       statStatus :=  ERR_DRIVE_OBJECT_NO;
                       statFBState :=   OOP_READWRITESTATUS#FB_ERROR;

                      // No error occurred during reading parameters
                    ELSIF (statCmdBusy = FALSE) AND (tempCmdValid = TRUE) AND  not(statFBState = OOP_READWRITESTATUS#FB_ERROR) THEN

                      IF (statFBSubState =  OOP_READWRITESTATUS#FB_BUSY_RDREC_1) THEN

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
                           statdiagnostics.errorValue :=  statParameter[0].errorValue;
                        END_IF; // Format = Error

                         statCmdBusy := FALSE;
                         statCmdError := FALSE;
                         statFBState :=  OOP_READWRITESTATUS#FB_BUSY;
                         statFBSubState :=  OOP_READWRITESTATUS#FB_BUSY_WRREC_2;

                      ELSE
                        // Error occurred during writing process (changing parameter values)
                        IF (statRespParameter.header.reqId = byte#16#82) THEN  // reqId: 16#82 (Error occurred during writing paramaters)

                          // Parameter error
                          IF (statRespParameter.data[0] =  FORMAT_ERROR) THEN

                            // Save first parameter error in telegram
                                IF (statFirstParameterError =  NO_PARAMETER_ERROR) THEN
                                statFirstParameterError := 0;
                                statdiagnostics.firstParameterError :=  statFirstParameterError;

                                statStateNumber :=  statFBSubState;
                                statStatus :=  ERR_PARAMETER;
                                statFBState :=   OOP_READWRITESTATUS#FB_ERROR;
                                END_IF;

                             statParameter[0].errorValue :=  statRespParameter.data[3];
                             statdiagnostics.errorValue :=  statParameter[0].errorValue; // V1.3.2

                            // Parameter without errors
                          ELSE
                             statParameter[0].errorValue := byte#16#FF;
                          END_IF;

                          statdiagnostics.errorValue :=  statParameter[0].errorValue;
                        END_IF; // Error occurred during writing process (changing parameter values)

                         statCmdBusy := FALSE;
                         statCmdError := FALSE;
                         statFBSubState :=  OOP_READWRITESTATUS#FB_BUSY_WRREC_1;

                            // Next state is depending on the FB mode
                            IF not(statFBState = OOP_ReadWriteStatus#FB_ERROR) THEN
                                statStatus := STATUS_RELEASE;
                                statFBState := OOP_ReadWriteStatus#FB_RELEASE;

                            END_IF; // statMode = MODE_WITH_BUFFER_MANAGER
                      END_IF; //  statParameterConfig = TRUE
                    END_IF; //  statCmdError = TRUE

                    OOP_READWRITESTATUS#FB_BUSY_WAIT:
                    // Timer for temporary errors
                     instIECTimer(signal :=  statTimerStart,
                                 duration :=  TIMER_TEMP_ERROR);

                     statTimerStart := TRUE;
                    IF (instIECTimer.output = TRUE) THEN
                       statTimerStart := FALSE;
                       statFBSubState :=  statFBSubStateOld;
                    END_IF;

                  ELSE

                     statStatus :=  ERR_UNDEFINED_SUBSTATE;
                     statStateNumber :=  statFBState;
                     statFBState :=   OOP_READWRITESTATUS#FB_ERROR;
                END_CASE;

              ELSE

                 statStatus :=  ERR_COMMAND_TIMEOUT;
                 statStateNumber :=  statFBState;
                 statFBState :=   OOP_READWRITESTATUS#FB_ERROR;
              END_IF; // ((buffer.element[statAllocatedIndex].enable = TRUE) AND (statMode =  MODE_WITH_BUFFER_MANAGER)) OR  statMode =  MODE_WITHOUT_BUFFER_MANAGER

        END_METHOD

        METHOD PUBLIC Start : bool
            VAR_INPUT
                  driveObjectId  : UInt := UINT#0;   // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
                  hardwareId : HW_IO;   // Hardware identifier of the hardware module
                  parameterNumber : UInt;   // Number of the parameter
                  index : UInt;   // Parameter index
                  value   : REAL;
                  DWVALUE : DWORD;
            END_VAR

             statparameterNumber := parameterNumber;
             statindex := index;
             statParameterValue := value;
             statParameterDWValue := DWVALUE;
             statDoId := to_byte(driveObjectId);
             statHwId := hardwareId;

             // starts functionality
             IF not ((statFBState = OOP_ReadWriteStatus#FB_IDLE OR
                 statFBState = OOP_ReadWriteStatus#FB_DONE) AND
                 statrequestBuffer <> NULL) THEN
                   Start := False;
             ELSE
               // Initialisation
               Start := TRUE;
               statAllocatedIndex := -1;
               statSubfunctionStatus :=  word#16#0000;
               statDataRecordNo := dint#0;
               statStateNumber := OOP_ReadWriteStatus#FB_IDLE;
               statDatasetType := SINT#0;
               statFirstParameterError := -1;
               statErrorCount := uint#0;
               statFBSubState := OOP_ReadWriteStatus#FB_BUSY_WRREC;
               statFBState := OOP_ReadWriteStatus#FB_FIRST_CYCLE;

               instIECTimer(signal := FALSE,
                             duration := TIMER_ALLOCATION);


             END_IF;
        END_METHOD

    END_CLASS
END_NAMESPACE    