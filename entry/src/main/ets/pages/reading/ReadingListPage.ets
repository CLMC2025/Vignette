// =====================================================
// ReadingListPage.ets - Reading Materials List
// Shows imported reading materials
// =====================================================

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { DeckManager } from '../../manager/DeckManager';
import { Deck } from '../../model/DeckModel';

/**
 * ReadingMaterial interface (simplified)
 */
interface ReadingMaterial {
  id: number;
  title: string;
  wordCount: number;
  progress: number; // percentage
  deckId: number | null;
}

/**
 * ReadingListPage - List of reading materials
 */
@Entry
@Component
struct ReadingListPage {
  @State private materials: ReadingMaterial[] = [];
  @State private isLoading: boolean = true;
  @State private showImportDialog: boolean = false;
  @State private importTitle: string = '';
  @State private importContent: string = '';
  
  private deckManager: DeckManager = DeckManager.getInstance();
  
  async aboutToAppear(): Promise<void> {
    await this.loadMaterials();
  }
  
  /**
   * Load reading materials
   */
  private async loadMaterials(): Promise<void> {
    try {
      this.isLoading = true;
      
      // Get all reading decks
      const decks = await this.deckManager.getDecksWithStats();
      const readingDecks = decks.filter(d => d.isReadingDeck());
      
      // Convert to materials (simplified)
      this.materials = readingDecks.map(deck => ({
        id: deck.sourceId ?? deck.id,
        title: deck.name,
        wordCount: deck.stats ? deck.stats.totalCount : 0,
        progress: 0,
        deckId: deck.id
      }));
    } catch (error) {
      console.error('[ReadingListPage] Failed to load materials:', error);
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }
  
  /**
   * Open reading page
   */
  private openReading(material: ReadingMaterial): void {
    if (!material.deckId) {
      promptAction.showToast({ message: '无效的阅读材料' });
      return;
    }
    
    router.pushUrl({
      url: 'pages/reading/ReadingPage',
      params: {
        deckId: material.deckId,
        materialId: material.id,
        title: material.title
      }
    });
  }
  
  /**
   * Import new reading material
   */
  private async importMaterial(): Promise<void> {
    if (!this.importTitle || !this.importContent) {
      promptAction.showToast({ message: '请输入标题和内容' });
      return;
    }
    
    try {
      // Create reading deck
      const deck = await this.deckManager.createReadingDeck(
        Date.now(), // Use timestamp as materialId
        this.importTitle
      );
      
      promptAction.showToast({ message: `已导入: ${this.importTitle}` });
      
      // Reset dialog
      this.showImportDialog = false;
      this.importTitle = '';
      this.importContent = '';
      
      // Reload materials
      await this.loadMaterials();
    } catch (error) {
      console.error('[ReadingListPage] Failed to import:', error);
      promptAction.showToast({ message: '导入失败' });
    }
  }
  
  build() {
    Column() {
      // Header
      Row() {
        Button('←')
          .fontSize(18)
          .backgroundColor(Color.Transparent)
          .fontColor('#333333')
          .onClick(() => router.back())
        
        Text('阅读材料')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ left: 16 })
        
        Spacer()
        
        // Import button
        Button({ type: ButtonType.Circle }) {
          Text('+')
            .fontSize(24)
            .fontColor(Color.White)
        }
        .width(40)
        .height(40)
        .backgroundColor('#2196F3')
        .onClick(() => this.showImportDialog = true)
      }
      .width('100%')
      .padding(16)
      
      if (this.isLoading) {
        // Loading state
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.materials.length === 0) {
        // Empty state
        Column() {
          Text('📖')
            .fontSize(48)
          Text('还没有阅读材料')
            .fontSize(18)
            .fontColor('#333333')
            .margin({ top: 16 })
          Text('点击右上角 + 号导入文章')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 8 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        // Materials list
        List({ space: 12 }) {
          ForEach(this.materials, (material: ReadingMaterial) => {
            ListItem() {
              this.buildMaterialCard(material)
            }
          }, (material: ReadingMaterial) => material.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      
      // Import dialog
      if (this.showImportDialog) {
        this.buildImportDialog()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
  
  /**
   * Build material card
   */
  @Builder
  private buildMaterialCard(material: ReadingMaterial) {
    Column() {
      Text(material.title)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      
      Row({ space: 16 }) {
        Text(`${material.wordCount} 个单词`)
          .fontSize(14)
          .fontColor('#999999')
        
        if (material.progress > 0) {
          Text(`进度: ${material.progress}%`)
            .fontSize(14)
            .fontColor('#2196F3')
        }
      }
      .margin({ top: 8 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({ radius: 4, color: '#10000000', offsetY: 2 })
    .onClick(() => this.openReading(material))
  }
  
  /**
   * Build import dialog
   */
  @Builder
  private buildImportDialog() {
    Column() {
      Column({ space: 16 }) {
        Text('导入阅读材料')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
        
        TextInput({ placeholder: '标题' })
          .onChange((value: string) => {
            this.importTitle = value;
          })
        
        TextArea({ placeholder: '粘贴文章内容...' })
          .height(200)
          .onChange((value: string) => {
            this.importContent = value;
          })
        
        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .backgroundColor('#EEEEEE')
            .fontColor('#333333')
            .onClick(() => {
              this.showImportDialog = false;
              this.importTitle = '';
              this.importContent = '';
            })
          
          Button('导入')
            .layoutWeight(1)
            .backgroundColor('#2196F3')
            .onClick(() => this.importMaterial())
        }
      }
      .width('90%')
      .padding(24)
      .backgroundColor(Color.White)
      .borderRadius(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.5)')
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.showImportDialog = false)
  }
}
