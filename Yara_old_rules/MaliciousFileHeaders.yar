rule MaliciousFileHeaders
{
    meta:
        description = "Detects files with headers or magic bytes common in malicious files"
        author = "pk"
        date = "2018-06-01"

    strings:
        $hdr1 = { 4D 5A } // MZ header for PE executables
        $hdr2 = { 23 21 } // #! for shell scripts
        $hdr3 = { D0 CF 11 E0 A1 B1 1A E1 } // OLE2 header for Office documents
        $hdr4 = { 50 4B 03 04 } // ZIP header (used in malicious Office or JAR files)
        $hdr5 = "<?php" nocase // PHP script start
        $hdr6 = "MZ" ascii // ASCII MZ for PE files

    condition:
        any of them
}