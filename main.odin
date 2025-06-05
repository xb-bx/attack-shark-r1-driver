#+feature dynamic-literals
package attackshark
import "core:fmt"
import "core:strings"
import "core:os"
import "core:sys/posix"
import "core:mem"
import "core:slice"
import "core:c"
import "core:strconv"
import "core:path/filepath"
import "core:flags"
import "base:runtime"
import "libusb"
import "ini"
VID :: 0x1d57
PID :: 0xfa60
INTERFACE :: 2

open_mouse :: proc(ctx: libusb.Context) -> (dev_handle: libusb.Device_Handle, has_kern_driver: bool, err: libusb.Error) {
    dev: libusb.Device = nil
    devs_raw: [^]libusb.Device = nil 
    count := libusb.get_device_list(ctx, &devs_raw)
    devs := devs_raw[:count]
    for idev in devs {
        desc: libusb.Device_Descriptor = {}
        if libusb.get_device_descriptor(idev, &desc) != .SUCCESS do continue
        if desc.idProduct == PID && desc.idVendor == VID {
            dev = idev
            break
        }
    } 
    if dev == nil {
        return nil, has_kern_driver, .NO_DEVICE
    }
    dev_handle = nil
    libusb.open(dev, &dev_handle) or_return
    
    has_kern_driver = libusb.kernel_driver_active(dev_handle, INTERFACE) != .SUCCESS
    if has_kern_driver do libusb.detach_kernel_driver(dev_handle, INTERFACE)


    return dev_handle, has_kern_driver, .SUCCESS
}

PollingRate :: enum u16 {
    Hz125   = 0xf708,
    Hz250   = 0xfb04,
    Hz500   = 0xfd02,
    Hz1000  = 0xfe01,
}
ctrl_transfer :: proc (dev_handle: libusb.Device_Handle, reqType: u8, req: u8, value: u16, index: u16, data: []u8) -> libusb.Error {
    err := libusb.control_transfer(dev_handle, reqType, req, value, index, slice.as_ptr(data), u16(len(data)), 0)
    if int(err) >= 0 do return nil
    return err
}
interrupt_transfer :: proc(dev_handle: libusb.Device_Handle, endpoint: u8, buf: []u8) -> libusb.Error {
    t := i32(0)
    err := libusb.interrupt_transfer(dev_handle, endpoint, slice.as_ptr(buf), i32(len(buf)), &t, 0) 
    if int(err) >= 0 do return nil
    return err
}

