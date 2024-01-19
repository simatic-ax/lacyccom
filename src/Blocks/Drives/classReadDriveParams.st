using system.timer;
using siemens.Simatic.S71500.DistributedIO;

NAMESPACE Simatic.Ax.LAcycCom
    CLASS LAcycCom_classReadDriveParams EXTENDS ReadWriteParameter
        var Private
            statparameterCount : INT := -1;
            dataset            : Array[0..LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM] of LAcycCom_typeDriveDataset;          // Dataset with all parameters to be read
            statParameter      : Array[0..LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatstatParameter;     // Parameter dataset
            parameterAddress   : Array[0..LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM] of LAcycCom_TypestatparameterAddress;  // Parameter data in telegram
          end_VAR


        METHOD OVERRIDE BUSY
            VAR_TEMP
                tempCmdValid          : BOOL;                       // TRUE: New data record was received and is valid
                tempStatusWord        : WORD;                       // Temporary status
                tempWord              : WORD;                       // Temporary WORD variable
                tempPointer           : INT;                        // Temporary pointer variable
                tempLoopIndex         : INT;                        // Temporary loop index variable
                tempBlkVariant        : INT;                        // Temporary result of MOVE_BLK_VARIANT
                tempCmdStatus         : DWORD;                      // Temporary status of WRREC and RDREC command
                tempDWord             : DWORD;                      // Temporary DWORD variable
                tempActualElementReal : LAcycCom_typeDriveDataset;  // Temporary element of the dataset (REAL values)
             END_VAR

            IF (statrequestBuffer.GetRessource(statAllocatedIndex)=LAcycCom_ResourceManagerRetval#STATUS_BUSY)
                THEN
                  CASE statFBSubState OF
                    LAcycCom_ReadWriteStatus#FB_GET_SUBSTATE:
                      statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;

                    LAcycCom_ReadWriteStatus#FB_BUSY_WRREC:  // Writing the dataset configuration into the drive object

                      IF (statCmdBusy = FALSE) THEN
                        // Resets WRREC command
                        instWRREC(request := FALSE,
                                  RECORD := atmpRec);
                        // Creating header data
                        statReqParameter.header.refNo := statRefNo; // Telegram reference number
                        statReqParameter.header.reqId := BYTE#16#01;  // 0x01 = request parameters
                        statReqParameter.header.doId := statDoId;  // Drive object identification number
                        statReqParameter.header.parameterNo := TO_BYTE(statCountOfElements);  // Count of parameters

                        // Copying the dataset into a static variable (depending on the used PLC data type)

                          FOR tempLoopIndex := 0 TO statCountOfElements - 1 DO
                            tempActualElementReal := dataset[tempLoopIndex];

                            statParameter[tempLoopIndex].index := tempActualElementReal.index;
                            statParameter[tempLoopIndex].parameterNo := tempActualElementReal.parameterNumber;
                            statReqParameter.parameterAddress[tempLoopIndex].parameterNo := statParameter[tempLoopIndex].parameterNo;  // Parameter number
                            statReqParameter.parameterAddress[tempLoopIndex].index := statParameter[tempLoopIndex].index;  // Subindex of parameter
                         END_FOR;

                      END_IF; // statCmdBusy = FALSE
                      SerializeBig(UINT#0,
                                  statReqParameter,
                                  atmpSend );
                      // WRREC command
                      instWRREC(REQUEST := TRUE,                                                 // Transfer data record
                                 ID     := statHwId,           // ID number of the hardware component
                                 INDEX  := statDataRecordNo,   // Data record number
                                 LENGTH := UINT#0,             // Maximum length of the data record to be transferred in bytes
                                 DONE   => statCmdDone,        // Data record was transferred
                                 BUSY   => statCmdBusy,        // The writing process is not yet complete
                                 ERROR  => statCmdError,       // An error occurred during the writing process
                                 STATUS => tempCmdStatus,      // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                                 RECORD := atmpSend);          // Data record


                      // Error occurred
                      IF (statCmdError = TRUE) AND not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN
                        tempStatusWord.%B0 := tempCmdStatus.%B1;
                        tempStatusWord.%B1 := tempCmdStatus.%B2;

                        //Temporary command status (80A1, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                        IF (tempStatusWord = WORD#16#80A1) OR  // Negative acknowledgment when writing to the module
                          (tempStatusWord = WORD#16#80A7) OR   // DP slave or module is occupied (temporary error)
                          (tempStatusWord = WORD#16#80B5) OR   // DP slave or module not ready
                          (tempStatusWord = WORD#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
                          (tempStatusWord = WORD#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.
                          (tempStatusWord = WORD#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                          (tempStatusWord = WORD#16#80C3) OR   // The required operating resources are currently occupied.
                          (tempStatusWord = WORD#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.

                          IF (statErrorCount >= MAX_ERROR_COUNT) THEN
                            statStateNumber := statFBSubState;
                            statSubfunctionStatus := tempStatusWord;
                            statStatus := ERR_WRREC_TEMP_COUNTER;
                            statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                          ELSE
                            statErrorCount := statErrorCount + UINT#1;  // Increment internal error counter
                            statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
                            statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WAIT;
                          END_IF;
                        ELSE
                          statStateNumber := statFBSubState;
                          statSubfunctionStatus := tempStatusWord;
                          statStatus := ERR_WRREC;
                          statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                        END_IF;

                      ELSIF (statCmdDone = TRUE) AND not(statFBState = LAcycCom_ReadWriteStatus#FB_ERROR) THEN  // Processing completed without errors
                        statErrorCount := UINT#0;  // V1.5.1 Reset error counter
                        statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_RDREC; // WRREC completed and continue with RDREC
                      END_IF; // statCmdError = TRUE

                      LAcycCom_ReadWriteStatus#FB_BUSY_RDREC:  // Reading the values from the drive object
                      // Resets RDREC command
                      IF (statCmdBusy = FALSE) THEN
                        instRDREC(REQUEST := FALSE,
                                   RECORD := atmpRec);
                      END_IF;

                      instRDREC(REQUEST := True,                                                 // Transfer data record
                                 ID := statHwId,                                                 // ID number of the hardware component
                                 INDEX := statDataRecordNo,                                                     // Data record number
                                 MAXLENGTH := UINT#0,                                                        // Maximum length in bytes of the data record information to be read
                                 VALID => tempCmdValid,                                          // New data record was received and is valid
                                 BUSY => statCmdBusy,                                            // The reading process is not yet complete
                                 ERROR => statCmdError,                                          // An error occurred during the reading process
                                 STATUS => tempCmdStatus,                                        // Status[1] = Error => Status[2] Error Decode + Status[3] Error Code
                                 RECORD := atmpRec);                                   // Destination area for the data record read


                      DeserializeBig(UINT#0,
                                 atmpRec,
                                 statRespParameter);
                      // Error occurred
                      IF (statCmdError = TRUE) THEN
                        // Get the error information from the status information
                        tempStatusWord.%B0 := tempCmdStatus.%B1;
                        tempStatusWord.%B1 := tempCmdStatus.%B2;

                        //Temporary command status (80A0, 80A7, 80B5, 80C0, 80C1, 80C2, 80C3 oder 80C4) are valid and retry command
                        IF (tempStatusWord = WORD#16#80A0) OR  // Negative acknowledgment when reading the module
                          (tempStatusWord = WORD#16#80A7) OR   // DP slave or module is occupied (temporary error)
                          (tempStatusWord = WORD#16#80B5) OR   // DP slave or module not ready
                          (tempStatusWord = WORD#16#80C0) OR   // The data can only be written when the CPU is in STOP mode. Note: this means that writing by the user program is not possible. You can only write the data online with PG/PC.
                          (tempStatusWord = WORD#16#80C1) OR   // The data of the previous write job on the module for the same data record have not yet been processed by the module.
                          (tempStatusWord = WORD#16#80C2) OR   // The module is currently processing the maximum possible number of jobs for a CPU.
                          (tempStatusWord = WORD#16#80C3) OR   // The required operating resources are currently occupied.
                          (tempStatusWord = WORD#16#80C4) THEN // Internal temporary error. Job could not be executed. Repeat the job. If this error occurs often, check your installation for sources of electrical interference.

                          IF (statErrorCount >= MAX_ERROR_COUNT) THEN
                            statStateNumber := statFBSubState;
                            statSubfunctionStatus := tempStatusWord;
                            statStatus := ERR_RDREC_TEMP_COUNTER;
                            statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                          ELSE
                            statErrorCount := statErrorCount + UINT#1;  // Increment internal error counter
                            statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_RDREC;
                            // V1.3.2. If error 80A0 then should be retry with WRREC command
                            IF (tempStatusWord = WORD#16#80A0) THEN
                              statFBSubStateOld := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
                            END_IF;
                            statFBSubState := LAcycCom_ReadWriteStatus#FB_BUSY_WAIT;
                          END_IF; // statErrorCount >= MAX_ERROR_COUNT
                        ELSE
                          statStateNumber := statFBSubState;
                          statSubfunctionStatus := tempStatusWord;
                          statStatus := ERR_RDREC;
                          statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                        END_IF;

                        // Error : Reference number of the request does not match with the response reference number
                      ELSIF (statCmdBusy = FALSE) AND
                        (statRefNo <> statRespParameter.header.refNo) AND
                        (tempCmdValid = TRUE) THEN

                        statStateNumber := statFBSubState;
                        statStatus := ERR_REFERENCE_NO;
                        statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;

                        // Error : Invalid response from the drive object (reqId: 16#01 - reading parameter successful; 16#81: reading parameter finished with error)
                      ELSIF NOT (statRespParameter.header.reqId = BYTE#16#81 OR statRespParameter.header.reqId = BYTE#16#01) AND
                        (statCmdBusy = FALSE) AND
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

                            // Format = Error, summarize the first and second error BYTE in a WORD error variable for each parameter
                            statParameter[tempLoopIndex].errorValue := statRespParameter.data[tempPointer + 3];
                            IF (statFirstParameterError = NO_PARAMETER_ERROR) THEN
                              statdiagnostics.firstParameterError := tempLoopIndex;
                              statdiagnostics.errorValue := statParameter[tempLoopIndex].errorValue; // V1.3.2
                              statFirstParameterError := tempLoopIndex;
                              statStateNumber := statFBSubState;
                              statStatus := ERR_PARAMETER;
                              statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                            END_IF;
                            // Points to the next parameter address
                            tempPointer := tempPointer + 6;

                          ELSE

                            CASE TO_SINT(statRespParameter.data[tempPointer]) OF
                              FORMAT_INTEGER_8:

                                  statParameter[tempLoopIndex].realValue := TO_REAL(TO_SINT(statRespParameter.data[tempPointer + 2]));
                                  statParameter[tempLoopIndex].dwordValue := statRespParameter.data[tempPointer + 2];

                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 4; // Points to the next parameter address

                              FORMAT_INTEGER_16:
                                tempWord.%B0 := statRespParameter.data[tempPointer + 3];
                                tempWord.%B1 := statRespParameter.data[tempPointer + 2];


                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_INT(tempWord));
                                statParameter[tempLoopIndex].dwordValue := tempWord;
                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 4; // Points to the next parameter address

                              FORMAT_INTEGER_32:
                                tempDWord.%B0 := statRespParameter.data[tempPointer + 5];
                                tempDWord.%B1 := statRespParameter.data[tempPointer + 4];
                                tempDWord.%B2 := statRespParameter.data[tempPointer + 3];
                                tempDWord.%B3 := statRespParameter.data[tempPointer + 2];

                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_DINT(tempDWord));
                                statParameter[tempLoopIndex].dwordValue := tempDWord;


                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 6; // Points to the next parameter address

                              FORMAT_UNSIGNED_8, FORMAT_OCTET_STRING: // V1.5 change OCTET_STRING

                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_USINT(statRespParameter.data[tempPointer + 2]));
                                statParameter[tempLoopIndex].dwordValue := statRespParameter.data[tempPointer + 2];

                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 4; // Points to the next parameter address
                              FORMAT_UNSIGNED_16:
                                tempWord.%B0 := statRespParameter.data[tempPointer + 3];
                                tempWord.%B1 := statRespParameter.data[tempPointer + 2];

                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_UINT(tempWord));
                                statParameter[tempLoopIndex].dwordValue := tempWord;

                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 4; // Points to the next parameter address

                              FORMAT_UNSIGNED_32, FORMAT_TIME_DIFFERENCE:
                                tempDWord.%B0 := statRespParameter.data[tempPointer + 5];
                                tempDWord.%B1 := statRespParameter.data[tempPointer + 4];
                                tempDWord.%B2 := statRespParameter.data[tempPointer + 3];
                                tempDWord.%B3 := statRespParameter.data[tempPointer + 2];

                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_UDINT(tempDWord));
                                statParameter[tempLoopIndex].dwordValue := tempDWord;

                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 6; // Points to the next parameter address

                              FORMAT_FLOATING_POINT, FORMAT_DOUBLE_WORD:
                                tempDWord.%B0 := statRespParameter.data[tempPointer + 5];
                                tempDWord.%B1 := statRespParameter.data[tempPointer + 4];
                                tempDWord.%B2 := statRespParameter.data[tempPointer + 3];
                                tempDWord.%B3 := statRespParameter.data[tempPointer + 2];

                                statParameter[tempLoopIndex].realValue := TO_REAL(tempDWord);
                                statParameter[tempLoopIndex].dwordValue := tempDWord;

                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 6; // Points to the next parameter address

                              FORMAT_BYTE:
                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_DWORD(statRespParameter.data[tempPointer + 2]));
                                statParameter[tempLoopIndex].dwordValue := statRespParameter.data[tempPointer + 2];

                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 4; // Points to the next parameter address

                              FORMAT_WORD:
                                tempWord.%B0 := statRespParameter.data[tempPointer + 3];
                                tempWord.%B1 := statRespParameter.data[tempPointer + 2];

                                statParameter[tempLoopIndex].realValue := TO_REAL(TO_DWORD(tempWord));
                                statParameter[tempLoopIndex].dwordValue := tempWord;

                                statParameter[tempLoopIndex].errorValue := BYTE#16#FF; // Sets the error status and diagnostics
                                tempPointer := tempPointer + 4; // Points to the next parameter address

                              ELSE
                                ;
                            END_CASE;

                          END_IF; // Format = Error
                        END_FOR; // Analyse of the response buffer

                        // Copying parameter data into the dataset (depending on the used PLC data type)

                          FOR tempLoopIndex := 0 TO statCountOfElements - 1 BY 1 DO
                            tempActualElementReal.index := statParameter[tempLoopIndex].index;
                            tempActualElementReal.parameterNumber := statParameter[tempLoopIndex].parameterNo;
                            tempActualElementReal.Rvalue := statParameter[tempLoopIndex].realValue;
                            tempActualElementReal.DWvalue := statParameter[tempLoopIndex].dwordValue;
                            tempActualElementReal.errorValue := statParameter[tempLoopIndex].errorValue;
                           // tempBlkVariant := MOVE_BLK_VARIANT(SRC := tempActualElementReal, COUNT := 1, SRC_INDEX := 0, DEST_INDEX := tempLoopIndex, DEST => dataset);
                            dataset[tempLoopIndex] := tempActualElementReal;
                            // Error occurred during MOVE_BLK_VARIANT command
                            IF (tempBlkVariant <> 0) THEN
                              statStateNumber := statFBSubState;
                              statSubfunctionStatus := TO_WORD(tempBlkVariant);
                              statStatus := ERR_MOVE_BLK_VARIANT;
                              statFBState := LAcycCom_ReadWriteStatus#FB_ERROR;
                              statdiagnostics.firstParameterError := tempLoopIndex;
                            END_IF;
                          END_FOR;


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
                END_IF; // ((buffer.element[statAllocatedIndex].enable = TRUE) AND (statMode = MODE_WITH_BUFFER_MANAGER)) OR statMode = MODE_WITHOUT_BUFFER_MANAGER

        END_METHOD

        METHOD PUBLIC Start : BOOL
            VAR_INPUT
              driveObjectId  : UINT := UINT#0;  // Optional: Identification number of the drive object (value =0: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId)
              hardwareId     : HW_IO;           // Hardware identifier of the hardware module
              parameterCount : INT := -1;       // Count of parameters to read (-1: read all parameter in dataset)
            END_VAR

             statparameterCount := parameterCount;
             statDoId           := to_byte(driveObjectId);
             statHwId           := hardwareId;

             // starts functionality
             IF not ((statFBState = LAcycCom_ReadWriteStatus#FB_IDLE OR
                 statFBState = LAcycCom_ReadWriteStatus#FB_DONE) AND
                 statrequestBuffer <> NULL) THEN
                   Start := False;
             ELSE
               // Initialisation
               Start := TRUE;
               statAllocatedIndex      := -1;
               statSubfunctionStatus   := WORD#16#0000;
               statDataRecordNo        := DINT#0;
               statStateNumber         := LAcycCom_ReadWriteStatus#FB_IDLE;
               statDatasetType         := SINT#0;
               statFirstParameterError := -1;
               statErrorCount          := UINT#0;
               statFBSubState          := LAcycCom_ReadWriteStatus#FB_BUSY_WRREC;
               statFBState             := LAcycCom_ReadWriteStatus#FB_FIRST_CYCLE;

               instIECTimer(signal := FALSE,
                             duration := TIMER_ALLOCATION);
             end_if;
        END_METHOD

        Method public DeleteList : BOOL
            Var
                z : INT;
            END_VAR

            For z := 0 to LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM do
                dataset[z].DWvalue  := DWORD#0;
                dataset[z].errorValue := BYTE#0;
                dataset[z].index    := UINT#0;
                dataset[z].parameterNumber := UINT#0;
                dataset[z].Rvalue    := REAL#0.0;
            end_FOR;
            statCountOfElements := 0;
        End_Method

        Method public AddDatasetItem : INT //Rückgabewert = anzahl der Listeneinträge
            VAR_INPUT
                datasetItem : LAcycCom_typeDriveDataset;
                element_no  : INT := INT#-1; //-1 element an die liste anhängen. >=0 element überschreiben
            end_VAR
            VAR_TEMP
                tempLoopIndex : INT;
            end_VAR
            If element_no = -1 and statCountOfElements < LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM Then
                    dataset[statCountOfElements] :=datasetItem;
                statCountOfElements := statCountOfElements + 1;
                AddDatasetItem := statCountOfElements;

            elsif element_no > -1 and
                element_no < LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM and
                element_no <= statCountOfElements Then
                    dataset[element_no] :=datasetItem;
                    If element_no = statCountOfElements Then
                        statCountOfElements := statCountOfElements + 1;
                    end_IF;
                    AddDatasetItem := statCountOfElements;
            else
                AddDatasetItem := -1;
            end_if;

        End_Method

        Method public ReadDatasetItem : LAcycCom_typeDriveDataset
            VAR_INPUT
                element_no  : INT := INT#0;
            end_VAR
            VAR_TEMP
                tempLoopIndex : INT;
            end_VAR

            If element_no >= 0 and element_no <= LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM Then
                ReadDatasetItem := dataset[element_no];
            end_if;

        End_Method

        Method public ReadDatasetValue : REAL
          VAR_INPUT
              element_no  : INT := INT#0;
          end_VAR
          VAR_TEMP
              tempLoopIndex : INT;
          end_VAR

          If element_no >= 0 and element_no <= LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM Then
            ReadDatasetValue := dataset[element_no].Rvalue;
          end_if;

        End_Method

        Method public ReaddatasetDWValue : DWORD
          VAR_INPUT
              element_no  : INT := INT#0;
          end_VAR
          VAR_TEMP
              tempLoopIndex : INT;
          end_VAR

          If element_no >= 0 and element_no <= LAcycComConstantsInt#LACYCCOM_READ_PARAMETERS_UPPER_LIM Then
            ReaddatasetDWValue := dataset[element_no].DWvalue;
          end_if;

        End_Method

    END_CLASS
END_NAMESPACE
