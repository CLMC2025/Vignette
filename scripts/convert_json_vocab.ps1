# Convert JSON vocabulary files to master.txt and word_levels.txt
# Uses json-full format which contains word, phonetic (usphone/ukphone), and translations

$ErrorActionPreference = "Stop"

# Book file to level mapping
$BookLevelMap = @{
    # CET4
    'CET4_1' = 'CET4'
    'CET4_2' = 'CET4'
    'CET4_3' = 'CET4'
    
    # CET6
    'CET6_1' = 'CET6'
    'CET6_2' = 'CET6'
    'CET6_3' = 'CET6'
    
    # KaoYan
    'KaoYan_1' = 'KAIOYAN'
    'KaoYan_2' = 'KAIOYAN'
    'KaoYan_3' = 'KAIOYAN'
    
    # IELTS
    'IELTS_2' = 'IELTS'
    'IELTS_3' = 'IELTS'
    
    # TOEFL
    'TOEFL_2' = 'TOEFL'
    'TOEFL_3' = 'TOEFL'
    
    # GRE
    'GRE_2' = 'GRE'
    'GRE_3' = 'GRE'
    
    # GMAT
    'GMAT_2' = 'GMAT'
    'GMAT_3' = 'GMAT'
    
    # SAT
    'SAT_2' = 'SAT'
    'SAT_3' = 'SAT'
    
    # BEC
    'BEC_2' = 'BEC'
    'BEC_3' = 'BEC'
    
    # High School (GaoZhong)
    'GaoZhong_2' = 'HIGH'
    'GaoZhong_3' = 'HIGH'
    'PEPGaoZhong_1' = 'HIGH'
    'PEPGaoZhong_2' = 'HIGH'
    'PEPGaoZhong_3' = 'HIGH'
    'PEPGaoZhong_4' = 'HIGH'
    'PEPGaoZhong_5' = 'HIGH'
    'PEPGaoZhong_6' = 'HIGH'
    'PEPGaoZhong_7' = 'HIGH'
    'PEPGaoZhong_8' = 'HIGH'
    'PEPGaoZhong_9' = 'HIGH'
    'PEPGaoZhong_10' = 'HIGH'
    'PEPGaoZhong_11' = 'HIGH'
    'BeiShiGaoZhong_1' = 'HIGH'
    'BeiShiGaoZhong_2' = 'HIGH'
    'BeiShiGaoZhong_3' = 'HIGH'
    'BeiShiGaoZhong_4' = 'HIGH'
    'BeiShiGaoZhong_5' = 'HIGH'
    'BeiShiGaoZhong_6' = 'HIGH'
    'BeiShiGaoZhong_7' = 'HIGH'
    'BeiShiGaoZhong_8' = 'HIGH'
    'BeiShiGaoZhong_9' = 'HIGH'
    'BeiShiGaoZhong_10' = 'HIGH'
    'BeiShiGaoZhong_11' = 'HIGH'
    
    # Junior High (ChuZhong)
    'ChuZhong_2' = 'JUNIOR'
    'ChuZhong_3' = 'JUNIOR'
    'PEPChuZhong7_1' = 'JUNIOR'
    'PEPChuZhong7_2' = 'JUNIOR'
    'PEPChuZhong8_1' = 'JUNIOR'
    'PEPChuZhong8_2' = 'JUNIOR'
    'PEPChuZhong9_1' = 'JUNIOR'
    'WaiYanSheChuZhong_1' = 'JUNIOR'
    'WaiYanSheChuZhong_2' = 'JUNIOR'
    'WaiYanSheChuZhong_3' = 'JUNIOR'
    'WaiYanSheChuZhong_4' = 'JUNIOR'
    'WaiYanSheChuZhong_5' = 'JUNIOR'
    'WaiYanSheChuZhong_6' = 'JUNIOR'
    
    # Primary (XiaoXue)
    'PEPXiaoXue3_1' = 'PRIMARY'
    'PEPXiaoXue3_2' = 'PRIMARY'
    'PEPXiaoXue4_1' = 'PRIMARY'
    'PEPXiaoXue4_2' = 'PRIMARY'
    'PEPXiaoXue5_1' = 'PRIMARY'
    'PEPXiaoXue5_2' = 'PRIMARY'
    'PEPXiaoXue6_1' = 'PRIMARY'
    'PEPXiaoXue6_2' = 'PRIMARY'
}

