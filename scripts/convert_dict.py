#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
词典转换脚本
将 kajweb/dict 项目的 JSON 格式转换为 Vignette 应用需要的 TXT 格式
"""

import os
import json
import zipfile
from typing import Dict, List

# 法语字母替换表
FR_EN = [
    ['é', 'e'], ['ê', 'e'], ['è', 'e'], ['ë', 'e'],
    ['à', 'a'], ['â', 'a'], ['ç', 'c'],
    ['î', 'i'], ['ï', 'i'],
    ['ô', 'o'],
    ['ù', 'u'], ['û', 'u'], ['ü', 'u'],
    ['ÿ', 'y']
]

def replace_french_chars(text: str) -> str:
    """替换法语字母为英语字母"""
    for fr, en in FR_EN:
        text = text.replace(fr, en)
    return text

def extract_phonetic(word_data: dict) -> str:
    """提取音标，优先美音"""
    content = word_data.get('content', {}).get('word', {}).get('content', {})
    usphone = content.get('usphone', '')
    ukphone = content.get('ukphone', '')
    
    phonetic = usphone if usphone else ukphone
    phonetic = replace_french_chars(phonetic)
    return phonetic.strip()

def extract_meanings(word_data: dict) -> List[str]:
    """提取释义"""
    content = word_data.get('content', {}).get('word', {}).get('content', {})
    trans = content.get('trans', [])
    
    meanings = []
    for t in trans:
        pos = t.get('pos', '').strip()
        tran_cn = t.get('tranCn', '').strip()
        tran_cn = replace_french_chars(tran_cn)
        
        if pos and tran_cn:
            if not pos.endswith('.'):
                pos = pos + '.'
            meanings.append(f"{pos} {tran_cn}")
        elif tran_cn:
            meanings.append(tran_cn)
    
    return meanings

def process_zip_file(zip_path: str, all_words: Dict[str, dict]) -> int:
    """处理ZIP文件"""
    count = 0
    
    with zipfile.ZipFile(zip_path, 'r') as zf:
        for name in zf.namelist():
            if name.endswith('.json'):
                with zf.open(name) as f:
                    content = f.read().decode('utf-8')
                    for line in content.strip().split('\n'):
                        line = line.strip()
                        if not line:
                            continue
                        
                        try:
                            word_data = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        
                        head_word = word_data.get('headWord', '').strip().lower()
                        if not head_word:
                            continue
                        
                        head_word = replace_french_chars(head_word)
                        
                        phonetic = extract_phonetic(word_data)
                        meanings = extract_meanings(word_data)
                        
                        if head_word not in all_words:
                            all_words[head_word] = {
                                'phonetic': phonetic,
                                'meanings': meanings
                            }
                        else:
                            if not all_words[head_word]['phonetic'] and phonetic:
                                all_words[head_word]['phonetic'] = phonetic
                            existing_meanings = set(all_words[head_word]['meanings'])
                            for m in meanings:
                                if m not in existing_meanings:
                                    all_words[head_word]['meanings'].append(m)
                                    existing_meanings.add(m)
                        
                        count += 1
    
    return count

def write_output(all_words: Dict[str, dict], output_path: str):
    """写入输出文件"""
    sorted_words = sorted(all_words.items(), key=lambda x: x[0])
    
    with open(output_path, 'w', encoding='utf-8') as f:
        for word, data in sorted_words:
            phonetic = data['phonetic']
            meanings = data['meanings']
            
            if phonetic:
                line = f"{word} [{phonetic}]"
            else:
                line = word
            
            if meanings:
                line = line + " " + " ".join(meanings)
            
            f.write(line + '\n')
    
    print(f"写入 {len(sorted_words)} 个单词到 {output_path}")

def main():
    dict_dir = r"D:\Downloads\dict-master\dict-master"
    book_dir = os.path.join(dict_dir, "book")
    output_path = r"D:\DevEcoStudioProjects\Vignette\entry\src\main\resources\rawfile\wordbooks\master.txt"
    
    all_words: Dict[str, dict] = {}
    total_count = 0
    
    if os.path.exists(book_dir):
        for filename in os.listdir(book_dir):
            if filename.endswith('.zip'):
                zip_path = os.path.join(book_dir, filename)
                print(f"处理: {filename}")
                count = process_zip_file(zip_path, all_words)
                total_count += count
                print(f"  -> {count} 个单词")
    
    print(f"\n总共处理: {total_count} 条记录")
    print(f"去重后: {len(all_words)} 个唯一单词")
    
    write_output(all_words, output_path)
    
    with_phonetic = sum(1 for w in all_words.values() if w['phonetic'])
    with_meanings = sum(1 for w in all_words.values() if w['meanings'])
    print(f"\n统计:")
    print(f"  有音标: {with_phonetic} ({with_phonetic*100/len(all_words):.1f}%)")
    print(f"  有释义: {with_meanings} ({with_meanings*100/len(all_words):.1f}%)")

if __name__ == '__main__':
    main()
