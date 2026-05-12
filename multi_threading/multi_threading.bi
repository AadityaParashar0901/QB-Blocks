Declare Library "./multi_threading"
    Function invokeWorker (ByVal id As Long)
    Sub joinThread (ByVal id As Long)
    Sub exitThread
    Sub lockThread (ByVal id As Long)
    Sub unlockThread (ByVal id As Long)
End Declare
Type ChunkWorker ' for multithreading
    As Long id
    As _Unsigned Long ChunksX(0 To MaxJobsPerThread), ChunksZ(0 To MaxJobsPerThread)
    As _Unsigned Long Jobs
    As _Unsigned _Byte RingId, CanChangeState, Buffer
    As _Unsigned _Byte Start, Finished, Freeze, Quit
    As Single TimeTook
    As Single ST
End Type
Dim Shared Workers(1 To MaxThreads) As ChunkWorker
Type ChunkWorkerStatus
    As _Unsigned _Byte State, RingId
End Type
Dim Shared WorkerStatus(1 To MaxThreads) As ChunkWorkerStatus
Dim As _Unsigned _Byte JobsPerThread: JobsPerThread = 1
