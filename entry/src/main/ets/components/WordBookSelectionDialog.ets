/**
 * WordBookSelectionDialog - 词书选择对话框
 * 用于选择用户个人词书或创建新词书
 */

import { UserStateManager, UserWordState } from '../manager/UserStateManager';
import { DBManager, UserWordBook } from '../database/DBManager';
import { BookCategory, BookDifficulty } from '../model/WordBookCatalog';
import { DesignTokens } from '../model/DesignTokens';

/**
 * 词书选择结果
 */
export interface WordBookSelectionResult {
  success: boolean;
  selectedBookId?: string;
  error?: string;
}

/**
 * 词书选择对话框组件
 */
@Component
export struct WordBookSelectionDialog {
  @State private userWordBooks: UserWordBook[] = [];
  @State private showCreateForm: boolean = false;
  @State private newBookName: string = '';
  @State private newBookCategory: string = '其他';
  @State private newBookDifficulty: string = '初级';
  @State private newBookCover: string[] = ['#a8edea', '#fed6e3'];
  @State private isCreating: boolean = false;
  @State private selectedBookId: string = '';
  
  // 回调函数
  private onSelectionComplete?: (result: WordBookSelectionResult) => void;
  private onDismiss?: () => void;
  
  // 管理器实例
  private dbManager: DBManager = DBManager.getInstance();
  private userStateManager: UserStateManager = UserStateManager.getInstance();
  
  aboutToAppear() {
    this.loadUserWordBooks();
  }
  
  /**
   * 加载用户个人词书
   */
  private async loadUserWordBooks(): Promise<void> {
    try {
      // 从数据库加载用户创建的个人词书
      const userBooks = await this.dbManager.getUserWordBooks();
      this.userWordBooks = userBooks.filter((book: UserWordBook): boolean => book.isUserCreated);
      
      console.log(`[WordBookSelectionDialog] Loaded ${this.userWordBooks.length} user word books`);
    } catch (error) {
      console.error('[WordBookSelectionDialog] Failed to load user word books:', error);
      this.userWordBooks = [];
    }
  }
  
  /**
   * 创建新词书
   */
  private async createNewWordBook(): Promise<void> {
    if (this.newBookName.trim().length === 0) {
      this.showError('请输入词书名称');
      return;
    }
    
    if (this.newBookName.trim().length > 20) {
      this.showError('词书名称不能超过20个字符');
      return;
    }
    
    this.isCreating = true;
    
    try {
      const now = Date.now();
      const bookId = await this.dbManager.createUserWordBook(
        this.newBookName.trim(),
        '用户自定义词书',
        this.newBookCategory,
        this.newBookDifficulty,
        JSON.stringify(this.newBookCover),
        '📓'
      );

      const newBook: UserWordBook = {
        id: bookId,
        name: this.newBookName.trim(),
        description: '用户自定义词书',
        wordCount: 0,
        isUserCreated: true,
        createdAt: now,
        updatedAt: now,
        category: this.newBookCategory,
        difficulty: this.newBookDifficulty,
        coverColor: JSON.stringify(this.newBookCover),
        icon: '📓'
      };
      
      // 更新本地列表
      this.userWordBooks.push(newBook);
      this.newBookName = '';
      this.showCreateForm = false;
      
      console.log(`[WordBookSelectionDialog] Created new word book: ${newBook.name}`);
      
      // 自动选择新创建的词书
      this.selectWordBook(newBook.id);
      
    } catch (error) {
      console.error('[WordBookSelectionDialog] Failed to create word book:', error);
      this.showError('创建词书失败，请重试');
    } finally {
      this.isCreating = false;
    }
  }
  
  /**
   * 选择词书
   */
  private selectWordBook(bookId: string): void {
    this.selectedBookId = bookId;
    
    // 完成选择
    if (this.onSelectionComplete) {
      this.onSelectionComplete({
        success: true,
        selectedBookId: bookId
      });
    }
    
    // 关闭对话框
    if (this.onDismiss) {
      this.onDismiss();
    }
  }
  
  /**
   * 取消选择
   */
  private cancelSelection(): void {
    if (this.onSelectionComplete) {
      this.onSelectionComplete({
        success: false,
        error: '用户取消了选择'
      });
    }
    
    if (this.onDismiss) {
      this.onDismiss();
    }
  }
  
  /**
   * 显示错误信息
   */
  private showError(message: string): void {
    // 这里可以集成到现有的错误提示系统中
    console.error(`[WordBookSelectionDialog] Error: ${message}`);
  }
  
