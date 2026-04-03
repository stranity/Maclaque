#include "include/CHIDAccelerometer.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDDevice.h>
#include <CoreFoundation/CoreFoundation.h>

// ── Constants ──────────────────────────────────────────────────────────
#define SPU_DRIVER_CLASS   "AppleSPUHIDDriver"
#define SPU_DEVICE_CLASS   "AppleSPUHIDDevice"
#define ACCEL_USAGE_PAGE   0xFF00   // Apple vendor HID page
#define ACCEL_USAGE        9        // Linear acceleration (user motion, no gravity)
#define IMU_REPORT_LEN     22
#define IMU_DATA_OFFSET    6
#define Q16_SCALE          65536.0
#define REPORT_BUF_SIZE    4096

// ── Struct ─────────────────────────────────────────────────────────────
struct CHIDAccelerometer {
    IOHIDDeviceRef device;
    CFRunLoopRef   runLoop;
    uint8_t        reportBuffer[REPORT_BUF_SIZE];

    // Latest raw values (updated from callback)
    int32_t  rawX, rawY, rawZ;
    bool     hasNewSample;
    pthread_mutex_t lock;

    // User callback
    AccelCallback callback;
    void         *callbackContext;

    bool running;
};

// ── Helpers ────────────────────────────────────────────────────────────
static CFNumberRef cfNum32(int32_t val) {
    return CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &val);
}

static int64_t propInt(io_service_t svc, const char *key) {
    CFStringRef cfKey = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
    CFTypeRef val = IORegistryEntryCreateCFProperty(svc, cfKey, kCFAllocatorDefault, 0);
    CFRelease(cfKey);
    if (!val) return -1;

    int64_t result = -1;
    if (CFGetTypeID(val) == CFNumberGetTypeID()) {
        CFNumberGetValue((CFNumberRef)val, kCFNumberSInt64Type, &result);
    }
    CFRelease(val);
    return result;
}

// ── Wake SPU drivers ───────────────────────────────────────────────────
static void wake_spu_drivers(void) {
    CFMutableDictionaryRef matching = IOServiceMatching(SPU_DRIVER_CLASS);
    if (!matching) return;

    io_iterator_t it = 0;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &it);
    if (kr != KERN_SUCCESS) return;

    io_service_t svc;
    while ((svc = IOIteratorNext(it)) != IO_OBJECT_NULL) {
        CFNumberRef one = cfNum32(1);
        CFNumberRef interval = cfNum32(1000); // 1000 µs = 1 ms

        IORegistryEntrySetCFProperty(svc, CFSTR("SensorPropertyReportingState"), one);
        IORegistryEntrySetCFProperty(svc, CFSTR("SensorPropertyPowerState"), one);
        IORegistryEntrySetCFProperty(svc, CFSTR("ReportInterval"), interval);

        CFRelease(one);
        CFRelease(interval);
        IOObjectRelease(svc);
    }
    IOObjectRelease(it);
}

// ── HID report callback ───────────────────────────────────────────────
static int report_count = 0;

static void report_callback(void *context, IOReturn result, void *sender,
                            IOHIDReportType type, uint32_t reportID,
                            uint8_t *report, CFIndex reportLength) {
    CHIDAccelerometer *accel = (CHIDAccelerometer *)context;

    report_count++;
    // Log every 500th report to show data is flowing
    if (report_count <= 3 || report_count % 500 == 0) {
        fprintf(stderr, "[CHIDAccelerometer] Report #%d: len=%ld\n",
                report_count, (long)reportLength);
    }

    if (reportLength != IMU_REPORT_LEN) return;

    int32_t x, y, z;
    memcpy(&x, report + IMU_DATA_OFFSET,     4);
    memcpy(&y, report + IMU_DATA_OFFSET + 4,  4);
    memcpy(&z, report + IMU_DATA_OFFSET + 8,  4);

    pthread_mutex_lock(&accel->lock);
    accel->rawX = x;
    accel->rawY = y;
    accel->rawZ = z;
    accel->hasNewSample = true;
    pthread_mutex_unlock(&accel->lock);

    // Fire user callback if set
    if (accel->callback) {
        AccelSample sample = {
            .x = x / Q16_SCALE,
            .y = y / Q16_SCALE,
            .z = z / Q16_SCALE
        };
        accel->callback(sample, accel->callbackContext);
    }
}

