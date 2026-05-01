#include "pthread.h"
#include <unistd.h>
#include <time.h>

#define RETRYCOUNT 5
static pthread_t thread[9];

typedef struct thread_data {
   int id;
} thread_data;

static bool threadRunning[] = {false,false,false,false,false,false,false,false,false,false};

static pthread_mutex_t mutex[9];

void SUB_WORKERTHREAD(int32*_SUB_WORKERTHREAD_LONG_ID);

void* RunWorker(void *arg){
    thread_data *tdata=(thread_data *)arg;
    int id = tdata->id;
    threadRunning[id] = true;
    SUB_WORKERTHREAD((int32*)&id);
}

int invokeWorker(int id){
    thread_data tdata;
    tdata.id = id;
    int retry_count = 0;
    if (!threadRunning[id]) {
        pthread_mutex_init(&mutex[id], NULL);
        while(pthread_create(&thread[id], NULL, RunWorker, (void *)&tdata))
        {
            if (retry_count++ > RETRYCOUNT){
                return threadRunning[id];
            }
            sleep(1);
        };
        int timeout_time = clock() * 1000 / CLOCKS_PER_SEC + 1000;
        do {} while (clock() * 1000 / CLOCKS_PER_SEC <= timeout_time && threadRunning[id] != true);
    }
    return threadRunning[id];
}

void joinThread(int id){
    pthread_join(thread[id],NULL);
    threadRunning[id] = false;
    pthread_mutex_destroy(&mutex[id]);
}

void exitThread(){
    pthread_exit(NULL);
}

void lockThread(int id){
    pthread_mutex_lock(&mutex[id]);
}

void unlockThread(int id){
    pthread_mutex_unlock(&mutex[id]);
}
