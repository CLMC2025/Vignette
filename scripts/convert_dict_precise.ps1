# Dictionary conversion script with precise level tags
# Only use specific wordbook files for accurate level mapping

$ErrorActionPreference = "Stop"

# French character replacements
$FrEn = @{
    [char]0x00E9 = 'e'; [char]0x00EA = 'e'; [char]0x00E8 = 'e'; [char]0x00EB = 'e'
    [char]0x00E0 = 'a'; [char]0x00E2 = 'a'; [char]0x00E7 = 'c'
    [char]0x00EE = 'i'; [char]0x00EF = 'i'
    [char]0x00F4 = 'o'
    [char]0x00F9 = 'u'; [char]0x00FB = 'u'; [char]0x00FC = 'u'
    [char]0x00FF = 'y'
}

# Precise book file to level mapping
$BookLevelMap = @{
    # CET4 - only use CET4_1, CET4_2, CET4_3
    '1521164635506_CET4_2' = 'CET4'
    '1521164643060_CET4_3' = 'CET4'
    '1521164649209_CET4_1' = 'CET4'
    
    # CET6 - only use CET6_1, CET6_2, CET6_3
    '1521164633851_CET6_3' = 'CET6'
    '1521164668667_CET6_1' = 'CET6'
    '1524052554766_CET6_2' = 'CET6'
    
    # KaoYan - only use KaoYan_1, KaoYan_2, KaoYan_3
    '1521164654696_KaoYan_2' = 'KAIOYAN'
    '1521164658897_KaoYan_3' = 'KAIOYAN'
    '1521164669833_KaoYan_1' = 'KAIOYAN'
    
    # IELTS
    '1521164624473_IELTSluan_2' = 'IELTS'
    '1521164657744_IELTS_2' = 'IELTS'
    '1521164666922_IELTS_3' = 'IELTS'
    
    # TOEFL
    '1521164640451_TOEFL_2' = 'TOEFL'
    '1521164667985_TOEFL_3' = 'TOEFL'
    
    # GRE
    '1521164637271_GRE_2' = 'GRE'
    '1521164677706_GRE_3' = 'GRE'
    
    # GMAT
    '1521164629611_GMATluan_2' = 'GMAT'
    '1521164662073_GMAT_2' = 'GMAT'
    '1521164672691_GMAT_3' = 'GMAT'
    
    # SAT
    '1521164636496_SAT_3' = 'SAT'
    '1521164670910_SAT_2' = 'SAT'
    
    # BEC
    '1521164626760_BEC_2' = 'BEC'
    '1521164649506_BEC_3' = 'BEC'
    
    # High School (GaoZhong)
    '1521164675301_GaoZhong_2' = 'HIGH'
    '1521164679263_GaoZhong_3' = 'HIGH'
    '1521164674793_PEPGaoZhong_1' = 'HIGH'
    '1521164678610_PEPGaoZhong_2' = 'HIGH'
    '1521164676690_PEPGaoZhong_3' = 'HIGH'
    '1521164657462_PEPGaoZhong_4' = 'HIGH'
    '1521164657147_PEPGaoZhong_5' = 'HIGH'
    '1521164629184_PEPGaoZhong_6' = 'HIGH'
    '1521164648940_PEPGaoZhong_7' = 'HIGH'
    '1521164666266_PEPGaoZhong_8' = 'HIGH'
    '1521164670293_PEPGaoZhong_9' = 'HIGH'
    '1521164634796_PEPGaoZhong_10' = 'HIGH'
    '1521164639915_PEPGaoZhong_11' = 'HIGH'
    
    # Junior High (ChuZhong)
    '1521164647926_ChuZhong_2' = 'JUNIOR'
    '1521164652700_ChuZhong_3' = 'JUNIOR'
    '1521164666522_PEPChuZhong8_2' = 'JUNIOR'
    '1521164677043_PEPChuZhong7_2' = 'JUNIOR'
    '1530101067588_PEPChuZhong7_1' = 'JUNIOR'
    '1530101070747_PEPChuZhong8_1' = 'JUNIOR'
    '1530101078234_PEPChuZhong9_1' = 'JUNIOR'
    
    # Primary (XiaoXue)
    '1521164632445_PEPXiaoXue6_2' = 'PRIMARY'
    '1521164656604_PEPXiaoXue3_2' = 'PRIMARY'
    '1521164661774_PEPXiaoXue3_1' = 'PRIMARY'
    '1521164663086_PEPXiaoXue4_2' = 'PRIMARY'
    '1521164677447_PEPXiaoXue4_1' = 'PRIMARY'
    '1530101073491_PEPXiaoXue5_2' = 'PRIMARY'
    '1530101075331_PEPXiaoXue6_1' = 'PRIMARY'
    '1530101080610_PEPXiaoXue5_1' = 'PRIMARY'
}

function Replace-FrenchChars {
    param([string]$text)
    if ([string]::IsNullOrEmpty($text)) { return '' }
    $result = $text
    foreach ($key in $FrEn.Keys) {
        $result = $result.Replace($key, $FrEn[$key])
    }
    return $result
}

