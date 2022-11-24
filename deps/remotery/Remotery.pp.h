# 1 "deps/remotery/Remotery.h"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 420 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "deps/remotery/Remotery.h" 2
# 222 "deps/remotery/Remotery.h"
typedef unsigned int rmtBool;




typedef unsigned char rmtU8;
typedef unsigned short rmtU16;
typedef unsigned int rmtU32;
typedef unsigned long long rmtU64;


typedef char rmtS8;
typedef short rmtS16;
typedef int rmtS32;
typedef long long rmtS64;


typedef float rmtF32;
typedef double rmtF64;


typedef const char* rmtPStr;


typedef struct Msg_SampleTree rmtSampleTree;


typedef struct Sample rmtSample;


typedef struct Remotery Remotery;


struct rmtProperty;

typedef enum rmtSampleType
{
    RMT_SampleType_CPU,
    RMT_SampleType_CUDA,
    RMT_SampleType_D3D11,
    RMT_SampleType_D3D12,
    RMT_SampleType_OpenGL,
    RMT_SampleType_Metal,
    RMT_SampleType_Count,
} rmtSampleType;



typedef enum rmtError
{
    RMT_ERROR_NONE,
    RMT_ERROR_RECURSIVE_SAMPLE,
    RMT_ERROR_UNKNOWN,
    RMT_ERROR_INVALID_INPUT,
    RMT_ERROR_RESOURCE_CREATE_FAIL,
    RMT_ERROR_RESOURCE_ACCESS_FAIL,
    RMT_ERROR_TIMEOUT,


    RMT_ERROR_MALLOC_FAIL,
    RMT_ERROR_TLS_ALLOC_FAIL,
    RMT_ERROR_VIRTUAL_MEMORY_BUFFER_FAIL,
    RMT_ERROR_CREATE_THREAD_FAIL,
    RMT_ERROR_OPEN_THREAD_HANDLE_FAIL,


    RMT_ERROR_SOCKET_INVALID_POLL,
    RMT_ERROR_SOCKET_SELECT_FAIL,
    RMT_ERROR_SOCKET_POLL_ERRORS,
    RMT_ERROR_SOCKET_SEND_FAIL,
    RMT_ERROR_SOCKET_RECV_NO_DATA,
    RMT_ERROR_SOCKET_RECV_TIMEOUT,
    RMT_ERROR_SOCKET_RECV_FAILED,


    RMT_ERROR_WEBSOCKET_HANDSHAKE_NOT_GET,
    RMT_ERROR_WEBSOCKET_HANDSHAKE_NO_VERSION,
    RMT_ERROR_WEBSOCKET_HANDSHAKE_BAD_VERSION,
    RMT_ERROR_WEBSOCKET_HANDSHAKE_NO_HOST,
    RMT_ERROR_WEBSOCKET_HANDSHAKE_BAD_HOST,
    RMT_ERROR_WEBSOCKET_HANDSHAKE_NO_KEY,
    RMT_ERROR_WEBSOCKET_HANDSHAKE_BAD_KEY,
    RMT_ERROR_WEBSOCKET_HANDSHAKE_STRING_FAIL,
    RMT_ERROR_WEBSOCKET_DISCONNECTED,
    RMT_ERROR_WEBSOCKET_BAD_FRAME_HEADER,
    RMT_ERROR_WEBSOCKET_BAD_FRAME_HEADER_SIZE,
    RMT_ERROR_WEBSOCKET_BAD_FRAME_HEADER_MASK,
    RMT_ERROR_WEBSOCKET_RECEIVE_TIMEOUT,

    RMT_ERROR_REMOTERY_NOT_CREATED,
    RMT_ERROR_SEND_ON_INCOMPLETE_PROFILE,


    RMT_ERROR_CUDA_DEINITIALIZED,
    RMT_ERROR_CUDA_NOT_INITIALIZED,
    RMT_ERROR_CUDA_INVALID_CONTEXT,
    RMT_ERROR_CUDA_INVALID_VALUE,
    RMT_ERROR_CUDA_INVALID_HANDLE,
    RMT_ERROR_CUDA_OUT_OF_MEMORY,
    RMT_ERROR_ERROR_NOT_READY,


    RMT_ERROR_D3D11_FAILED_TO_CREATE_QUERY,


    RMT_ERROR_OPENGL_ERROR,

    RMT_ERROR_CUDA_UNKNOWN,
} rmtError;



        rmtPStr rmt_GetLastErrorMessage();
# 343 "deps/remotery/Remotery.h"
typedef void* (*rmtMallocPtr)(void* mm_context, rmtU32 size);
typedef void* (*rmtReallocPtr)(void* mm_context, void* ptr, rmtU32 size);
typedef void (*rmtFreePtr)(void* mm_context, void* ptr);
typedef void (*rmtInputHandlerPtr)(const char* text, void* context);
typedef void (*rmtSampleTreeHandlerPtr)(void* cbk_context, rmtSampleTree* sample_tree);
typedef void (*rmtPropertyHandlerPtr)(void* cbk_context, struct rmtProperty* root);


