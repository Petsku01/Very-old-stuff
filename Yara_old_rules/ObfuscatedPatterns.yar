rule ObfuscatedPatterns
{
    meta:
        description = "Detects files with suspicious obfuscation or encoded patterns common in current malware"
        author = "pk"
        date = "2018-11-01"

    strings:
        $obf1 = "base64_decode" nocase
        $obf2 = "atob(" nocase
        $obf3 = "b64decode" nocase
        $obf4 = /\\x[0-9a-fA-F]{2}/  // Matches hex-encoded bytes like \x41
        $obf5 = "FromBase64String" nocase
        $obf6 = "CharToOem" nocase

    condition:
        any of them
}