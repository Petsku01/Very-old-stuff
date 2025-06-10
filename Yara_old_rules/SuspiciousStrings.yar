rule SuspiciousStrings
{
    meta:
        description = "Detects files with suspicious strings commonly found in current malicious software"
        author = "pk"
        date = "2018-02-14"

    strings:
        $str1 = "cmd.exe" nocase
        $str2 = "powershell.exe" nocase
        $str3 = "http://" nocase
        $str4 = "https://" nocase
        $str5 = "rundll32.exe" nocase
        $str6 = "regsvr32.exe" nocase

    condition:
        any of them
}