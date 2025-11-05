# Drive functions

## Abstract class ReadWriteParameter

This abstract class is the basis of all implementations. It contains basic functionality that is present in all implementations.

### Method execute

This method needs to be called cyclically during operation. It contains the main logic of the drive functions. It has no interface.

### Method errorDiagnostics

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| errorDiagnostics | LAcycCom_ooptypeDrivediagnostics | RETURN | Returns the diagnostic information of the class |

Used to retrieve diagnostic information, if an error occured during operation.

### Method Status

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| Status | LAcycComstateDef | RETURN | Returns the state of the class |

Used to receive the state of the operation.

### Method Config

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| requestBuffer | Resourcemanager | INPUT | Reference to the resource manager |
| Config | BOOL | RETURN | TRUE: Configuration was successful, FALSE: No valid configuration |

Used to attach a resource manager instance to the class. For operation, a valid resource manager is necessary.

## Class classReadDriveParams

### Method AddatasetItem

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| datasetItem | LAcycCom_typeDriveDataset | INPUT | Item you want to add to the dataset for a read request |
| element_no | INT | INPUT | -1: add to the list. >= 0: Overwrite item on the list |
| AddatasetItem | INT | RETURN | number of list entries after adding the dataset |

Adds a dataset item to the list of items you want to read from the drive. You can either write all items into a specific list element, or let the system attach the item to the list by setting the element number to -1.

### Method Start

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| driveObjectId | INT | INPUT | Optional: Identification number of the drive object (value = -1: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId) |
| hardwareId | HW_IO | INPUT | hardware id of the device |
| parameterCount | INT | INPUT | number of parameters to read |
| Start | BOOL | RETURN | TRUE: Command was started successfully FALSE: Command could not be started, there is an issue in the configuration |

Starts a request to read multiple parameters that have been added to the dataset list via the `AddatasetItem` method.

For compability reasons, there are two more methods with the name `start` in this class. In one instance, the input `driveObjectId` is set as an UINT for legacy users to avoid breaking existing applications. The second instance drops the input `driveObjectId` completely, if you are using the hardware id of the submodule.

### Method ReaddatasetItem

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| element_no | INT | INPUT | item index you want to read |
| ReaddatasetItem | LAcycCom_typeDriveDataset | RETURN | Returns the dataset for the element number you requested |

### Method ReaddatasetValue

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| element_no | INT | INPUT | item index you want to read |
| ReaddatasetValue | REAL | RETURN | Returns the value of the item formatted as a 32-bit floating point value (REAL) |

### Method ReaddatasetValue

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| element_no | INT | INPUT | item index you want to read |
| ReaddatasetValue | DWORD | RETURN | Returns the value of the item formatted as a DWORD value |

### Method DeleteList

Deletes the internal list of items. This method does not have a interface.

## Class classReadDriveSingleParams

### Method Start

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| driveObjectId | INT | INPUT | Optional: Identification number of the drive object (value = -1: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId) |
| hardwareId | HW_IO | INPUT | hardware id of the device |
| parameterNumber | INT | INPUT | number of parameter to read |
| index | UINT | INPUT | Index of the parameter |
| Start | BOOL | RETURN | TRUE: Command was started successfully FALSE: Command could not be started, there is an issue in the configuration |

Starts a request to read a single parameter defined at the input

For compability reasons, there are two more methods with the name `start` in this class. In one instance, the input `driveObjectId` is set as an UINT for legacy users to avoid breaking existing applications. The second instance drops the input `driveObjectId` completely, if you are using the hardware id of the submodule.

### Method GetValueREAL

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| GetValueREAL | REAL | RETURN | Returns the value of the item formatted as a 32-bit floating point value (REAL) |

### Method GetValueDWORD

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| GetValueDWORD | DWORD | RETURN | Returns the value of the item formatted as a DWORD value |

## Class LAcycCom_classWriteDriveParams