  build() {
    Column() {
      // 标题
      Row() {
        Text('选择词书')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
        
        Blank()
        
        Text('✕')
          .fontSize(20)
          .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
          .onClick(() => this.cancelSelection())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      
      // 内容区域
      Stack() {
        if (this.showCreateForm) {
          // 创建新词书表单
          Column() {
            Text('创建新词书')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
              .margin({ bottom: 16 })
            
            TextInput({ placeholder: '请输入词书名称', text: this.newBookName })
              .width('100%')
              .height(48)
              .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
              .borderRadius(8)
              .padding({ left: 16, right: 16 })
              .maxLength(20)
              .onChange((value: string) => {
                this.newBookName = value;
              })
              .margin({ bottom: 16 })
            
            Row() {
              Text('分类: ').fontSize(14).fontColor(DesignTokens.Colors.TEXT_SECONDARY)
              Select([
                { value: '其他' }, { value: '考试' }, { value: '学术' }, 
                { value: '商务' }, { value: '旅游' }, { value: '日常' }
              ])
              .selected(0)
              .value(this.newBookCategory)
              .font({ size: 14 })
              .onSelect((index, value) => this.newBookCategory = value)
              .height(36)
              
              Blank()
              
              Text('难度: ').fontSize(14).fontColor(DesignTokens.Colors.TEXT_SECONDARY)
              Select([
                { value: '入门' }, { value: '初级' }, { value: '中级' }, 
                { value: '高级' }, { value: '专家' }
              ])
              .selected(1)
              .value(this.newBookDifficulty)
              .font({ size: 14 })
              .onSelect((index, value) => this.newBookDifficulty = value)
              .height(36)
            }
            .width('100%')
            .margin({ bottom: 20 })
            
            Row() {
              Button('取消')
                .width(100)
                .height(40)
                .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
                .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
                .onClick(() => {
                  this.showCreateForm = false;
                  this.newBookName = '';
                })
              
              Blank()
              
              Button(this.isCreating ? '创建中...' : '确认创建')
                .width(120)
                .height(40)
                .backgroundColor(DesignTokens.Colors.PRIMARY)
                .fontColor(DesignTokens.Colors.WHITE)
                .enabled(!this.isCreating)
                .onClick(() => this.createNewWordBook())
            }
            .width('100%')
          }
          .width('100%')
          .padding(20)
          
        } else {
          // 词书选择列表
          Column() {
            if (this.userWordBooks.length === 0) {
              // 空状态 - 引导创建
              Column() {
                Text('📚')
                  .fontSize(48)
                  .margin({ bottom: 16 })
                
                Text('还没有创建词书')
                  .fontSize(16)
                  .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
                  .margin({ bottom: 8 })
                
                Text('创建你的第一个词书，开始收集单词吧！')
                  .fontSize(14)
                  .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
                  .textAlign(TextAlign.Center)
                  .margin({ bottom: 24 })
                
                Button('创建词书')
                  .width(160)
                  .height(44)
                  .backgroundColor(DesignTokens.Colors.PRIMARY)
                  .fontColor(DesignTokens.Colors.WHITE)
                  .borderRadius(22)
                  .onClick(() => this.showCreateForm = true)
              }
              .width('100%')
              .padding(40)
              .alignItems(HorizontalAlign.Center)
              
            } else {
              // 词书列表
              List() {
                ForEach(this.userWordBooks, (book: UserWordBook) => {
                  ListItem() {
                    Row() {
                      Column() {
                        Text(book.name)
                          .fontSize(16)
                          .fontWeight(FontWeight.Medium)
                        .fontColor(DesignTokens.Colors.TEXT_PRIMARY)
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .width('100%')
                        
                        Text(`${book.wordCount} 词`)
                          .fontSize(14)
                        .fontColor(DesignTokens.Colors.TEXT_TERTIARY)
                          .margin({ top: 4 })
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                      
                      Radio({ value: book.id, group: 'wordbook_selection' })
                        .checked(this.selectedBookId === book.id)
                        .onChange((isChecked: boolean) => {
                          if (isChecked) {
                            this.selectedBookId = book.id;
                          }
                        })
                    }
                    .width('100%')
                    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
                    .backgroundColor(this.selectedBookId === book.id ? DesignTokens.Colors.PRIMARY_LIGHTEST : DesignTokens.Colors.SURFACE_PRIMARY)
                    .onClick(() => this.selectWordBook(book.id))
                  }
                }, (book: UserWordBook) => book.id)
              }
              .width('100%')
              .layoutWeight(1)
              .divider({ strokeWidth: 1, color: DesignTokens.Colors.BORDER_LIGHT })
              
              // 创建新词书按钮
              Button('创建新词书')
                .width('90%')
                .height(44)
                .backgroundColor(Color.Transparent)
                .fontColor(DesignTokens.Colors.PRIMARY)
                .borderWidth(1)
                .borderColor(DesignTokens.Colors.PRIMARY)
                .borderRadius(22)
                .margin({ top: 16, bottom: 16 })
                .onClick(() => this.showCreateForm = true)
            }
          }
          .width('100%')
        }
      }
      .layoutWeight(1)
      .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
      
      // 底部操作按钮
      if (!this.showCreateForm && this.userWordBooks.length > 0) {
        Row() {
          Button('取消')
            .layoutWeight(1)
            .height(48)
            .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
            .fontColor(DesignTokens.Colors.TEXT_SECONDARY)
            .margin({ right: 12 })
            .onClick(() => this.cancelSelection())
          
          Button('确认选择')
            .layoutWeight(1)
            .height(48)
            .backgroundColor(this.selectedBookId ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.GRAY_300)
            .fontColor(DesignTokens.Colors.WHITE)
            .enabled(this.selectedBookId.length > 0)
            .onClick(() => {
              if (this.selectedBookId) {
                this.selectWordBook(this.selectedBookId);
              }
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, bottom: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
    .borderRadius({ topLeft: 16, topRight: 16 })
  }
}
