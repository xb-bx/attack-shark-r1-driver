#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include <stdlib.h>
#include <assert.h>
#include <sys/types.h>
#define VID 0x1d57
#define PID 0xfa60
#define INTERFACE 2
#define eprintf(args...) fprintf(stderr, args)

enum PollingRate {
    Hz125   = 0xf708,
    Hz250   = 0xfb04,
    Hz500   = 0xfd02,
    Hz1000  = 0xfe01,
};

void
usage() {
    printf("attack-shark-r1-drv <command> <args>\n");
    printf("commands:\n");
    printf("\tcharge\n");
    printf("\tset\tpoll\t\t(125/250/500/1000)\n");
}
int
set_polling_rate(libusb_device_handle *dev_handle, int polling_rate) {
    unsigned char payload[9] = {0x6, 0x9, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0};;
    *((u_int16_t*)&payload[3]) = (u_int16_t)polling_rate;
    int n = libusb_control_transfer(dev_handle, 0x21, 0x9, 0x306, 2, payload, 9, 0);
    return n;
}
int
set(int argc, char **argv, libusb_device_handle *dev_handle, int packet_id) {
    if(argc < 2) {
        usage(); 
        return -1;
    }
    if(strcmp("poll", argv[0]) == 0) {
        int polling_rate = 0;
        if(strcmp("125", argv[1]) == 0) {
            polling_rate = Hz125;
        } else if(strcmp("250", argv[1]) == 0) {
            polling_rate = Hz250;
        } else if(strcmp("500", argv[1]) == 0) {
            polling_rate = Hz500;
        } else if(strcmp("1000", argv[1]) == 0) {
            polling_rate = Hz1000;
        } else {
            eprintf("Unsupported polling rate\n");
            return -1;
        }
        return set_polling_rate(dev_handle, polling_rate);
    } else {
        eprintf("Unknown\n");
        return -1;
    }
}
int 
main(int argc, char **argv) {
    if(argc < 2) {
        usage();
        return 0;
    }
    libusb_context *ctx = NULL;
    int ret = libusb_init(&ctx);
    if (ret != LIBUSB_SUCCESS) {
        printf("ERROR: %i %i\n", ret, __LINE__);
        return 0;
    }
    libusb_device *needed_device = NULL;
    libusb_device **list = NULL;
    int count = libusb_get_device_list(ctx, &list);
    for(int i = 0; i < count; i ++) {
        struct libusb_device_descriptor desc;
        libusb_get_device_descriptor(list[i], &desc);
        if(desc.idVendor == VID && (desc.idProduct == PID || desc.idProduct == PID)) {
            needed_device = list[i];
        }
    }
    if(needed_device == NULL) {
        eprintf("NOT FOUND\n");
        return 1;
    }
    libusb_device_handle *dev_handle = NULL;
    ret = libusb_open(needed_device, &dev_handle);
    if (ret != LIBUSB_SUCCESS) {
        eprintf("ERROR: %i %i %s\n", ret, __LINE__, libusb_error_name(ret));
        return 1;
    }
    int has_driver = libusb_kernel_driver_active(dev_handle, INTERFACE);
    if(has_driver) {
        ret = libusb_detach_kernel_driver(dev_handle, INTERFACE);
        if (ret != LIBUSB_SUCCESS) {
            eprintf("ERROR: %i %i %s\n", ret, __LINE__, libusb_error_name(ret));
            return 1;
        }
    }
    ret = libusb_claim_interface(dev_handle, INTERFACE);
    if (ret != LIBUSB_SUCCESS) {
        eprintf("ERROR: %i %i %s\n", ret, __LINE__, libusb_error_name(ret));
        return 1;
    }
    int res = 0;
    if(strcmp("charge", argv[1]) == 0) {
        unsigned char data[64] = {0};
        int transferred = 0;
        res = libusb_interrupt_transfer(dev_handle, 0x83, data, 64, &transferred, 0);
        printf("%i\n", data[4] * 10);
    } else if(strcmp("set", argv[1]) == 0) {
        res = set(argc-2, argv+2, dev_handle, 0);
        if(res >= 0) res = libusb_interrupt_transfer(dev_handle, 0x83, data, 64, &transferred, 0);
    } else {
        usage();
    }

    if (res < 0) {
        eprintf("ERROR: %i %s\n", res, libusb_error_name(res));
    }

    libusb_release_interface(dev_handle, INTERFACE);
    if(has_driver) {
        ret = libusb_attach_kernel_driver(dev_handle, INTERFACE);
        if (ret != LIBUSB_SUCCESS) {
            printf("ERROR: %i %i %s\n", ret, __LINE__, libusb_error_name(ret));
            return 1;
        }
    }
    if(res < 0) return 1;
    return 0;
}
