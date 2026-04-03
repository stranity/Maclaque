#ifndef CHID_ACCELEROMETER_H
#define CHID_ACCELEROMETER_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Accelerometer sample in g-force units
typedef struct {
    double x;
    double y;
    double z;
} AccelSample;

/// Opaque accelerometer handle
typedef struct CHIDAccelerometer CHIDAccelerometer;

/// Callback type for receiving accelerometer samples
typedef void (*AccelCallback)(AccelSample sample, void *context);

/// Create and open the accelerometer. Returns NULL on failure.
/// Requires root privileges (sudo).
CHIDAccelerometer *accelerometer_open(void);

/// Register a callback for new samples. Thread-safe.
void accelerometer_set_callback(CHIDAccelerometer *accel, AccelCallback cb, void *context);

/// Start the run loop on the current thread (blocks).
/// Call from a dedicated thread.
void accelerometer_run(CHIDAccelerometer *accel);

/// Stop the run loop (can be called from any thread).
void accelerometer_stop(CHIDAccelerometer *accel);

/// Read the latest sample. Returns false if no new sample available.
bool accelerometer_read(CHIDAccelerometer *accel, AccelSample *out);

/// Close and release all resources.
void accelerometer_close(CHIDAccelerometer *accel);

#ifdef __cplusplus
}
#endif

#endif /* CHID_ACCELEROMETER_H */