typedef struct rmtSettings
{

    rmtU16 port;




    rmtBool reuse_open_port;





    rmtBool limit_connections_to_localhost;





    rmtBool enableThreadSampler;



    rmtU32 msSleepBetweenServerUpdates;



    rmtU32 messageQueueSizeInBytes;




    rmtU32 maxNbMessagesPerUpdate;


    rmtMallocPtr malloc;
    rmtReallocPtr realloc;
    rmtFreePtr free;
    void* mm_context;


    rmtInputHandlerPtr input_handler;


    rmtSampleTreeHandlerPtr sampletree_handler;
    void* sampletree_context;


    rmtPropertyHandlerPtr snapshot_callback;
    void* snapshot_context;


    void* input_handler_context;

    rmtPStr logPath;
} rmtSettings;
# 479 "deps/remotery/Remotery.h"
typedef struct rmtCUDABind
{

    void* context;






    void* CtxSetCurrent;
    void* CtxGetCurrent;
    void* EventCreate;
    void* EventDestroy;
    void* EventRecord;
    void* EventQuery;
    void* EventElapsedTime;

} rmtCUDABind;
# 534 "deps/remotery/Remotery.h"
typedef struct rmtD3D12Bind
{

    void* device;


    void* queue;

} rmtD3D12Bind;
# 611 "deps/remotery/Remotery.h"
typedef enum
{
    RMT_PropertyFlags_NoFlags = 0,


    RMT_PropertyFlags_FrameReset = 1,
} rmtPropertyFlags;


typedef enum
{
    RMT_PropertyType_rmtGroup,
    RMT_PropertyType_rmtBool,
    RMT_PropertyType_rmtS32,
    RMT_PropertyType_rmtU32,
    RMT_PropertyType_rmtF32,
    RMT_PropertyType_rmtS64,
    RMT_PropertyType_rmtU64,
    RMT_PropertyType_rmtF64,
} rmtPropertyType;


typedef union rmtPropertyValue
{
# 647 "deps/remotery/Remotery.h"
    rmtBool Bool;
    rmtS32 S32;
    rmtU32 U32;
    rmtF32 F32;
    rmtS64 S64;
    rmtU64 U64;
    rmtF64 F64;
} rmtPropertyValue;




typedef struct rmtProperty
{

    rmtBool initialised;


    rmtPropertyType type;
    rmtPropertyFlags flags;


    rmtPropertyValue value;


    rmtPropertyValue lastFrameValue;


    rmtPropertyValue prevValue;
    rmtU32 prevValueFrame;


    const char* name;
    const char* description;


    rmtPropertyValue defaultValue;


    struct rmtProperty* parent;


    struct rmtProperty* firstChild;
    struct rmtProperty* lastChild;
    struct rmtProperty* nextSibling;


    rmtU32 nameHash;


    rmtU32 uniqueID;
} rmtProperty;
# 788 "deps/remotery/Remotery.h"
        void _rmt_PropertySetValue(rmtProperty* property);
        void _rmt_PropertyAddValue(rmtProperty* property, rmtPropertyValue add_value);
        rmtError _rmt_PropertySnapshotAll();
        void _rmt_PropertyFrameResetAll();
        rmtU32 _rmt_HashString32(const char* s, int len, rmtU32 seed);
# 804 "deps/remotery/Remotery.h"
typedef enum rmtSampleFlags
{

    RMTSF_None = 0,


    RMTSF_Aggregate = 1,


    RMTSF_Recursive = 2,



    RMTSF_Root = 4,






    RMTSF_SendOnClose = 8,
} rmtSampleFlags;


typedef struct rmtSampleIterator
{

    rmtSample* sample;

    rmtSample* initial;
} rmtSampleIterator;
# 876 "deps/remotery/Remotery.h"
typedef struct rmtPropertyIterator
{

    rmtProperty* property;

    rmtProperty* initial;
} rmtPropertyIterator;
# 1023 "deps/remotery/Remotery.h"
        rmtSettings* _rmt_Settings( void );
        enum rmtError _rmt_CreateGlobalInstance(Remotery** remotery);
        void _rmt_DestroyGlobalInstance(Remotery* remotery);
        void _rmt_SetGlobalInstance(Remotery* remotery);
        Remotery* _rmt_GetGlobalInstance(void);
        void _rmt_SetCurrentThreadName(rmtPStr thread_name);
        void _rmt_LogText(rmtPStr text);
        void _rmt_BeginCPUSample(rmtPStr name, rmtU32 flags, rmtU32* hash_cache);
        void _rmt_EndCPUSample(void);
        rmtError _rmt_MarkFrame(void);
# 1067 "deps/remotery/Remotery.h"
        void _rmt_IterateChildren(rmtSampleIterator* iter, rmtSample* sample);
        rmtBool _rmt_IterateNext(rmtSampleIterator* iter);


        const char* _rmt_SampleTreeGetThreadName(rmtSampleTree* sample_tree);
        rmtSample* _rmt_SampleTreeGetRootSample(rmtSampleTree* sample_tree);


        const char* _rmt_SampleGetName(rmtSample* sample);
        rmtU32 _rmt_SampleGetNameHash(rmtSample* sample);
        rmtU32 _rmt_SampleGetCallCount(rmtSample* sample);
        rmtU64 _rmt_SampleGetStart(rmtSample* sample);
        rmtU64 _rmt_SampleGetTime(rmtSample* sample);
        rmtU64 _rmt_SampleGetSelfTime(rmtSample* sample);
        void _rmt_SampleGetColour(rmtSample* sample, rmtU8* r, rmtU8* g, rmtU8* b);
        rmtSampleType _rmt_SampleGetType(rmtSample* sample);


        void _rmt_PropertyIterateChildren(rmtPropertyIterator* iter, rmtProperty* property);
        rmtBool _rmt_PropertyIterateNext(rmtPropertyIterator* iter);


        rmtPropertyType _rmt_PropertyGetType(rmtProperty* property);
        rmtU32 _rmt_PropertyGetNameHash(rmtProperty* property);
        const char* _rmt_PropertyGetName(rmtProperty* property);
        const char* _rmt_PropertyGetDescription(rmtProperty* property);
        rmtPropertyValue _rmt_PropertyGetValue(rmtProperty* property);
