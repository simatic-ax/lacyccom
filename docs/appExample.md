# Application example

Below, you can find an example program using the library. It uses the classes 'WriteParameterSingle' and 'ReadParameter' to cyclically read and write from and to a S120 drive system. The example communicates with the S120 control unit CU320-2.

It reads parameter 969 of the control unit, the relative system runtime. It writes the parameter 4730, the CU trace configuration. The control unit always has 1 as drive object id.

If you want to read or write to a different device, please make sure to change the drive object id. 

Please also make sure to address the drive using the correct hardware id.

```cli
USING Simatic.Ax.LAcycCom;

CONFIGURATION MyConfiguration
    TASK Main(Priority := 1);
    
    PROGRAM P1 WITH Main : lacyccom_example;
    VAR_GLOBAL
        diagnosticRead  : LAcycCom_ooptypeDrivediagnostics;
        diagnosticWrite : LAcycCom_ooptypeDrivediagnostics;
        statusRead      : LAcycComstateDef;
        statusWrite     : LAcycComstateDef;
        SystemRuntime   : UDINT;
    END_VAR

END_CONFIGURATION

PROGRAM lacyccom_example
    //global data
    VAR_EXTERNAL
        diagnosticWrite: LAcycCom_ooptypeDrivediagnostics;
        diagnosticRead : LAcycCom_ooptypeDrivediagnostics;
        statusRead     : LAcycComstateDef;
        statusWrite    : LAcycComstateDef;
        SystemRuntime  : UDINT;
    END_VAR

    VAR //Instances
        Resourcemanager         : OOPLAcycCom_ResourceManager;
        WriteParameterSingle    : LAcycCom_classWriteDriveSingleParams;
        ReadParameter           : LAcycCom_classReadDriveParams;
    END_VAR

    VAR CONSTANT //constants: Change the hardware id of the drive according to the hwid in the hardware configuration
        HARDWARE_ID        : HW_IO := UINT#262;
        DO_ID_CONTROL_UNIT : INT   := 1;
    END_VAR

    VAR //variables for application example
        FirstCycle : BOOL := TRUE;
    END_VAR

    VAR_TEMP
        datasetitem : LAcycCom_typeDriveDataset;
    END_VAR

    IF FirstCycle THEN
        //Initialization: Attach resource manager to read and write class
        ReadParameter.Config(requestBuffer := Resourcemanager);
        WriteParameterSingle.Config(requestBuffer := Resourcemanager);

        //configure parameter for reading to list. In this example: system runtime of a CU320-2
        datasetitem.parameterNumber := UINT#969;
        datasetitem.index := UINT#0;
        //add parameter to list
        ReadParameter.AddatasetItem(datasetItem := datasetItem, element_no := -1);
        //reset initialization bit
        FirstCycle := FALSE;
    END_IF;
 
    //get status for read and write operation
    statusRead := ReadParameter.Status();
    statusWrite := WriteParameterSingle.Status();

    //state machine for reading parameters
    CASE statusRead OF
        LAcycComstateDef#IDLE, LAcycComstateDef#DONE :
            //retreive last value. Since we only used one parameter, its index is 0
            SystemRuntime := TO_UDINT(ReadParameter.ReaddatasetDWValue(element_no := 0));
            //restart read request
            ReadParameter.Start(
                driveObjectID := DO_ID_CONTROL_UNIT,
                HardwareID    := HARDWARE_ID
            );
        LAcycComstateDef#BUSY :
            ;
        LAcycComstateDef#ERROR :
                //collect error information if an error occured
                //in this example, there is no recovery from errors. If you exeperience an error, you may start a new command from the error state
            diagnosticRead := WriteParameterSingle.errordiagnostics();
    END_CASE;

    //state machine for writing a single parameter
    CASE statusWrite OF

        LAcycComstateDef#IDLE, LAcycComstateDef#DONE :

        //start write command, if it is idle or the previous command was done
        //The parameter being written here is just an example. Please make sure to not overwrite important data when executing this example
            WriteParameterSingle.Start(
                driveObjectId   := DO_ID_CONTROL_UNIT,
                hardwareId      := HARDWARE_ID,
                parameterNumber := UINT#4730,
                index           := UINT#0,
                dwValue         := DWORD#1
            );
        LAcycComstateDef#BUSY :
            ;
        LAcycComstateDef#ERROR :
            //collect error information if an error occured
            //in this example, there is no recovery from errors. If you exeperience an error, you may start a new command from the error state
            diagnosticWrite := WriteParameterSingle.errordiagnostics();
    END_CASE;

    //call execute methods for reading, writing and for the resource manager
    ReadParameter.execute();
    WriteParameterSingle.execute();
    Resourcemanager.execute();

END_PROGRAM

```