function Get-LevelFromFileName {
    param([string]$fileName)
    
    $baseName = $fileName -replace '\.json$', ''
    
    foreach ($key in $BookLevelMap.Keys) {
        if ($baseName -eq $key) {
            return $BookLevelMap[$key]
        }
    }
    
    return $null
}

function Process-JsonFile {
    param(
        [string]$filePath,
        [hashtable]$allWords,
        [string]$level
    )
    
    $content = Get-Content -Path $filePath -Encoding UTF8 -Raw
    
    try {
        $wordArray = $content | ConvertFrom-Json
    } catch {
        Write-Host "  Failed to parse JSON: $($_.Exception.Message)"
        return
    }
    
    $count = 0
    foreach ($wordData in $wordArray) {
        $headWord = $wordData.headWord
        if ([string]::IsNullOrWhiteSpace($headWord)) { continue }
        
        # Skip phrases (contain spaces or special chars)
        if ($headWord -match '[\s\(\)\/]') { continue }
        
        $headWord = $headWord.ToLower().Trim()
        
        # Extract phonetic from json-full format
        $phonetic = ''
        try {
            $wordContent = $wordData.content.word.content
            if ($wordContent.PSObject.Properties.Match('usphone').Count -gt 0) {
                $phonetic = $wordContent.usphone
            } elseif ($wordContent.PSObject.Properties.Match('ukphone').Count -gt 0) {
                $phonetic = $wordContent.ukphone
            }
            if ($phonetic) { $phonetic = $phonetic.Trim() }
        } catch {}
        
        # Extract translations
        $meanings = @()
        try {
            $wordContent = $wordData.content.word.content
            if ($wordContent.PSObject.Properties.Match('trans').Count -gt 0) {
                foreach ($trans in $wordContent.trans) {
                    $pos = $trans.pos
                    $meaning = $trans.tranCn
                    
                    if ($pos -and $meaning) {
                        if (-not $pos.EndsWith('.')) {
                            $pos = $pos + '.'
                        }
                        $meanings += "$pos $meaning"
                    } elseif ($meaning) {
                        $meanings += $meaning
                    }
                }
            }
        } catch {}
        
        # Store or merge
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
            foreach ($m in $meanings) {
                if ($m -notin $existing.meanings) {
                    $existing.meanings += $m
                }
            }
            if ($level -and $level -notin $existing.levels) {
                $existing.levels += $level
            }
        }
        
        $count++
    }
    
    Write-Host "  -> $count words"
}

# Main
$sourceDir = "D:\Downloads\english-vocabulary-master (1)\english-vocabulary-master\json_original\json-full"
$masterPath = "D:\DevEcoStudioProjects\Vignette\entry\src\main\resources\rawfile\wordbooks\master.txt"
$levelsPath = "D:\DevEcoStudioProjects\Vignette\entry\src\main\resources\rawfile\wordbooks\word_levels.txt"

$allWords = @{}
$levelStats = @{}
$fileCount = 0

if (Test-Path $sourceDir) {
    $files = Get-ChildItem -Path $sourceDir -Filter "*.json"
    
    foreach ($file in $files) {
        $level = Get-LevelFromFileName $file.Name
        
        if (-not $level) {
            continue
        }
        
        Write-Host "Processing: $($file.Name) -> $level"
        Process-JsonFile -filePath $file.FullName -allWords $allWords -level $level
        $fileCount++
    }
}

Write-Host "`nProcessed $fileCount files"
Write-Host "Unique words: $($allWords.Count)"

# Sort and write output
$sorted = $allWords.Keys | Sort-Object
$masterLines = New-Object System.Collections.ArrayList
$levelLines = New-Object System.Collections.ArrayList

foreach ($word in $sorted) {
    $data = $allWords[$word]
    $phonetic = $data.phonetic
    $meanings = $data.meanings
    $levels = ($data.levels | Where-Object { $_ } | Sort-Object -Unique) -join ','
    
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
            if ($lvl) {
                if (-not $levelStats.ContainsKey($lvl)) {
                    $levelStats[$lvl] = 0
                }
                $levelStats[$lvl]++
            }
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
