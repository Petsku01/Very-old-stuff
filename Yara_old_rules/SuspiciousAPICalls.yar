rule SuspiciousAPICalls
{
    meta:
        description = "Detects files with suspicious Windows API calls or functions common in malware"
        author = "pk"
        date = "2018-04-12"

    strings:
        $api1 = "CreateRemoteThread" nocase
        $api2 = "VirtualAlloc" nocase
        $api3 = "WriteProcessMemory" nocase
        $api4 = "WinExec" nocase
        $api5 = "URLDownloadToFile" nocase
        $api6 = "ShellExecute" nocase

    condition:
        any of them
}