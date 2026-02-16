/**
 * 词典转换脚本
 * 将 kajweb/dict 项目的 JSON 格式转换为 Vignette 应用需要的 TXT 格式
 */

const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

// 法语字母替换表
const FR_EN = [
  ['é', 'e'], ['ê', 'e'], ['è', 'e'], ['ë', 'e'],
  ['à', 'a'], ['â', 'a'], ['ç', 'c'],
  ['î', 'i'], ['ï', 'i'],
  ['ô', 'o'],
  ['ù', 'u'], ['û', 'u'], ['ü', 'u'],
  ['ÿ', 'y']
];

function replaceFrenchChars(text) {
  if (!text) return '';
  let result = text;
  for (const [fr, en] of FR_EN) {
    result = result.split(fr).join(en);
  }
  return result;
}

function extractPhonetic(wordData) {
  const content = wordData?.content?.word?.content || {};
  const usphone = content.usphone || '';
  const ukphone = content.ukphone || '';
  const phonetic = usphone || ukphone;
  return replaceFrenchChars(phonetic).trim();
}

function extractMeanings(wordData) {
  const content = wordData?.content?.word?.content || {};
  const trans = content.trans || [];
  
  const meanings = [];
  for (const t of trans) {
    let pos = (t.pos || '').trim();
    let tranCn = replaceFrenchChars((t.tranCn || '').trim());
    
    if (pos && tranCn) {
      if (!pos.endsWith('.')) {
        pos = pos + '.';
      }
      meanings.push(`${pos} ${tranCn}`);
    } else if (tranCn) {
      meanings.push(tranCn);
    }
  }
  
  return meanings;
}

function processZipFile(zipPath, allWords) {
  const AdmZip = require('adm-zip');
  const zip = new AdmZip(zipPath);
  const entries = zip.getEntries();
  
  let count = 0;
  
  for (const entry of entries) {
    if (!entry.entryName.endsWith('.json')) continue;
    
    const content = entry.getData().toString('utf8');
    const lines = content.split('\n');
    
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      
      let wordData;
      try {
        wordData = JSON.parse(trimmed);
      } catch (e) {
        continue;
      }
      
      let headWord = (wordData.headWord || '').trim().toLowerCase();
      if (!headWord) continue;
      
      headWord = replaceFrenchChars(headWord);
      const phonetic = extractPhonetic(wordData);
      const meanings = extractMeanings(wordData);
      
      if (!allWords.has(headWord)) {
        allWords.set(headWord, { phonetic, meanings });
      } else {
        const existing = allWords.get(headWord);
        if (!existing.phonetic && phonetic) {
          existing.phonetic = phonetic;
        }
        const existingSet = new Set(existing.meanings);
        for (const m of meanings) {
          if (!existingSet.has(m)) {
            existing.meanings.push(m);
            existingSet.add(m);
          }
        }
      }
      
      count++;
    }
  }
  
  return count;
}

function writeOutput(allWords, outputPath) {
  const sorted = [...allWords.entries()].sort((a, b) => a[0].localeCompare(b[0]));
  
  const lines = [];
  for (const [word, data] of sorted) {
    const { phonetic, meanings } = data;
    
    let line = word;
    if (phonetic) {
      line = `${word} [${phonetic}]`;
    }
    
    if (meanings.length > 0) {
      line = line + ' ' + meanings.join(' ');
    }
    
    lines.push(line);
  }
  
  fs.writeFileSync(outputPath, lines.join('\n'), 'utf8');
  console.log(`写入 ${sorted.length} 个单词到 ${outputPath}`);
}

async function main() {
  const dictDir = 'D:\\Downloads\\dict-master\\dict-master';
  const bookDir = path.join(dictDir, 'book');
  const outputPath = 'D:\\DevEcoStudioProjects\\Vignette\\entry\\src\\main\\resources\\rawfile\\wordbooks\\master.txt';
  
  const allWords = new Map();
  let totalCount = 0;
  
  // 检查 adm-zip 是否安装
  try {
    require.resolve('adm-zip');
  } catch (e) {
    console.log('安装 adm-zip...');
    require('child_process').execSync('npm install adm-zip', { cwd: __dirname, stdio: 'inherit' });
  }
  
  if (fs.existsSync(bookDir)) {
    const files = fs.readdirSync(bookDir);
    for (const filename of files) {
      if (!filename.endsWith('.zip')) continue;
      
      const zipPath = path.join(bookDir, filename);
      console.log(`处理: ${filename}`);
      const count = processZipFile(zipPath, allWords);
      totalCount += count;
      console.log(`  -> ${count} 个单词`);
    }
  }
  
  console.log(`\n总共处理: ${totalCount} 条记录`);
  console.log(`去重后: ${allWords.size} 个唯一单词`);
  
  writeOutput(allWords, outputPath);
  
  let withPhonetic = 0;
  let withMeanings = 0;
  for (const [, data] of allWords) {
    if (data.phonetic) withPhonetic++;
    if (data.meanings.length > 0) withMeanings++;
  }
  
  console.log('\n统计:');
  console.log(`  有音标: ${withPhonetic} (${(withPhonetic * 100 / allWords.size).toFixed(1)}%)`);
  console.log(`  有释义: ${withMeanings} (${(withMeanings * 100 / allWords.size).toFixed(1)}%)`);
}

main().catch(console.error);
