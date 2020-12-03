## creating a user token

```cpp
// see Removed code relying on USE_NTCREATETOKEN at https://github.com/PowerShell/Win32-OpenSSH/commit/268bdeb6626f9b45767ac856ce6efdd9bf7e8d50
// the removed code (the parent of the above commit) was at:
// HANDLE CreateUserToken(const char *userName, const char *domainName, const char *sourceName)
//     https://github.com/PowerShell/Win32-OpenSSH/blob/a3cc5c797de5a9086b1c81c7c45fc713476bcab3/contrib/win32/win32compat/win32auth.c#L515-L516
HANDLE CreateUserToken(
    const char *userName,
    const char *domainName,
    const char *sourceName
)

// see https://www.codeproject.com/Articles/6443/GUI-Based-RunAsEx
// see https://github.com/bb107/WinSudo
// see https://github.com/dahall/Vanara/blob/1fb8a2dc8a116995831730a7d433a07f940cc5ef/System/Extensions/ProcessExtension.cs#L332
// see https://github.com/dahall/Vanara/blob/1fb8a2dc8a116995831730a7d433a07f940cc5ef/UnitTests/PInvoke/Security/AdvApi32/WinBaseTests.cs#L121

// see https://github.com/googleprojectzero/sandbox-attacksurface-analysis-tools
// see https://www.tiraniddo.dev/2020/01/empirically-assessing-windows-service.html
// see https://www.tiraniddo.dev/2020/01/dont-use-system-tokens-for-sandboxing.html
// see https://github.com/rmusser01/Infosec_Reference
```

Continue looking for NtCreateToken usages in GitHub:

    https://github.com/search?p=2&q=ntcreatetoken&type=Code
