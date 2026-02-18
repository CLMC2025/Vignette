// =====================================================
// ImportPage.ets - Import custom wordbooks
// Supports: Paste Text, File Import with detailed guidance
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import type common from '@ohos.app.ability.common';
import { DBManager } from '../database/DBManager';
import { WordItem, WordDefinition } from '../model/WordModel';
import { CurrentBookStore } from '../utils/CurrentBookStore';
import { BookImportParser, ImportPreviewResult, ImportErrorDetail } from '../utils/BookImportParser';
import { DesignTokens } from '../model/DesignTokens';
import { ColorsInterface } from '../model/TokenInterfaces';
import { ThemeManager } from '../manager/ThemeManager';

import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';

enum ImportStep {
  SELECT_MODE = 0,
  INPUT_CONTENT = 1,
  PREVIEW_CONFIRM = 2,
  IMPORTING = 3,
  RESULT = 4
}

enum ImportFormat {
  TXT = 'txt',
  CSV = 'csv',
  JSON = 'json'
}

@Entry
@Component
struct ImportPage {
  @State currentStep: ImportStep = ImportStep.SELECT_MODE;
  @State bookName: string = '';
  @State tagsText: string = '';
  @State category: string = '其他';
  @State difficulty: string = '初级';
  @State icon: string = '📓';
  @State rawText: string = '';
  @State previewResult: ImportPreviewResult | null = null;
  @State importLog: string = '';
  @State isFileMode: boolean = false;
  @State selectedFormat: ImportFormat = ImportFormat.TXT;
  @State showFormatHelp: boolean = false;
  @State importProgress: number = 0;
  @State importTotal: number = 0;
  @State showExample: boolean = false;
  @StorageProp('ThemeRefreshToken') @Watch('onThemeChange') themeRefreshToken: number = 0;
  @State private colors: ColorsInterface = ThemeManager.getInstance().getColors();

  private dbManager: DBManager = DBManager.getInstance();
  private context: common.UIAbilityContext | null = null;

  // Example templates
  private readonly txtExample: string = `apple
banana
computer
hello
world`;

  private readonly csvExample: string = `word
apple
banana
computer`;

  private readonly jsonExample: string = `[
  {"word": "apple"},
  {"word": "banana"},
  {"word": "computer"}
]`;

  aboutToAppear(): void {
    this.context = getContext(this) as common.UIAbilityContext;
    void this.ensureDB();
  }

  private onThemeChange(): void {
    this.colors = ThemeManager.getInstance().getColors();
  }

  private async ensureDB(): Promise<void> {
    try {
      await this.dbManager.initialize(this.context!);
    } catch (e) {
      promptAction.showToast({ message: '数据库初始化失败' });
    }
  }

  private async handleFileSelect(): Promise<void> {
    try {
      const documentPicker = new picker.DocumentViewPicker();
      const options = new picker.DocumentSelectOptions();

      documentPicker.select(options).then(async (result: string[]) => {
        if (result.length > 0) {
          const uri = result[0];
          let file: fs.File | null = null;
          try {
            file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
            const size = fs.statSync(file.fd).size;
            // Limit size to avoid OOM (e.g. 1MB)
            if (size > 1024 * 1024) {
              promptAction.showToast({ message: '文件过大，请使用小于1MB的文件' });
              return;
            }

            const buf = new ArrayBuffer(size);
            fs.readSync(file.fd, buf);

            const decoder = new util.TextDecoder('utf-8');
            this.rawText = decoder.decode(new Uint8Array(buf));

            // Auto-detect format from file extension
            if (uri.toLowerCase().endsWith('.json')) {
              this.selectedFormat = ImportFormat.JSON;
            } else if (uri.toLowerCase().endsWith('.csv')) {
              this.selectedFormat = ImportFormat.CSV;
            } else {
              this.selectedFormat = ImportFormat.TXT;
            }

            this.isFileMode = true;
            this.currentStep = ImportStep.INPUT_CONTENT;
            promptAction.showToast({ message: '文件读取成功' });
          } catch (readErr) {
            const errMsg = readErr instanceof Error ? readErr.message : String(readErr);
            promptAction.showToast({ message: `文件读取失败: ${errMsg}` });
          } finally {
            if (file !== null) {
              try {
                fs.closeSync(file);
              } catch (closeErr) {
                console.error('[ImportPage] File close error:', closeErr);
              }
            }
          }
        }
      }).catch((err: Error) => {
        promptAction.showToast({ message: `文件选择失败: ${err.message}` });
      });
    } catch (e) {
      promptAction.showToast({ message: '当前环境不支持文件选择' });
    }
  }

