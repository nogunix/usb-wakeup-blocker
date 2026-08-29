/*
 * usb-wakeup-helper — macOS IOKit helper for USB remote wakeup control
 *
 * MIT License
 * Copyright (c) 2025 Masaharu Noguchi
 *
 * Build: cc -framework IOKit -framework CoreFoundation -o usb-wakeup-helper usb-wakeup-helper.c
 *
 * Usage:
 *   usb-wakeup-helper list
 *   usb-wakeup-helper get    <locationID>
 *   usb-wakeup-helper set    <locationID> disabled|enabled
 *   usb-wakeup-helper daemon <locationID> [<locationID> ...]
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include <syslog.h>
#include <AvailabilityMacros.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOCFPlugIn.h>
#include <IOKit/IOMessage.h>
#include <IOKit/usb/IOUSBLib.h>
#include <IOKit/pwr_mgt/IOPMLib.h>
#include <CoreFoundation/CoreFoundation.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED < 120000
#define kIOMainPortDefault kIOMasterPortDefault
#endif

#define MAX_DEVICES 64

static io_connect_t g_root_port;

static uint32_t get_int_property(io_service_t service, CFStringRef key) {
    CFNumberRef num = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
    if (!num) return 0;
    uint32_t val = 0;
    CFNumberGetValue(num, kCFNumberSInt32Type, &val);
    CFRelease(num);
    return val;
}

static char *get_string_property(io_service_t service, CFStringRef key) {
    CFStringRef str = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
    if (!str) return NULL;
    CFIndex len = CFStringGetLength(str);
    CFIndex max = CFStringGetMaximumSizeForEncoding(len, kCFStringEncodingUTF8) + 1;
    char *buf = malloc(max);
    if (buf && !CFStringGetCString(str, buf, max, kCFStringEncodingUTF8)) {
        free(buf); buf = NULL;
    }
    CFRelease(str);
    return buf;
}

static io_service_t find_device_by_location(uint32_t location_id) {
    io_iterator_t iter;
    io_service_t service;

    CFMutableDictionaryRef match = IOServiceMatching("IOUSBHostDevice");
    if (!match) return 0;

    if (IOServiceGetMatchingServices(kIOMainPortDefault, match, &iter) != KERN_SUCCESS)
        return 0;

    while ((service = IOIteratorNext(iter)) != 0) {
        if (get_int_property(service, CFSTR("locationID")) == location_id) {
            IOObjectRelease(iter);
            return service;
        }
        IOObjectRelease(service);
    }
    IOObjectRelease(iter);
    return 0;
}

/* Send CLEAR_FEATURE(DEVICE_REMOTE_WAKEUP) or SET_FEATURE via USB control transfer */
static int usb_set_remote_wakeup(uint32_t location_id, int enable) {
    io_service_t service = find_device_by_location(location_id);
    if (!service) return -1;

    /* Try IORegistryEntry property first (works on Intel Macs) */
    CFBooleanRef bval = enable ? kCFBooleanTrue : kCFBooleanFalse;
    kern_return_t kr = IORegistryEntrySetCFProperty(service,
        CFSTR("kUSBRemoteWakeOverride"), bval);
    if (kr == KERN_SUCCESS) {
        IOObjectRelease(service);
        return 0;
    }

    /* Fallback: USB control transfer via IOUSBDeviceInterface */
    IOCFPlugInInterface **plugIn = NULL;
    SInt32 score;
    kr = IOCreatePlugInInterfaceForService(service,
        kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
        &plugIn, &score);
    IOObjectRelease(service);
    if (kr != KERN_SUCCESS || !plugIn) return -2;

    IOUSBDeviceInterface **dev = NULL;
    HRESULT res = (*plugIn)->QueryInterface(plugIn,
        CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID *)&dev);
    (*plugIn)->Release(plugIn);
    if (res || !dev) return -3;

    kr = (*dev)->USBDeviceOpen(dev);
    if (kr == kIOReturnExclusiveAccess)
        kr = (*dev)->USBDeviceOpenSeize(dev);
    if (kr != KERN_SUCCESS) {
        (*dev)->Release(dev);
        return -4;
    }

    IOUSBDevRequest request;
    request.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBStandard, kUSBDevice);
    request.bRequest = enable ? kUSBRqSetFeature : kUSBRqClearFeature;
    request.wValue = kUSBFeatureDeviceRemoteWakeup;
    request.wIndex = 0;
    request.wLength = 0;
    request.pData = NULL;

    kr = (*dev)->DeviceRequest(dev, &request);
    (*dev)->USBDeviceClose(dev);
    (*dev)->Release(dev);

    return (kr == KERN_SUCCESS) ? 0 : -5;
}

/* ===== Sleep notification callback for daemon mode ===== */

typedef struct {
    uint32_t *ids;
    int count;
} daemon_ctx_t;

