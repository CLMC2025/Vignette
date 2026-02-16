# Dictionary conversion script with level tags
# Convert kajweb/dict JSON format to Vignette TXT format with exam level tags

$ErrorActionPreference = "Stop"

# French character replacements using Unicode escape sequences
$FrEn = @{
    [char]0x00E9 = 'e'; [char]0x00EA = 'e'; [char]0x00E8 = 'e'; [char]0x00EB = 'e'
    [char]0x00E0 = 'a'; [char]0x00E2 = 'a'; [char]0x00E7 = 'c'
    [char]0x00EE = 'i'; [char]0x00EF = 'i'
    [char]0x00F4 = 'o'
    [char]0x00F9 = 'u'; [char]0x00FB = 'u'; [char]0x00FC = 'u'
    [char]0x00FF = 'y'
}

# Book ID to Exam Level mapping
$BookLevelMap = @{
    'CET4' = 'CET4'
    'CET6' = 'CET6'
    'KaoYan' = 'KAIOYAN'
    'IELTS' = 'IELTS'
    'TOEFL' = 'TOEFL'
    'GRE' = 'GRE'
    'GMAT' = 'GMAT'
    'SAT' = 'SAT'
    'GaoZhong' = 'HIGH'
    'ChuZhong' = 'JUNIOR'
    'PEPGaoZhong' = 'HIGH'
    'PEPChuZhong' = 'JUNIOR'
    'PEPXiaoXue' = 'PRIMARY'
    'Level4' = 'CET4'
    'Level8' = 'CET6'
    'BEC' = 'BEC'
    'BeiShiGaoZhong' = 'HIGH'
    'WaiYanSheChuZhong' = 'JUNIOR'
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

function Get-LevelFromBookId {
    param([string]$bookId)
    
    foreach ($key in $BookLevelMap.Keys) {
        if ($bookId -match $key) {
            return $BookLevelMap[$key]
        }
    }
    return ''
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
$outputPath = "D:\DevEcoStudioProjects\Vignette\entry\src\main\resources\rawfile\wordbooks\master.txt"
$levelsPath = "D:\DevEcoStudioProjects\Vignette\entry\src\main\resources\rawfile\wordbooks\word_levels.txt"

$allWords = @{}  # word -> @{phonetic, meanings, levels}
$totalCount = 0

if (Test-Path $bookDir) {
    $files = Get-ChildItem -Path $bookDir -Filter "*.zip"
    
    foreach ($file in $files) {
        Write-Host "Processing: $($file.Name)"
        
        # Extract level from filename
        $bookId = $file.BaseName
        $level = Get-LevelFromBookId $bookId
        
        $tempDir = Join-Path $env:TEMP "dict_extract_$($file.BaseName)"
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
                    if ($level -and $level -notin $existing.levels) {
                        $existing.levels += $level
                    }
                }
                
                $totalCount++
            }
        }
        
        Remove-Item -Recurse -Force $tempDir
        Write-Host "  -> Done"
    }
}

Write-Host "`nTotal processed: $totalCount records"
Write-Host "Unique words: $($allWords.Count)"

# Sort and write output
$sorted = $allWords.Keys | Sort-Object
$outputLines = New-Object System.Collections.ArrayList
$levelLines = New-Object System.Collections.ArrayList

foreach ($word in $sorted) {
    $data = $allWords[$word]
    $phonetic = $data.phonetic
    $meanings = $data.meanings
    $levels = ($data.levels | Where-Object { $_ } | Sort-Object -Unique) -join ','
    
    $line = $word
    if ($phonetic) {
        $line = "$word [$phonetic]"
    }
    
    if ($meanings.Count -gt 0) {
        $line = "$line $($meanings -join ' ')"
    }
    
    [void]$outputLines.Add($line)
    
    # Write level mapping
    if ($levels) {
        [void]$levelLines.Add("$word $levels")
    }
}

$outputLines | Out-File -FilePath $outputPath -Encoding UTF8
Write-Host "`nWrote $($sorted.Count) words to $outputPath"

$levelLines | Out-File -FilePath $levelsPath -Encoding UTF8
Write-Host "Wrote $($levelLines.Count) level mappings to $levelsPath"

# Stats
$withPhonetic = ($allWords.Values | Where-Object { $_.phonetic }).Count
$withMeanings = ($allWords.Values | Where-Object { $_.meanings.Count -gt 0 }).Count
$withLevels = ($allWords.Values | Where-Object { $_.levels.Count -gt 0 }).Count

Write-Host "`nStatistics:"
Write-Host "  With phonetic: $withPhonetic"
Write-Host "  With meanings: $withMeanings"
Write-Host "  With levels: $withLevels"

# Level distribution
$levelStats = @{}
foreach ($entry in $allWords.Values) {
    foreach ($lvl in $entry.levels) {
        if ($lvl) {
            if (-not $levelStats.ContainsKey($lvl)) {
                $levelStats[$lvl] = 0
            }
            $levelStats[$lvl]++
        }
    }
}

Write-Host "`nLevel distribution:"
foreach ($lvl in $levelStats.Keys | Sort-Object) {
    Write-Host "  $lvl`: $($levelStats[$lvl])"
}
