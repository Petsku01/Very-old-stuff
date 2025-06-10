rule MaliciousScriptPatterns
{
    meta:
        description = "Detects files with suspicious scripting patterns common in current malware"
        author = "pk"
        date = "2018-12-05"

    strings:
        $script1 = "document.createElement" nocase
        $script2 = "eval(" nocase
        $script3 = "ActiveXObject" nocase
        $script4 = "WScript.Shell" nocase
        $script5 = "fromCharCode" nocase
        $script6 = "unescape(" nocase

    condition:
        any of them
}