static void sleep_callback(void *refcon, io_service_t service,
                            natural_t msg_type, void *msg_arg) {
    (void)service;
    daemon_ctx_t *ctx = (daemon_ctx_t *)refcon;

    switch (msg_type) {
    case kIOMessageCanSystemSleep:
        IOAllowPowerChange(g_root_port, (long)msg_arg);
        break;

    case kIOMessageSystemWillSleep:
        for (int i = 0; i < ctx->count; i++) {
            int rc = usb_set_remote_wakeup(ctx->ids[i], 0);
            syslog(LOG_INFO, "usb-wakeup-helper: pre-sleep disable 0x%08x → %s",
                   ctx->ids[i], rc == 0 ? "ok" : "failed");
        }
        IOAllowPowerChange(g_root_port, (long)msg_arg);
        break;

    case kIOMessageSystemHasPoweredOn:
        syslog(LOG_INFO, "usb-wakeup-helper: system woke up");
        break;
    }
}

static int cmd_daemon(int count, uint32_t *ids) {
    daemon_ctx_t ctx = { .ids = ids, .count = count };
    IONotificationPortRef notify_port;
    io_object_t notifier;

    g_root_port = IORegisterForSystemPower(&ctx, &notify_port,
                                           sleep_callback, &notifier);
    if (g_root_port == 0) {
        fprintf(stderr, "IORegisterForSystemPower failed\n");
        return 1;
    }

    CFRunLoopAddSource(CFRunLoopGetCurrent(),
        IONotificationPortGetRunLoopSource(notify_port),
        kCFRunLoopCommonModes);

    syslog(LOG_INFO, "usb-wakeup-helper: daemon started, watching %d device(s)", count);
    for (int i = 0; i < count; i++)
        syslog(LOG_INFO, "usb-wakeup-helper:   target 0x%08x", ids[i]);

    /* Also disable immediately at startup */
    for (int i = 0; i < count; i++)
        usb_set_remote_wakeup(ids[i], 0);

    CFRunLoopRun();

    IODeregisterForSystemPower(&notifier);
    IOServiceClose(g_root_port);
    IONotificationPortDestroy(notify_port);
    return 0;
}

/* ===== One-shot commands ===== */

static int cmd_list(void) {
    io_iterator_t iter;
    io_service_t service;

    CFMutableDictionaryRef match = IOServiceMatching("IOUSBHostDevice");
    if (!match) return 1;
    if (IOServiceGetMatchingServices(kIOMainPortDefault, match, &iter) != KERN_SUCCESS)
        return 1;

    while ((service = IOIteratorNext(iter)) != 0) {
        uint32_t loc = get_int_property(service, CFSTR("locationID"));
        char *product = get_string_property(service, CFSTR("USB Product Name"));
        char *vendor = get_string_property(service, CFSTR("USB Vendor Name"));

        printf("%u\t%s\t%s\n", loc,
               product ? product : "(unknown)",
               vendor ? vendor : "(unknown)");

        free(product);
        free(vendor);
        IOObjectRelease(service);
    }
    IOObjectRelease(iter);
    return 0;
}

static int cmd_get(uint32_t location_id) {
    io_service_t service = find_device_by_location(location_id);
    if (!service) { fprintf(stderr, "Device not found: 0x%x\n", location_id); return 1; }

    CFTypeRef val = IORegistryEntryCreateCFProperty(service,
        CFSTR("kUSBRemoteWakeOverride"), kCFAllocatorDefault, 0);
    IOObjectRelease(service);

    if (!val) { printf("default\n"); return 0; }
    if (CFGetTypeID(val) == CFBooleanGetTypeID())
        printf("%s\n", CFBooleanGetValue(val) ? "enabled" : "disabled");
    else
        printf("default\n");
    CFRelease(val);
    return 0;
}

static int cmd_set(uint32_t location_id, int enable) {
    int rc = usb_set_remote_wakeup(location_id, enable);
    if (rc != 0) {
        fprintf(stderr, "Failed to set wakeup (rc=%d)\n", rc);
        return 1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 2) goto usage;

    if (strcmp(argv[1], "list") == 0)
        return cmd_list();

    if (strcmp(argv[1], "get") == 0 && argc >= 3)
        return cmd_get((uint32_t)strtoul(argv[2], NULL, 0));

    if (strcmp(argv[1], "set") == 0 && argc >= 4) {
        int enable;
        if (strcmp(argv[3], "enabled") == 0) enable = 1;
        else if (strcmp(argv[3], "disabled") == 0) enable = 0;
        else { fprintf(stderr, "Invalid value: %s\n", argv[3]); return 1; }
        return cmd_set((uint32_t)strtoul(argv[2], NULL, 0), enable);
    }

    if (strcmp(argv[1], "daemon") == 0 && argc >= 3) {
        int count = argc - 2;
        if (count > MAX_DEVICES) count = MAX_DEVICES;
        uint32_t ids[MAX_DEVICES];
        for (int i = 0; i < count; i++)
            ids[i] = (uint32_t)strtoul(argv[2 + i], NULL, 0);
        return cmd_daemon(count, ids);
    }

usage:
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "  %s list\n", argv[0]);
    fprintf(stderr, "  %s get    <locationID>\n", argv[0]);
    fprintf(stderr, "  %s set    <locationID> disabled|enabled\n", argv[0]);
    fprintf(stderr, "  %s daemon <locationID> [<locationID> ...]\n", argv[0]);
    return 1;
}
