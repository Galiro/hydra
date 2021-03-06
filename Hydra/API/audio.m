#import "helpers.h"
#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>


#define hydra_audio_device(L, idx) *(AudioDeviceID*)luaL_checkudata(L, idx, "audio_device")

static bool _check_audio_device_has_streams(AudioDeviceID deviceId, AudioObjectPropertyScope scope) {
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyStreams,
        scope,
        kAudioObjectPropertyElementMaster
    };
    
    OSStatus result = noErr;
    UInt32 dataSize = 0;
    
    result = AudioObjectGetPropertyDataSize(deviceId, &propertyAddress, 0, NULL, &dataSize);
    
    if (result)
        goto error;
    
    return (dataSize / sizeof(AudioStreamID)) > 0;
    
    
error:
    return false;
}

void new_device(lua_State* L, AudioDeviceID deviceId) {
    AudioDeviceID* userData = (AudioDeviceID*) lua_newuserdata(L, sizeof(AudioDeviceID));
    *userData = deviceId;
    
    luaL_getmetatable(L, "audio_device");
    lua_setmetatable(L, -2);
}

static int audio_alloutputdevices(lua_State* L) {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    OSStatus result = noErr;
    AudioDeviceID *deviceList = NULL;
    UInt32 deviceListPropertySize = 0;
    UInt32 numDevices = 0;
    
    result = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceListPropertySize);
    if (result) {
        goto error;
    }
    
    numDevices = deviceListPropertySize / sizeof(AudioDeviceID);
    deviceList = (AudioDeviceID*) calloc(numDevices, sizeof(AudioDeviceID));
    
    if (!deviceList)
        goto error;
    
    result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceListPropertySize, deviceList);
    if (result) {
        goto error;
    }
    
    lua_newtable(L);
    
    for(UInt32 i = 0, tableIndex = 1; i < numDevices; i++) {
        AudioDeviceID deviceId = deviceList[i];
        if (!_check_audio_device_has_streams(deviceId, kAudioDevicePropertyScopeOutput))
            continue;
        
        lua_pushnumber(L, tableIndex++);
        new_device(L, deviceId);
        lua_settable(L, -3);
    }
    
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    if (deviceList)
        free(deviceList);
    
    return 1;
}

static int audio_defaultoutputdevice(lua_State* L) {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    
    AudioDeviceID deviceId;
    UInt32 deviceIdSize = sizeof(AudioDeviceID);
    OSStatus result = noErr;
    
    result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceIdSize, &deviceId);
    if (result)
        goto error;
    
    if (!_check_audio_device_has_streams(deviceId, kAudioDevicePropertyScopeOutput))
        goto error;
    
    new_device(L, deviceId);
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    
    return 1;
}

static int audio_setdefaultoutputdevice(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    
    UInt32 deviceIdSize = sizeof(AudioDeviceID);
    OSStatus result = noErr;
    
    if (!_check_audio_device_has_streams(deviceId, kAudioDevicePropertyScopeOutput))
        goto error;
    
    result = AudioObjectSetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, deviceIdSize, &deviceId);
    
    if (result)
        goto error;
    
    lua_pushboolean(L, true);
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    
    return 1;
}

static int audio_device_name(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyName,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    CFStringRef deviceName;
    UInt32 propertySize = sizeof(CFStringRef);
    
    OSStatus result = noErr;
    
    result = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &propertySize, &deviceName);
    if (result)
        goto error;
    
    CFIndex length = CFStringGetLength(deviceName);
    const char* deviceNameBytes = CFStringGetCStringPtr(deviceName, kCFStringEncodingMacRoman);
    
    lua_pushlstring(L, deviceNameBytes, length);
    CFRelease(deviceName);
    
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    return 1;
    
}

static int audio_device_muted(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
    
    if (!AudioObjectHasProperty(deviceId, &propertyAddress)) {
        goto error;
    }
    
    OSStatus result = noErr;
    UInt32 muted;
    UInt32 mutedSize = sizeof(UInt32);
    
    result = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &mutedSize, &muted);
    if (result)
        goto error;
    
    lua_pushboolean(L, muted != 0);
    
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    return 1;
    
}

static int audio_device_setmuted(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    UInt32 muted = lua_toboolean(L, 2);
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
    
    if (!AudioObjectHasProperty(deviceId, &propertyAddress)) {
        goto error;
    }
    
    OSStatus result = noErr;
    UInt32 mutedSize = sizeof(UInt32);
    
    result = AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, mutedSize, &muted);
    if (result)
        goto error;
    
    lua_pushboolean(L, true);
    
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    return 1;
    
}


static int audio_device_volume(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
    
    if (!AudioObjectHasProperty(deviceId, &propertyAddress))
        goto error;
    
    OSStatus result = noErr;
    Float32 volume;
    UInt32 volumeSize = sizeof(Float32);
    
    result = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &volumeSize, &volume);
    
    if (result)
        goto error;
    
    lua_pushnumber(L, volume * 100.0);
    
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    return 1;
    
}



static int audio_device_setvolume(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    Float32 volume = MIN(MAX(luaL_checknumber(L, 2) / 100.0, 0.0), 1.0);
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };
    
    if (!AudioObjectHasProperty(deviceId, &propertyAddress))
        goto error;
    
    OSStatus result = noErr;
    UInt32 volumeSize = sizeof(Float32);
    
    result = AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, volumeSize, &volume);
    
    if (result)
        goto error;
    
    lua_pushboolean(L, true);
    
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    return 1;
    
}

static int audio_device_eq(lua_State* L) {
    AudioDeviceID deviceA = hydra_audio_device(L, 1);
    AudioDeviceID deviceB = hydra_audio_device(L, 2);
    lua_pushboolean(L, deviceA == deviceB);
    return 1;
}

static const luaL_Reg audiolib[] = {
    
    {"alloutputdevices", audio_alloutputdevices},
    {"defaultoutputdevice", audio_defaultoutputdevice},
    {"setdefaultoutputdevice", audio_setdefaultoutputdevice},
    
    {"name", audio_device_name},
    
    {"volume", audio_device_volume},
    {"setvolume", audio_device_setvolume},
    
    {"muted", audio_device_muted},
    {"setmuted", audio_device_setmuted},
    
    {NULL, NULL}
};

int luaopen_audio(lua_State* L) {
    luaL_newlib(L, audiolib);
    
    if (luaL_newmetatable(L, "audio_device")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");
        
        lua_pushcfunction(L, audio_device_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_pop(L, 1);
    
    return 1;
}
