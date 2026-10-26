## Script
```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NPSummers/Hydroxide-/main/loadstring.lua?_=" .. tostring(os.time())))()
```

Requires an executor that implements the sUNC API.

# Hydroxide+ (New)
<i>Lua runtime introspection and network capturing tool for games on the Roblox engine.</i>


<p align="center">
    <img src="https://raw.githubusercontent.com/NPSummers/Hydroxide-/main/github-assets/ui.png" width="677px"/>
</p>

## Features
* Upvalue Scanner
    * View/Modify Upvalues
    * View first-level values in table upvalues
    * View information of closure
* Constant Scanner
    * View/Modify Constants
    * View information of closure
* Script Scanner
    * View general information of scripts (source, protos, constants, etc.)
    * Retrieve all protos found in GC
* Module Scanner
    * View general information of modules (return value, source, protos, constants, etc.)
    * Retrieve all protos found in GC
* RemoteSpy
    * Log calls of remote objects (RemoteEvent, RemoteFunction, BindableEvent, BindableFunction)
    * Ignore/Block calls based on parameters passed
    * Traceback calling function/closure
    * Protects against remotespy detection
* ClosureSpy
    * Log calls of closures
    * View general information of closures (location, protos, constants, etc.)

More to come, soon.
