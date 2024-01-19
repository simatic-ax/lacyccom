NAMESPACE Simatic.Ax.LAcycCom
   TYPE LAcycCom_typeActiveRequest

                      :  STRUCT
      bufferIndex     : INT := -1;     // Index of buffer element
      maxAssignedTime : Time := T#1M;  // Maximum time a resource is assigned to a request
      END_STRUCT;

   END_TYPE

   TYPE LAcycCom_typeRequestBufferElement

                           :  STRUCT
      state                : BYTE := BYTE#2#00000000;  // State of the request. Bit 0: allocate new buffer element; Bit 1: buffer element is assigned; Bit 2: release buffer element; Bit 3: request rejected
      hardwareId           : HW_IO := HW_IO#default;   // Hardware identifier of the hardware module
      queueElementPrevious : INT := -1;                // Element in queue before this element
      queueElementNext     : INT := -1;                // Element in queue after this element
      queueTime            : Time := T#0MS;            // Time duration element is in queue
      END_STRUCT;

   END_TYPE

   TYPE LAcycCom_typeRequestBufferHeader

                        :  STRUCT
      lockBuffer        : BOOL := TRUE;                                // TRUE: Request buffer DB is locked by application
      nextFreeElement   : INT := -1;                                   // Next free request element in request buffer
      firstQueueElement : INT := -1;                                   // Index of oldest element existing in request buffer
      numberOfRequests  : INT := -1;                                   // Number of existing requests in request buffer not released yet
      activeRequests    : Array[0..19] of LAcycCom_typeActiveRequest;  // Currently enabled request elements
      END_STRUCT;

   END_TYPE

   TYPE LAcycCom_typeRequestBuffer

               :  STRUCT
      header   : LAcycCom_typeRequestBufferHeader;                                                                        // Request header
      elements : Array[0..LAcycComConstantsInt#LACYCCOM_BUFFER_ELEMENTS_UPPER_LIM] of LAcycCom_typeRequestBufferElement;  // Request elements
      END_STRUCT;

   END_TYPE

   TYPE LAcycCom_typeResourceManagerConf

                              :  STRUCT
      timeoutBufferLock       : Time := T#1S;   // Timeout for locking of complete request buffer, that means resource manager has no access
      maxQueueTime            : Time := T#30S;  // Maximum waiting time of a request waiting in queue before releasing the element is enforced by resource manager
      maxAssignedTime         : Time := T#1M;   // Maximum time a resource is assigned to a request
      delayReleaseAfterReject : Time := T#10S;  // Delay for releasing resource after it was rejected by resource manager
      END_STRUCT;

   END_TYPE

   TYPE LAcycCom_typeResourceManagerDiag

                      :  STRUCT
      maxNoOfRequests : UINT;    // Maximum number of requests in use in request buffer
      curRuntime      : Time;    // Runtime of last call
      maxRuntime      : Time;    // Maximum runtime of FB
      status          : WORD;    // Current status
      END_STRUCT;

      HW_IO : WORD (default:=WORD#0);

   END_TYPE

END_NAMESPACE