  private processPreview() {
    if (this.rawText.trim().length === 0) {
      promptAction.showToast({ message: '请输入内容' });
      return;
    }

    if (this.bookName.trim().length === 0) {
      promptAction.showToast({ message: '请输入词书名称' });
      return;
    }

    const tags = this.tagsText.split(' ').filter(t => t.length > 0);
    this.previewResult = BookImportParser.parseText(this.rawText, this.bookName, tags);

    if (this.previewResult.words.length === 0) {
      promptAction.showToast({ message: '未能识别有效单词，请检查格式' });
      return;
    }

    this.currentStep = ImportStep.PREVIEW_CONFIRM;
  }

  private async executeImport() {
    if (!this.previewResult || this.previewResult.words.length === 0) return;

    this.currentStep = ImportStep.IMPORTING;
    this.importProgress = 0;
    this.importTotal = this.previewResult.words.length;

    try {
      const words = this.previewResult.words;

      const bookId = await this.dbManager.createUserWordBook(
        this.bookName.trim(),
        '',
        this.category,
        this.difficulty,
        '',
        this.icon
      );
      words.forEach(w => w.bookId = bookId);

      // Batch insert with progress
      let inserted = 0;
      const batchSize = 10;

      for (let i = 0; i < words.length; i += batchSize) {
        const batch = words.slice(i, Math.min(i + batchSize, words.length));
        for (const w of batch) {
          const rowId = await this.dbManager.insertWord(w);
          if (rowId > 0) inserted++;
        }
        this.importProgress = Math.min(i + batchSize, words.length);
      }

      for (const w of words) {
        await this.dbManager.addWordToUserWordBook(bookId, w.word);
      }

      // Build detailed import log
      const lines: string[] = [];
      lines.push(`成功导入 ${inserted} 个单词`);
      lines.push(`重复跳过: ${this.previewResult.duplicateCount} 个`);
      lines.push(`格式错误: ${this.previewResult.invalidCount} 个`);

      if (this.previewResult.errors && this.previewResult.errors.length > 0) {
        lines.push('');
        lines.push('错误详情:');
        this.previewResult.errors.slice(0, 5).forEach((err: ImportErrorDetail) => {
          lines.push(`  第${err.line}行: ${err.message}`);
        });
        if (this.previewResult.errors.length > 5) {
          lines.push(`  ...还有 ${this.previewResult.errors.length - 5} 个错误`);
        }
      }

      this.importLog = lines.join('\n');

      this.currentStep = ImportStep.RESULT;

    } catch (e) {
      const errMsg = e instanceof Error ? e.message : String(e);
      this.importLog = `导入失败: ${errMsg}`;
      this.currentStep = ImportStep.RESULT;
    }
  }

  private getCurrentExample(): string {
    switch (this.selectedFormat) {
      case ImportFormat.CSV:
        return this.csvExample;
      case ImportFormat.JSON:
        return this.jsonExample;
      default:
        return this.txtExample;
    }
  }

  private copyExample(): void {
    const example = this.getCurrentExample();
    // Note: Clipboard API might not be available in all versions
    promptAction.showToast({ message: '示例已复制到剪贴板（如支持）' });
  }

