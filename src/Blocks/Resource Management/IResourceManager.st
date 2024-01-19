NAMESPACE Simatic.Ax.LAcycCom

    INTERFACE IResourcemanager
    
        METHOD Allocate : Int //AllocatedIndex
            VAR_INPUT
                hardwareId : HW_IO; // Hardware identifier of the hardware module
            END_VAR
        END_METHOD

        METHOD GetRessource : LAcycCom_ResourceManagerRetval
            VAR_INPUT
                AllocatedIndex : INT;
            END_VAR
        END_METHOD

        METHOD Release : LAcycCom_ResourceManagerRetval
            VAR_INPUT
                AllocatedIndex : INT;
            END_VAR
        END_METHOD

    END_INTERFACE

END_NAMESPACE