// ── Find accelerometer HID device ─────────────────────────────────────
static IOHIDDeviceRef find_accelerometer(void) {
    CFMutableDictionaryRef matching = IOServiceMatching(SPU_DEVICE_CLASS);
    if (!matching) return NULL;

    io_iterator_t it = 0;
    kern_return_t kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &it);
    if (kr != KERN_SUCCESS) return NULL;

    IOHIDDeviceRef found = NULL;
    io_service_t svc;
    int count = 0;
    while ((svc = IOIteratorNext(it)) != IO_OBJECT_NULL) {
        int64_t usagePage = propInt(svc, "PrimaryUsagePage");
        int64_t usage     = propInt(svc, "PrimaryUsage");
        fprintf(stderr, "[CHIDAccelerometer] Device %d: UsagePage=0x%llX Usage=%lld\n",
                count++, usagePage, usage);

        if (usagePage == ACCEL_USAGE_PAGE && usage == ACCEL_USAGE) {
            found = IOHIDDeviceCreate(kCFAllocatorDefault, svc);
            fprintf(stderr, "[CHIDAccelerometer] Found accelerometer!\n");
            IOObjectRelease(svc);
            break;
        }
        IOObjectRelease(svc);
    }
    IOObjectRelease(it);
    return found;
}

// ── Public API ─────────────────────────────────────────────────────────

CHIDAccelerometer *accelerometer_open(void) {
    // Wake SPU drivers first
    wake_spu_drivers();

    // Find accelerometer device
    IOHIDDeviceRef device = find_accelerometer();
    if (!device) {
        fprintf(stderr, "[CHIDAccelerometer] Accelerometer not found. Apple Silicon M1+ required.\n");
        return NULL;
    }

    IOReturn ret = IOHIDDeviceOpen(device, 0);
    if (ret != kIOReturnSuccess) {
        fprintf(stderr, "[CHIDAccelerometer] Failed to open device (error 0x%x). Run with sudo.\n", ret);
        CFRelease(device);
        return NULL;
    }

    CHIDAccelerometer *accel = calloc(1, sizeof(CHIDAccelerometer));
    accel->device = device;
    accel->hasNewSample = false;
    accel->running = false;
    accel->callback = NULL;
    accel->callbackContext = NULL;
    pthread_mutex_init(&accel->lock, NULL);

    // Register input report callback
    IOHIDDeviceRegisterInputReportCallback(
        device,
        accel->reportBuffer,
        REPORT_BUF_SIZE,
        report_callback,
        accel
    );

    return accel;
}

void accelerometer_set_callback(CHIDAccelerometer *accel, AccelCallback cb, void *context) {
    if (!accel) return;
    accel->callback = cb;
    accel->callbackContext = context;
}

static void keepalive_timer_callback(CFRunLoopTimerRef timer, void *info) {
    (void)timer;
    // Re-poke the SPU drivers to keep sensor streaming
    wake_spu_drivers();
}

void accelerometer_run(CHIDAccelerometer *accel) {
    if (!accel || !accel->device) return;

    accel->runLoop = CFRunLoopGetCurrent();
    IOHIDDeviceScheduleWithRunLoop(accel->device, accel->runLoop, kCFRunLoopDefaultMode);
    accel->running = true;

    // Create a repeating timer to keep the sensor alive (every 0.5s)
    CFRunLoopTimerRef timer = CFRunLoopTimerCreate(
        kCFAllocatorDefault,
        CFAbsoluteTimeGetCurrent() + 0.5,  // first fire
        0.5,                                // interval
        0, 0,
        keepalive_timer_callback,
        NULL
    );
    CFRunLoopAddTimer(accel->runLoop, timer, kCFRunLoopDefaultMode);

    while (accel->running) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.1, true);
    }

    CFRunLoopTimerInvalidate(timer);
    CFRelease(timer);
}

void accelerometer_stop(CHIDAccelerometer *accel) {
    if (!accel) return;
    accel->running = false;
    if (accel->runLoop) {
        CFRunLoopStop(accel->runLoop);
    }
}

bool accelerometer_read(CHIDAccelerometer *accel, AccelSample *out) {
    if (!accel || !out) return false;

    pthread_mutex_lock(&accel->lock);
    if (!accel->hasNewSample) {
        pthread_mutex_unlock(&accel->lock);
        return false;
    }
    out->x = accel->rawX / Q16_SCALE;
    out->y = accel->rawY / Q16_SCALE;
    out->z = accel->rawZ / Q16_SCALE;
    accel->hasNewSample = false;
    pthread_mutex_unlock(&accel->lock);
    return true;
}

void accelerometer_close(CHIDAccelerometer *accel) {
    if (!accel) return;
    accelerometer_stop(accel);

    if (accel->device) {
        IOHIDDeviceUnscheduleFromRunLoop(accel->device, accel->runLoop, kCFRunLoopDefaultMode);
        IOHIDDeviceClose(accel->device, 0);
        CFRelease(accel->device);
    }
    pthread_mutex_destroy(&accel->lock);
    free(accel);
}
