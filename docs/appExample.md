# Application example

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
