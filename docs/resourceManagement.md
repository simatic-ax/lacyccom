# Resource management

## Class OOPLAcycCom_ResourceManager

The resource management is handled by the `OOPLAcycCom_ResourceManager` class. It receives read/write requests for acyclic communication from the drive functions blocks. It stores the request and gives the communication blocks the authority to communicate with the drive. If there are multiple requests, the requests are stored and access is given one after the other. This avoids collision caused by multiple simultaneous requests to a single drive.

The resource manager can also be used to request resources for external acyclic data exchange. Simply call the methods for resource allocation before accessing and make sure to release the resource after finishing communication.

The class `OOPLAcycCom_ResourceManager` implements the interface `Resourcemanager`. A user may create their own version of the resource manager and implement this interface. Using the interface keeps compability with the drive function blocks. 

### Method execute

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| config | LAcycCom_typeResourceManagerConf | INPUT | configuration of the resource management |

This method needs to be called cyclically. It contains the main logic of the resource manager. The configuration of the resource manager is attached here.

### Method Reset

Resets the resource manager, e.g. after an error occured. Will also clear all current requests out of the buffer.

This Method has no interface.

### Method Allocate

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| hardwareId | HW_IO | INPUT | Hardware identifier of the hardware module |
| Allocate | INT | RETURN | Returns the allocated index |

Used to allocate a resource for the hardware id set at the input. Returns the allocated index for tracking the resource status in the following methods.

### Method GetResource

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| AllocatedIndex | INT | INPUT | Allocated index from allocate method |
| GetResource | LAcycCom_ResourceManagerRetval | RETURN | Returns the status of the index as enumeration |

Returns the state of the allocated request for communication.

### Method Release

| Symbol | Datatype | Type | Explanation |
| --- | --- | --- | --- |
| AllocatedIndex | INT | INPUT | Allocated index from allocate method |
| Release | LAcycCom_ResourceManagerRetval | RETURN | Returns the status of the release process |

Releases the ressource of the allocated index to free up the resource for the next request.

## Structured data types

### Type LAcycCom_typeResourceManagerConf

| Symbol | Datatype | Default value | Explanation |
| --- | --- | --- | --- |
| timeoutBufferLock       | TIME     | T#1s | Timeout for locking of complete request buffer, that means resource manager has no access |
| maxQueueTime       | TIME     | T#30s | Maximum waiting time of a request waiting in queue before releasing the element is enforced by resource manager |
| maxAssignedTime       | TIME     | T#1m | Maximum time a resource is assigned to a request |
| delayReleaseAfterReject       | TIME     | T#10s | Delay for releasing resource after it was rejected by resource manager |

### Type LAcycCom_typeResourceManagerDiag

| Symbol | Datatype | Default value | Explanation |
| --- | --- | --- | --- |
| maxNoOfRequests | UINT | - | Maximum number of requests in use in request buffer |
| curRuntime | TIME | - | Runtime of last call |
| maxRuntime | TIME | - | Maximum runtime of execute method |
| status | WORD | - | current status |

## Enumerations

### Type LAcycCom_ResourceManagerRetval

Values:

ERR_INVALID_BUF_INDEX
ERR_REQUEST_REJECTED
ERR_RESOURCE_RELEASED
STATUS_BUSY
STATUS_GET_RESOURCE
STATUS_EXECUTION_FINISHED