### Method AddatasetItem

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| datasetItem | LAcycCom_typeDriveDataset | INPUT | Item you want to add to the dataset for a write request |
| element_no | INT | INPUT | -1: add to the list. >= 0: Overwrite item on the list |
| AddatasetItem | INT | RETURN | number of list entries after adding the dataset |

Adds a dataset item to the list of items you want to write to the drive. You can either write all items into a specific list element, or let the system attach the item to the list by setting the element number to -1.

### Method Start

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| driveObjectId | INT | INPUT | Optional: Identification number of the drive object (value = -1: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId) |
| hardwareId | HW_IO | INPUT | hardware id of the device |
| parameterCount | INT | INPUT | number of parameters to write |
| Start | BOOL | RETURN | TRUE: Command was started successfully FALSE: Command could not be started, there is an issue in the configuration |

Starts a write operation of parameters previously added to the dataset list via the `AddatasetItem` method.

### Method ReaddatasetItem

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| element_no | INT | INPUT | item index you want to read |
| ReaddatasetItem | LAcycCom_typeDriveDataset | RETURN | Returns the dataset for the element number you requested |

Returns the dataset for a given element number. Useful to check, if the parameter was added to the list or to check, if the correct item was overwritten manually.

### Method DeleteList

Deletes the internal list of items. This method does not have a interface.


## Class LAcycCom_classWriteDriveSingleParams

### Method Start

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| driveObjectId | INT | INPUT | Optional: Identification number of the drive object (value = -1: driveObjectId is not used, i.e. the corresponding drive object is only addressed via the hardwareId) |
| hardwareId | HW_IO | INPUT | hardware id of the device |
| parameterNumber | INT | INPUT | number of parameter to write |
| index | UINT | INPUT | Index of the parameter |
| value | REAL | INPUT | value that shall be written, formatted as 32-bit REAL |
| DwValue | DWORD | INPUT | value that shall be written, formatted as DWORD |
| Start | BOOL | RETURN | TRUE: Command was started successfully FALSE: Command could not be started, there is an issue in the configuration |

Starts the write operation.

If you would like to write the value as DWORD, please keep the real value at REAL#0.0 (default value), otherwise the real value will be written.

For compability reasons, there are two more methods with the name `start` in this class. In one instance, the input `driveObjectId` is set as an UINT for legacy users to avoid breaking existing applications. The second instance drops the input `driveObjectId` completely, if you are using the hardware id of the submodule.

## Structured datatypes

### Type LAcycCom_typeDriveDataset

| Symbol | Datatype | Default value | Explanation |
| --- | --- | --- | --- |
| maxNoOfRequests | UINT | - | Maximum number of requests in use in request buffer |
| parameterNumber | UInt   | - | Number of the parameter |
| index           | UInt   | - | Index of the parameter |
| Rvalue          | REAL   | - | parameter value formatted as 32-bit floating point value (REAL) |
| DWvalue         | DWORD  | - | parameter value formatted as DWORD |
| errorValue      | BYTE   | BYTE#2#11111111 | error value during operation |

### Type LAcycCom_ooptypeDriveDiagnostics

| Symbol | Datatype | Default value | Explanation |
| --- | --- | --- | --- |
| status              | WORD | - | Status identifier when error occurred |
| subfunctionStatus   | WORD | - | Block status or error information |
| stateNumber         | LAcycCom_ReadWriteStatus | - | Internal state when error occurred |
| driveObjectId       | USINT | - | Identification number of the drive object |
| hardwareId          | HW_IO                    | HW_IO#default| Hardware identifier of the hardware module |
| parameterCount      | INT | - | Total amount of parameters |
| firstParameterError | INT                      | -1 | Number of parameter at which the error occurred (-1: no parameter with error) |
| errorValue          | BYTE                     | BYTE#2#11111111 | Error number (16#FF: no error; else: see error list) |

## Enumerations 

### Type LAcycComstateDef

Values:

BUSY
IDLE
DONE
ABORTED
ERROR