function Extract-Phonetic {
    param($wordData)
    try {
        $content = $wordData.content.word.content
        $usphone = $content.usphone
        $ukphone = $content.ukphone
        $phonetic = if ($usphone) { $usphone } else { $ukphone }
        return (Replace-FrenchChars $phonetic).Trim()
    } catch {
        return ''
    }
}

function Extract-Meanings {
    param($wordData)
    $meanings = @()
    try {
        $content = $wordData.content.word.content
        $trans = $content.trans
        
        foreach ($t in $trans) {
            $pos = $t.pos.Trim()
            $tranCn = (Replace-FrenchChars $t.tranCn).Trim()
            
            if ($pos -and $tranCn) {
                if (-not $pos.EndsWith('.')) {
                    $pos = $pos + '.'
                }
                $meanings += "$pos $tranCn"
            } elseif ($tranCn) {
                $meanings += $tranCn
            }
        }
    } catch {}
    
    return $meanings
}

# Main
$dictDir = "D:\Downloads\dict-master\dict-master"
$bookDir = Join-Path $dictDir "book"
$masterPath = "D:\DevEcoStudioProjects\Vignette\entry\src\main\resources\rawfile\wordbooks\master.txt"
$levelsPath = "D:\DevEcoStudioProjects\Vignette\entry\src\main\resources\rawfile\wordbooks\word_levels.txt"

$allWords = @{}  # word -> @{phonetic, meanings, levels}
$levelStats = @{} # level -> count
$totalCount = 0

if (Test-Path $bookDir) {
    $files = Get-ChildItem -Path $bookDir -Filter "*.zip"
    
    foreach ($file in $files) {
        # Check if this file is in our mapping
        $baseName = $file.BaseName
        $level = $null
        
        foreach ($key in $BookLevelMap.Keys) {
            if ($baseName -eq $key) {
                $level = $BookLevelMap[$key]
                break
            }
        }
        
        if (-not $level) {
            continue  # Skip files not in our mapping
        }
        
        Write-Host "Processing: $($file.Name) -> $level"
        
        $tempDir = Join-Path $env:TEMP "dict_extract_$baseName"
        if (Test-Path $tempDir) {
            Remove-Item -Recurse -Force $tempDir
        }
        Expand-Archive -Path $file.FullName -DestinationPath $tempDir -Force
        
        $jsonFiles = Get-ChildItem -Path $tempDir -Filter "*.json" -Recurse
        
        foreach ($jsonFile in $jsonFiles) {
            $lines = Get-Content -Path $jsonFile.FullName -Encoding UTF8
            
            foreach ($line in $lines) {
                $trimmed = $line.Trim()
                if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
                
                try {
                    $wordData = $trimmed | ConvertFrom-Json
                } catch {
                    continue
                }
                
                $headWord = $wordData.headWord
                if ([string]::IsNullOrWhiteSpace($headWord)) { continue }
                
                $headWord = (Replace-FrenchChars $headWord).ToLower().Trim()
                $phonetic = Extract-Phonetic $wordData
                $meanings = Extract-Meanings $wordData
                
                if (-not $allWords.ContainsKey($headWord)) {
                    $allWords[$headWord] = @{
                        phonetic = $phonetic
                        meanings = $meanings
                        levels = @($level)
                    }
                } else {
                    $existing = $allWords[$headWord]
                    if (-not $existing.phonetic -and $phonetic) {
                        $existing.phonetic = $phonetic
                    }
                    $existingSet = @($existing.meanings)
                    foreach ($m in $meanings) {
                        if ($m -notin $existingSet) {
                            $existing.meanings += $m
                        }
                    }
                    if ($level -notin $existing.levels) {
                        $existing.levels += $level
                    }
                }
                
                $totalCount++
            }
        }
        
        Remove-Item -Recurse -Force $tempDir
    }
}

Write-Host "`nTotal processed: $totalCount records"
Write-Host "Unique words: $($allWords.Count)"

# Sort and write output
$sorted = $allWords.Keys | Sort-Object
$masterLines = New-Object System.Collections.ArrayList
$levelLines = New-Object System.Collections.ArrayList

foreach ($word in $sorted) {
    $data = $allWords[$word]
    $phonetic = $data.phonetic
    $meanings = $data.meanings
    $levels = ($data.levels | Sort-Object -Unique) -join ','
    
    # Master line
    $line = $word
    if ($phonetic) {
        $line = "$word [$phonetic]"
    }
    if ($meanings.Count -gt 0) {
        $line = "$line $($meanings -join ' ')"
    }
    [void]$masterLines.Add($line)
    
    # Level line
    if ($levels) {
        [void]$levelLines.Add("$word $levels")
        
        # Count per level
        foreach ($lvl in $data.levels) {
            if (-not $levelStats.ContainsKey($lvl)) {
                $levelStats[$lvl] = 0
            }
            $levelStats[$lvl]++
        }
    }
}

$masterLines | Out-File -FilePath $masterPath -Encoding UTF8
Write-Host "`nWrote $($masterLines.Count) words to $masterPath"

$levelLines | Out-File -FilePath $levelsPath -Encoding UTF8
Write-Host "Wrote $($levelLines.Count) level mappings to $levelsPath"

# Stats
Write-Host "`nLevel distribution:"
foreach ($lvl in $levelStats.Keys | Sort-Object) {
    Write-Host "  $lvl`: $($levelStats[$lvl])"
}
