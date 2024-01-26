# @simatic-ax.lacyccom

## Description

The following section shows a scenario for a possible application of the LAcycCom
library:

With acyclic data exchange, contrary to cyclic communication, data transfer takes place when an explicit request is made, e.g. in order to read and write drive object parameters. Acyclic parameter access occurs parallel to the cyclic process data exchange. This saves resources, since the data is only requested on demand, i. e. when a parameter has to be transferred.The "Read data record" and "Write data record" services are available for acyclic data exchange.

According to the PROFIdrive profile, for drives in conformance with PROFIdrive, only one DPV1 (asynchronous PROFIBUS communication) request is permissible for each drive object and control unit for non-cyclic (acyclic) communication (parameter requests). If two or more DPV1 requests are simultaneously issued to a drive unit, conflicts can occur when processing the request in the drive unit. These conflicts then cause the different DPV1 requests to mutually interfere with one another. In order to prevent that such bus conflict occurs, it is the user’s responsibility to avoid that and a check must be made for each new DPV1 request whether another request is already active on the drive object involved. This is certainly the case if system functions are also used that are not exclusively intended to communicate to drive units via DPV1 services.

In order to relieve the user of this task a request management called Resource Manager exists that handles the management of DPV1 services for the user. This function is presented here. However, the introduction of this request management assumes as prerequisite that each function, which utilizes DPV1 services, will also actually use them.

## Install this package

Enter:

```cli
apax add @simatic-ax/lacyccom
```

## Namespace

```iec-st
Simatic.Ax.LAcycCom;
```

## Objects

## Example

```cli
USING Simatic.Ax.LAcycCom;

PROGRAM MyProgram
    VAR
        Resourcemanager         : OOPLAcycCom_ResourceManager;
        WriteParameterSingle    : LAcycCom_classWriteDriveSingleParams;
        ReadParameterSingle     : LAcycCom_classReadDriveSingleParams;
        WriteParameter          : LAcycCom_classWriteDriveParams;
        ReadParameter           : LAcycCom_classReadDriveParams;
        diagnostic : LAcycCom_ooptypeDrivediagnostics;
        RVALUEp304 : real;
        RVALUEp305 : real;
        RVALUEp310 : real;
        FirstCycle : Bool := TRUE;
        datasetitemread : LAcycCom_typeDriveDataset;
        datasetitemwrite : LAcycCom_typeDriveDataset;
        elements : int;
    END_VAR

    Resourcemanager.execute();

    ReadParameter.execute();
    ReadParameterSingle.execute();
    WriteParameter.execute();
    WriteParameterSingle.execute();

    If FirstCycle Then
        ReadParameter.Config(requestBuffer   := Resourcemanager);
        ReadParameterSingle.Config(requestBuffer   := Resourcemanager);
        WriteParameter.Config(requestBuffer   := Resourcemanager);
        WriteParameterSingle.Config(requestBuffer   := Resourcemanager);
    end_IF;

    CASE ReadParameter.Status() OF
        LAcycComstateDef#BUSY :
            ;

        LAcycComstateDef#IDLE :
            datasetitemread.parameterNumber := uint#304;
            elements := ReadParameter.AddatasetItem(datasetItem := datasetitemread,
                                                    element_no  := -1);

            datasetitemread.parameterNumber := uint#305;
            elements := ReadParameter.AddatasetItem(datasetItem := datasetitemread,
                                                     element_no := -1);

            ReadParameter.Start(driveObjectId  := uint#5,
                                hardwareId     := word#269);

        LAcycComstateDef#DONE :
            datasetitemread := ReadParameter.ReaddatasetItem(element_no := 0);
            RVALUEp304 := datasetitemread.Rvalue;
            datasetitemread := ReadParameter.ReaddatasetItem(element_no := 1);
            RVALUEp305 := datasetitemread.Rvalue;

        LAcycComstateDef#ERROR :
            diagnostic := ReadParameter.errordiagnostics();
    END_CASE;

    CASE ReadParameterSingle.Status() OF
        LAcycComstateDef#BUSY :
            ;

        LAcycComstateDef#IDLE :
            ReadParameterSingle.Start(  driveObjectId      := uint#5,
                                        hardwareId         := word#269,
                                        parameterNumber    := uint#310,
                                        index              := uint#0);

        LAcycComstateDef#DONE :
        RVALUEp310 := ReadParameterSingle.GetValueREAL();

        LAcycComstateDef#ERROR :
            diagnostic := ReadParameterSingle.errordiagnostics();
    END_CASE;

    CASE WriteParameter.Status() OF
        LAcycComstateDef#BUSY :
            ;

        LAcycComstateDef#IDLE :

            datasetitemwrite.parameterNumber := uint#2900;
            datasetitemwrite.Rvalue  := real#12.3;
            elements := WriteParameter.AddatasetItem(datasetItem := datasetitemwrite,
                                                      element_no := -1);

            datasetitemwrite.parameterNumber := uint#2901;
            datasetitemwrite.Rvalue  := real#45.6;
            elements := WriteParameter.AddatasetItem(datasetItem := datasetitemwrite,
                                                    element_no   := -1);

            WriteParameter.Start(driveObjectId  := uint#5,
                                 hardwareId     := word#269);

        LAcycComstateDef#DONE :
            ;

        LAcycComstateDef#ERROR :
            diagnostic := WriteParameter.errordiagnostics();
    END_CASE;

    CASE WriteParameterSingle.Status() OF
        LAcycComstateDef#BUSY :
            ;

        LAcycComstateDef#IDLE :
        WriteParameterSingle.Start( driveObjectId   := uint#5,
                                    hardwareId      := word#269,
                                    parameterNumber := uint#2930,
                                    value           := REAL#78.9,
                                    index           := uint#0);

        LAcycComstateDef#DONE :
            ;

        LAcycComstateDef#ERROR :
            diagnostic := WriteParameterSingle.errordiagnostics();
    END_CASE;

    FirstCycle := False;
END_PROGRAM
```

## Contribution

Thanks for your interest in contributing. Anybody is free to report bugs, unclear documentation, and other problems regarding this repository in the Issues section or, even better, is free to propose any changes to this repository using Merge Requests.

## License and Legal information

Please read the [Legal information](LICENSE.md)