set_times :: proc (dev_handle: libusb.Device_Handle, sleep_time: f64, deep_sleep: int, key_resp: int) -> libusb.Error {
    t := i32(0)
    for {
        payload := [?]u8{0x5, 0xf, 0x1, 0x0, 0x03 /*deep sleep 4bit higher*/, 0x18 /*0xF0 deep sleep 4 bit lower*/, 0x0, 0x0, 0xff, 0x4 /*sleep time (0.5 * value)*/, 0x2 /*key resp time (2 * value)*/, 0x1, 0x20 /*checksum*/, 0x0, 0x0};
        payload[4] = 0x03 | u8(deep_sleep & 0xF0)
        payload[5] = 0x08 | u8((deep_sleep & 0x0F) << 4)
        payload[9] = u8(int(sleep_time * 2))
        payload[10] = u8(key_resp / 2)
        payload[12] = ((u8(deep_sleep) & 0xF + (u8(deep_sleep & 0xF0) >> 4) & 0xF) << 4) + 0xa + payload[9] + payload[10]
        ctrl_transfer(dev_handle, 0x21, 0x9, 0x305, INTERFACE, payload[:]) or_return
        buf := [5]u8{}
        interrupt_transfer(dev_handle, 0x83, buf[:]) or_return
        if buf[2] == 0x50 do break
    }
    return nil
}
set_polling_rate :: proc (dev_handle: libusb.Device_Handle, polling_rate: PollingRate) -> libusb.Error {
    t := i32(0)
    for {
        payload := [9]u8{0x6, 0x9, 0x1, 0x1, 0x0, 0x0, 0x0, 0x0, 0x0}
        (transmute(^u16)&payload[3])^ = u16(polling_rate)
        ctrl_transfer(dev_handle, 0x21, 0x9, 0x306, INTERFACE, payload[:]) or_return
        buf := [5]u8{}
        interrupt_transfer(dev_handle, 0x83, buf[:]) or_return
        if buf[2] == 0x50 do break
    }
    return nil
}
Config :: struct {
    poll:            PollingRate,
    dpis:            [5]int,
    active_dpi:      int,
    sleep_time:      f64,
    deep_sleep_time: int,
    key_resp_time:   int
}
CfgErr :: enum {
    None,
    PollRateNotProvided,
    DpiValuesNotProvided,
    ActiveDpiNotProvided,
    InvalidActiveDpiValue,
    InvalidPollRate,
    InvalidDpiValue,
    NotEnoughDpiValues,
    TooMuchDpiValues,
    SleepTimeNotProvided,
    InvalidSleepTime,
    DeepSleepTimeNotProvided,
    InvalidDeepSleepTime,
    KeyRespTimeNotProvided,
    InvalidKeyRespTime,

}
ConfigError :: union #shared_nil {
    os.Error,
    ini.ParseErr,
    CfgErr,
}
load_config :: proc(path: string) -> (cfg: Config, err: ConfigError) {
    cfg = {}
    unwrap_parse_res :: proc(ini_cfg: ini.INI, res: ini.ParseResult) -> (ini.INI, ini.ParseErr) {
        return ini_cfg, res.err
    } 
    cfg_float :: proc(cfg: ini.INI, name: string, not_prov: ConfigError, inv_err: ConfigError) -> (f64, ConfigError) {
        str, ok := cfg[""][name]
        if !ok do return 0, not_prov
        val := f64(0)
        val, ok = strconv.parse_f64(strings.trim(str, " \n\t"))
        if !ok do return 0, inv_err
        return val, nil
    }
    cfg_int :: proc(cfg: ini.INI, name: string, not_prov: ConfigError, inv_err: ConfigError) -> (int, ConfigError) {
        str, ok := cfg[""][name]
        if !ok do return 0, not_prov
        val := 0
        val, ok = strconv.parse_int(strings.trim(str, " \n\t"))
        if !ok do return 0, inv_err
        return val, nil
    }
    file := os.read_entire_file_from_filename_or_err(path) or_return
    defer delete(file)
    
    ini_cfg := unwrap_parse_res(ini.parse(file)) or_return
    poll_rate_map := map[string]PollingRate {
        "125"  = .Hz125,
        "250"  = .Hz250,
        "500"  = .Hz500,
        "1000" = .Hz1000,
    }
    poll_rate, ok := ini_cfg[""]["polling_rate"]
    if !ok do return {}, .PollRateNotProvided
    if !(poll_rate in poll_rate_map) {
        return {}, .InvalidPollRate
    }
    cfg.poll = poll_rate_map[poll_rate]

    dpis := "" 
    dpis, ok = ini_cfg[""]["dpis"]
    if !ok do return {}, .DpiValuesNotProvided

    i := 0
    for dpi in strings.split_by_byte_iterator(&dpis, ' ') {
        if i >= 5 do return {}, .TooMuchDpiValues

        dpi_val, ok := strconv.parse_int(strings.trim(dpi, " \n\t"))
        if !ok || dpi_val < 100 || dpi_val > 18000 || dpi_val % 100 != 0 do return {}, .InvalidDpiValue 
        cfg.dpis[i] = dpi_val
        i += 1
    }
    if i != 5 do return {}, .NotEnoughDpiValues

    active_dpi_val := cfg_int(ini_cfg, "active_dpi", .ActiveDpiNotProvided, .InvalidActiveDpiValue) or_return
    if active_dpi_val < 1 || active_dpi_val > 5 do return {}, .InvalidActiveDpiValue
    cfg.active_dpi = active_dpi_val

    sleep_time := cfg_float(ini_cfg, "sleep_time", .SleepTimeNotProvided, .InvalidSleepTime) or_return
    if sleep_time < 0.5 || sleep_time > 30 do return {}, .InvalidSleepTime
    cfg.sleep_time = sleep_time

    deep_sleep_time := cfg_int(ini_cfg, "deep_sleep_time", .DeepSleepTimeNotProvided, .InvalidDeepSleepTime) or_return

    if deep_sleep_time < 1 || deep_sleep_time > 60 do return {}, .InvalidDeepSleepTime
    cfg.deep_sleep_time = deep_sleep_time
    
    key_resp_time := cfg_int(ini_cfg, "key_response_time", .KeyRespTimeNotProvided, .InvalidKeyRespTime) or_return

    if key_resp_time < 4 || key_resp_time > 50 || key_resp_time % 2 != 0 do return {}, .InvalidKeyRespTime
    cfg.key_resp_time = key_resp_time


    return cfg, nil
}
apply_config :: proc(config: Config, mouse: libusb.Device_Handle) -> libusb.Error {
    set_polling_rate(mouse, config.poll) or_return
    set_times(mouse, config.sleep_time, config.deep_sleep_time, config.key_resp_time) or_return
    return nil
}
CliOptions :: struct {
    polling_rate: int `usage:"Set polling rate(125, 250, 500, 1000)"`,
    config_path: string `usage:"Config file"`,
    key_response_time: int `usage:"Set key response time [4ms; 50ms]. Must be even number"`,
    sleep_time: f64 `usage:"Set sleep time [0.5ms; 30ms]"`,
    deep_sleep_time: int `usage:"Set deepsleep time [1ms; 60ms]"`,
    reapply_config: bool `usage:"Reapply entire config"`,
    query_charge: bool `usage:"Output current charge"`,
} 
DriverError :: union #shared_nil {
    ConfigError,
    libusb.Error,
}
driver_main :: proc(opts: CliOptions , config: ^Config) -> DriverError {
    ctx := libusb.Context {}
    libusb.init(&ctx)
    mouse, has_kern_driver := open_mouse(ctx) or_return
    defer if has_kern_driver do libusb.attach_kernel_driver(mouse, INTERFACE)

    libusb.claim_interface(mouse, INTERFACE) or_return
    defer libusb.release_interface(mouse, INTERFACE)

    if opts.reapply_config do apply_config(config^, mouse) or_return
    t := i32(0)
    buf := [5]u8{}
    libusb.interrupt_transfer(mouse, 0x83, slice.as_ptr(buf[:]), 64, &t, 0) or_return
    if opts.query_charge do fmt.println(buf[4] * 10)
    
    if opts.polling_rate != 0 {
        polls := map[int]PollingRate {
            125  = .Hz125,
            250  = .Hz250,
            500  = .Hz500,
            1000 = .Hz1000,
        }    
        if poll, ok := polls[opts.polling_rate]; ok {
            set_polling_rate(mouse, poll) or_return
        } else {
            return ConfigError(.InvalidPollRate)
        }
    }
    times := false
    if opts.key_response_time != 0 {
        key_resp_time := opts.key_response_time
        if key_resp_time < 4 || key_resp_time > 50 || key_resp_time % 2 != 0 do return ConfigError(.InvalidKeyRespTime)
        config.key_resp_time = key_resp_time
        times = true
    }
    if opts.deep_sleep_time != 0 {
        deep_sleep_time := opts.deep_sleep_time
        if deep_sleep_time < 1 || deep_sleep_time > 60 do return ConfigError(.InvalidDeepSleepTime)
        config.deep_sleep_time = deep_sleep_time
        times = true
    }
    if opts.sleep_time != 0 {
        sleep_time := opts.sleep_time
        if sleep_time < 0.5 || sleep_time > 30 do return ConfigError(.InvalidSleepTime)
        config.sleep_time = sleep_time
        times := true
    }
    if times do set_times(mouse, config.sleep_time, config.deep_sleep_time, config.key_resp_time) or_return

    return nil
}
main :: proc () {
    opts: CliOptions = {}
    flags.parse_or_exit(&opts, os.args, .Unix)

    cfg := os.get_env("XDG_CONFIG_HOME")
    if cfg == "" {
        arr := [3]string{os.get_env("HOME"), ".config", "attack-shark-r1.ini"}
        cfg = filepath.join(arr[:])
    } else {
        arr := [2]string{cfg, "attack-shark-r1.ini"}
        cfg = filepath.join(arr[:])
    }
    if opts.config_path != "" do cfg = opts.config_path
    if !os.exists(cfg) {
        cfg = "/etc/attack-shark-r1.ini"
    }
    config, cfg_err := load_config(cfg) 
    if cfg_err != nil {
        fmt.println("ERROR while loading config:", cfg_err)
    }
    err := driver_main(opts, &config)
    if err != nil {
        fmt.eprintln("ERROR:", err)
        os.exit(1)
    }
}