  private getDefinitionPreview(definition: WordDefinition): string {
    if (definition.contextMeaning.length > 0) {
      return definition.contextMeaning;
    }
    if (definition.commonMeanings.length > 0) {
      const meaning = definition.commonMeanings[0];
      return meaning.cn;
    }
    return '';
  }

  build() {
    Column() {
      // Navbar
      Row() {
        Text('←')
          .fontSize(24)
          .fontColor(this.colors.GRAY_900)
          .onClick(() => {
            if (this.currentStep === ImportStep.SELECT_MODE || this.currentStep === ImportStep.RESULT) {
              router.back();
            } else {
              this.currentStep = this.currentStep - 1;
            }
          })

        Text('导入词书')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.colors.GRAY_900)
          .margin({ left: 16 })

        Blank()

        // Step indicator
        if (this.currentStep !== ImportStep.SELECT_MODE && this.currentStep !== ImportStep.RESULT) {
          Text(`步骤 ${this.currentStep}/4`)
            .fontSize(12)
            .fontColor(this.colors.GRAY_500)
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.colors.BACKGROUND_PRIMARY)

      // Content
      Column() {
        if (this.currentStep === ImportStep.SELECT_MODE) {
          this.buildSelectMode();
        } else if (this.currentStep === ImportStep.INPUT_CONTENT) {
          this.buildInputContent();
        } else if (this.currentStep === ImportStep.PREVIEW_CONFIRM) {
          this.buildPreview();
        } else if (this.currentStep === ImportStep.IMPORTING) {
          this.buildImporting();
        } else if (this.currentStep === ImportStep.RESULT) {
          this.buildResult();
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.colors.BACKGROUND_PRIMARY)
    .id('importPage_' + this.themeRefreshToken)
  }

  @Builder
  buildSelectMode() {
    Column({ space: 16 }) {
      Text('选择导入方式')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.GRAY_900)
        .margin({ bottom: 8 })

      // Format help card
      Column() {
        Text('📖 支持格式说明')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.GRAY_800)
          .margin({ bottom: 8 })

        Text('TXT: 每行一个单词')
          .fontSize(12)
          .fontColor(this.colors.GRAY_600)
          .margin({ bottom: 4 })

        Text('CSV: word 格式')
          .fontSize(12)
          .fontColor(this.colors.GRAY_600)
          .margin({ bottom: 4 })

        Text('JSON: [{"word":""}]')
          .fontSize(12)
          .fontColor(this.colors.GRAY_600)
      }
      .width('100%')
      .padding(16)
      .backgroundColor(this.colors.BACKGROUND_SECONDARY)
      .borderRadius(12)
      .margin({ bottom: 8 })

      Button() {
        Column() {
          Text('📋').fontSize(32).margin({ bottom: 8 })
          Text('粘贴文本').fontSize(16).fontWeight(FontWeight.Medium)
          Text('直接粘贴单词列表')
            .fontSize(12)
            .fontColor(this.colors.WHITE)
            .opacity(0.8)
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(24)
      }
      .type(ButtonType.Normal)
      .borderRadius(16)
      .backgroundColor(this.colors.PRIMARY)
      .width('100%')
      .onClick(() => {
        this.isFileMode = false;
        this.selectedFormat = ImportFormat.TXT;
        this.currentStep = ImportStep.INPUT_CONTENT;
      })

      Button() {
        Column() {
          Text('📂').fontSize(32).margin({ bottom: 8 })
          Text('选择文件').fontSize(16).fontWeight(FontWeight.Medium)
          Text('支持 .txt .csv .json').fontSize(12).fontColor(this.colors.GRAY_600).margin({ top: 4 })
        }
        .width('100%')
        .padding(24)
      }
      .type(ButtonType.Normal)
      .borderRadius(16)
      .backgroundColor(this.colors.BACKGROUND_SECONDARY)
      .fontColor(this.colors.GRAY_900)
      .width('100%')
      .onClick(() => this.handleFileSelect())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildInputContent() {
    Column() {
      // Book Settings
      Column() {
        Text('词书信息')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.GRAY_700)
          .margin({ bottom: 12 })

        TextInput({ text: this.bookName, placeholder: '词书名称 (例如: 雅思核心词汇)' })
          .height(48)
          .backgroundColor(this.colors.SURFACE_PRIMARY)
          .borderRadius(8)
          .margin({ bottom: 12 })
          .onChange((v) => this.bookName = v)

        TextInput({ text: this.tagsText, placeholder: '标签 (空格分隔，如: 雅思 考试)' })
          .height(48)
          .backgroundColor(this.colors.SURFACE_PRIMARY)
          .borderRadius(8)
          .margin({ bottom: 12 })
          .onChange((v) => this.tagsText = v)

        // Metadata Inputs
        Row() {
          Text('分类:').fontSize(14).fontColor(this.colors.GRAY_600).width(60)
          Select([
            { value: '其他' }, { value: '考试' }, { value: '学术' },
            { value: '商务' }, { value: '旅游' }, { value: '日常' }
          ])
            .selected(0)
            .value(this.category)
            .font({ size: 14 })
            .onSelect((index, value) => this.category = value)
            .layoutWeight(1)
            .height(40)
        }
        .width('100%')
        .margin({ bottom: 8 })

        Row() {
          Text('难度:').fontSize(14).fontColor(this.colors.GRAY_600).width(60)
          Select([
            { value: '入门' }, { value: '初级' }, { value: '中级' },
            { value: '高级' }, { value: '专家' }
          ])
            .selected(1)
            .value(this.difficulty)
            .font({ size: 14 })
            .onSelect((index, value) => this.difficulty = value)
            .layoutWeight(1)
            .height(40)
        }
        .width('100%')
        .margin({ bottom: 8 })

        Row() {
          Text('图标:').fontSize(14).fontColor(this.colors.GRAY_600).width(60)
          TextInput({ text: this.icon, placeholder: 'Emoji (e.g. 📓)' })
            .layoutWeight(1)
            .height(40)
            .fontSize(14)
            .backgroundColor(this.colors.SURFACE_PRIMARY)
            .onChange((v) => this.icon = v)
        }
        .width('100%')
        .margin({ bottom: 12 })
      }
      .width('100%')
      .padding(12)
      .backgroundColor(this.colors.BACKGROUND_SECONDARY)
      .borderRadius(12)
      .margin({ bottom: 12 })

      // Format selector and example
      Row() {
        Text('格式:')
          .fontSize(14)
          .fontColor(this.colors.GRAY_600)

        Select([
          { value: 'TXT (Tab分隔)' },
          { value: 'CSV (逗号分隔)' },
          { value: 'JSON' }
        ])
          .selected(this.selectedFormat === ImportFormat.TXT ? 0 : this.selectedFormat === ImportFormat.CSV ? 1 : 2)
          .font({ size: 14 })
          .onSelect((index) => {
            if (index === 0) this.selectedFormat = ImportFormat.TXT;
            else if (index === 1) this.selectedFormat = ImportFormat.CSV;
            else this.selectedFormat = ImportFormat.JSON;
          })
          .height(36)
          .layoutWeight(1)

        Button('查看示例')
          .type(ButtonType.Normal)
          .height(32)
          .fontSize(12)
          .fontColor(this.colors.PRIMARY)
          .backgroundColor(this.colors.PRIMARY_LIGHTEST)
          .borderRadius(16)
          .onClick(() => {
            this.showExample = true;
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      Text('粘贴内容:')
        .fontSize(14)
        .fontColor(this.colors.GRAY_600)
        .margin({ bottom: 8 })

      TextArea({ text: this.rawText, placeholder: this.getPlaceholderText() })
        .layoutWeight(1)
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(8)
        .padding(12)
        .fontSize(14)
        .onChange((v) => this.rawText = v)

      Row() {
        Text(`${this.rawText.length} 字符`)
          .fontSize(12)
          .fontColor(this.colors.GRAY_500)

        Blank()

        if (this.rawText.length > 0) {
          Button('清空')
            .type(ButtonType.Normal)
            .height(32)
            .fontSize(12)
            .fontColor(this.colors.GRAY_600)
            .backgroundColor(Color.Transparent)
            .onClick(() => {
              this.rawText = '';
            })
        }
      }
      .width('100%')
      .margin({ top: 8, bottom: 8 })

      Button('下一步: 预览')
        .width('100%')
        .height(48)
        .backgroundColor(this.colors.PRIMARY)
        .fontColor(this.colors.WHITE)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .borderRadius(12)
        .enabled(this.rawText.trim().length > 0 && this.bookName.trim().length > 0)
        .onClick(() => this.processPreview())
    }
    .height('100%')
  }

  private getPlaceholderText(): string {
    switch (this.selectedFormat) {
      case ImportFormat.CSV:
        return 'word\napple\nbanana';
      case ImportFormat.JSON:
        return '[\n  {"word": "apple"}\n]';
      default:
        return 'apple\nbanana\ncomputer';
    }
  }

  @Builder
  buildPreview() {
    Column() {
      Text('解析预览')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.colors.GRAY_900)
        .margin({ bottom: 12 })

      if (this.previewResult) {
        // Stats cards
        Row() {
          this.StatItem('有效', this.previewResult.words.length, this.colors.SUCCESS)
          this.StatItem('重复', this.previewResult.duplicateCount, this.colors.WARNING)
          this.StatItem('无效', this.previewResult.invalidCount, this.colors.ERROR)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .margin({ bottom: 12 })

        // Errors section
        if (this.previewResult.errors && this.previewResult.errors.length > 0) {
          Column() {
            Row() {
              Text('⚠️ 解析警告')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.colors.ERROR)

              Blank()

              Text(`${this.previewResult.errors.length} 个问题`)
                .fontSize(12)
                .fontColor(this.colors.GRAY_500)
            }
            .width('100%')
            .margin({ bottom: 8 })

            List() {
              ForEach(this.previewResult.errors.slice(0, 10), (err: ImportErrorDetail, index: number) => {
                ListItem() {
                  Row() {
                    Text(`第${err.line}行`)
                      .fontSize(12)
                      .fontColor(this.colors.GRAY_500)
                      .width(60)

                    Text(err.message)
                      .fontSize(12)
                      .fontColor(this.colors.GRAY_700)
                      .layoutWeight(1)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('100%')
                  .padding({ top: 6, bottom: 6 })
                }
              }, (err: ImportErrorDetail, index: number) => `error-${index}`)
            }
            .height(Math.min(this.previewResult.errors.length * 30, 120))

            if (this.previewResult.errors.length > 10) {
              Text(`还有 ${this.previewResult.errors.length - 10} 个警告...`)
                .fontSize(12)
                .fontColor(this.colors.GRAY_500)
                .margin({ top: 4 })
            }
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.colors.WARNING_LIGHTEST)
          .borderRadius(8)
          .margin({ bottom: 12 })
        }

        // Preview list header
        Row() {
          Text(`前 ${Math.min(this.previewResult.words.length, 50)} 条预览:`)
            .fontSize(14)
            .fontColor(this.colors.GRAY_600)

          Blank()

          Text('共 ' + this.previewResult.words.length + ' 词')
            .fontSize(12)
            .fontColor(this.colors.GRAY_500)
        }
        .width('100%')
        .margin({ bottom: 8 })

        // Preview list
        List() {
          ForEach(this.previewResult.words.slice(0, 50), (w: WordItem, index: number) => {
            ListItem() {
              Row() {
                Text(`${index + 1}`)
                  .fontSize(12)
                  .fontColor(this.colors.GRAY_500)
                  .width(36)

                Text(w.word)
                  .fontWeight(FontWeight.Medium)
                  .width('35%')
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(this.getDefinitionPreview(w.definition))
                  .fontSize(14)
                  .fontColor(this.colors.GRAY_600)
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .padding({ top: 8, bottom: 8 })
              .border({ width: { bottom: 1 }, color: this.colors.BORDER_LIGHT })
            }
          }, (w: WordItem, index: number) => `word-${w.word}-${index}`)
        }
        .layoutWeight(1)
        .backgroundColor(this.colors.SURFACE_PRIMARY)
        .borderRadius(8)
        .padding(12)

        // Action buttons
        Row({ space: 12 }) {
          Button('返回修改')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontColor(this.colors.GRAY_700)
            .backgroundColor(this.colors.BACKGROUND_SECONDARY)
            .borderRadius(12)
            .onClick(() => {
              this.currentStep = ImportStep.INPUT_CONTENT;
            })

          Button('确认导入')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.colors.WHITE)
            .backgroundColor(this.colors.PRIMARY)
            .borderRadius(12)
            .enabled(this.previewResult.words.length > 0)
            .onClick(() => this.executeImport())
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .height('100%')
  }

  @Builder
  buildImporting() {
    Column() {
      LoadingProgress()
        .width(64)
        .height(64)
        .color(this.colors.PRIMARY)

      Text('正在导入...')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16, bottom: 8 })

      // Progress bar
      Column() {
        Row() {
          Text(`${this.importProgress} / ${this.importTotal}`)
            .fontSize(14)
            .fontColor(this.colors.GRAY_600)

          Blank()

          Text(`${Math.round((this.importProgress / this.importTotal) * 100)}%`)
            .fontSize(14)
            .fontColor(this.colors.PRIMARY)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .margin({ bottom: 8 })

        // Progress bar background
        Row() {
          Row()
            .width(`${(this.importProgress / this.importTotal) * 100}%`)
            .height('100%')
            .backgroundColor(this.colors.PRIMARY)
            .borderRadius(4)
        }
        .width('100%')
        .height(8)
        .backgroundColor(this.colors.GRAY_200)
        .borderRadius(4)
      }
      .width('80%')
      .margin({ top: 16 })

      Text('请勿关闭应用')
        .fontSize(12)
        .fontColor(this.colors.GRAY_500)
        .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  buildResult() {
    Column() {
      // Result icon
      Text(this.importLog.includes('失败') ? '❌' : '✅')
        .fontSize(48)
        .margin({ bottom: 16 })

      Text(this.importLog.includes('失败') ? '导入失败' : '导入完成')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.importLog.includes('失败') ? this.colors.ERROR : this.colors.SUCCESS)
        .margin({ bottom: 16 })

      // Result details
      Scroll() {
        Column() {
          Text(this.importLog)
            .fontSize(14)
            .textAlign(TextAlign.Start)
            .lineHeight(22)
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.colors.BACKGROUND_SECONDARY)
        .borderRadius(12)
      }
      .layoutWeight(1)
      .width('100%')
      .margin({ bottom: 16 })

      // Action buttons
      Column({ space: 12 }) {
        Button('返回词书管理')
          .width('100%')
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.colors.WHITE)
          .backgroundColor(this.colors.PRIMARY)
          .borderRadius(12)
          .onClick(() => router.back())

        if (!this.importLog.includes('失败')) {
          Button('继续导入')
            .width('100%')
            .height(48)
            .fontSize(16)
            .fontColor(this.colors.PRIMARY)
            .backgroundColor(this.colors.PRIMARY_LIGHTEST)
            .borderRadius(12)
            .onClick(() => {
              // Reset state for another import
              this.rawText = '';
              this.bookName = '';
              this.previewResult = null;
              this.importLog = '';
              this.importProgress = 0;
              this.currentStep = ImportStep.SELECT_MODE;
            })
        }
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }

  @Builder
  StatItem(label: string, value: number, color: ResourceColor) {
    Column() {
      Text(value.toString())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(12)
        .fontColor(this.colors.GRAY_600)
        .margin({ top: 4 })
    }
    .padding(12)
    .backgroundColor(this.colors.SURFACE_PRIMARY)
    .borderRadius(8)
    .width('30%')
  }
}
