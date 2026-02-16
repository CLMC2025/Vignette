import { DesignTokens } from '../model/DesignTokens';
import { BookCategory, BookDifficulty } from '../model/WordBookCatalog';

export type SortType = 'Default' | 'Name' | 'Progress' | 'Count';
export type SourceType = 'All' | 'System' | 'User';

export interface FilterOptions {
  category: BookCategory | 'All' | string;
  difficulty: BookDifficulty | 'All' | string;
  sort: SortType;
  view: 'Grid' | 'List';
  tag: string;
  source: SourceType;
}

@Component
export struct FilterBar {
  @Link filter: FilterOptions;
  @Link searchText: string;
  private readonly sortOptions: Array<SortType> = ['Default', 'Name', 'Progress', 'Count'];
  @Prop categoryOptions: string[] = ['All'];
  @Prop difficultyOptions: string[] = ['All'];
  @Prop tagOptions: string[] = [];
  @Prop sourceOptions: string[] = ['All', 'System', 'User'];

  build() {
    Column() {
      // Search Row
      Row() {
        // Search Input
        Row() {
          Text('🔍')
            .fontSize(16)
            .fontColor(DesignTokens.Colors.GRAY_500)
            .margin({ right: 8 })

          TextInput({ text: this.searchText, placeholder: '搜索词书...' })
            .layoutWeight(1)
            .height(36)
            .fontSize(14)
            .backgroundColor(Color.Transparent)
            .onChange((value: string) => this.searchText = value)
        }
        .layoutWeight(1)
        .height(40)
      .backgroundColor(DesignTokens.Colors.BACKGROUND_SECONDARY)
        .borderRadius(20)
        .padding({ left: 12, right: 12 })

        // View Toggle
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Text(this.filter.view === 'Grid' ? '≣' : '⊞')
            .fontSize(20)
            .fontColor(DesignTokens.Colors.GRAY_700)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .margin({ left: 8 })
        .onClick(() => {
          this.filter.view = this.filter.view === 'Grid' ? 'List' : 'Grid';
        })
      }
      .width('100%')

      // Filter Chips Row (Horizontal Scroll)
      Scroll() {
        Row() {
          ForEach(this.categoryOptions, (cat: string) => {
            this.buildFilterChip(this.getCategoryLabel(cat), this.filter.category === cat, () => this.filter.category = cat as BookCategory | 'All' | string)
          }, (cat: string) => cat)
        }
        .padding({ top: 12, bottom: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .align(Alignment.Start)

      Scroll() {
        Row() {
          ForEach(this.difficultyOptions, (level: string) => {
            this.buildFilterChip(this.getDifficultyLabel(level), this.filter.difficulty === level, () => this.filter.difficulty = level as BookDifficulty | 'All' | string)
          }, (level: string) => level)
        }
        .padding({ top: 4, bottom: 4 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .align(Alignment.Start)

      Scroll() {
        Row() {
          ForEach(this.sortOptions, (sort: SortType) => {
            this.buildFilterChip(this.getSortLabel(sort), this.filter.sort === sort, () => this.filter.sort = sort)
          }, (sort: string) => sort)
        }
        .padding({ top: 4, bottom: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .align(Alignment.Start)

      if (this.tagOptions.length > 0) {
        Scroll() {
          Row() {
            ForEach(this.tagOptions, (tag: string) => {
              this.buildFilterChip(this.getTagLabel(tag), this.filter.tag === tag, () => this.filter.tag = tag)
            }, (tag: string) => tag)
          }
          .padding({ top: 4, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .align(Alignment.Start)
      }

      Scroll() {
        Row() {
          ForEach(this.sourceOptions, (source: string) => {
            this.buildFilterChip(this.getSourceLabel(source), this.filter.source === source, () => this.filter.source = source as SourceType)
          }, (source: string) => source)
        }
        .padding({ top: 4, bottom: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .align(Alignment.Start)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
    .backgroundColor(DesignTokens.Colors.SURFACE_PRIMARY)
  }

  @Builder
  buildFilterChip(label: string, isSelected: boolean, onClick: () => void) {
    Text(label)
      .fontSize(12)
      .fontColor(isSelected ? DesignTokens.Colors.WHITE : DesignTokens.Colors.GRAY_700)
      .backgroundColor(isSelected ? DesignTokens.Colors.PRIMARY : DesignTokens.Colors.BACKGROUND_SECONDARY)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(16)
      .margin({ right: 8 })
      .onClick(onClick)
  }

  private getSortLabel(sort: SortType): string {
    if (sort === 'Default') {
      return '默认排序';
    }
    if (sort === 'Name') {
      return '按名称';
    }
    if (sort === 'Progress') {
      return '按进度';
    }
    return '按词量';
  }

  private getCategoryLabel(cat: string): string {
    if (cat === 'All') {
      return '全部';
    }
    return cat;
  }

  private getDifficultyLabel(level: string): string {
    if (level === 'All') {
      return '全部难度';
    }
    return level;
  }

  private getTagLabel(tag: string): string {
    if (tag === 'All') {
      return '全部标签';
    }
    return tag;
  }

  private getSourceLabel(source: string): string {
    if (source === 'All') {
      return '全部来源';
    }
    if (source === 'System') {
      return '系统词书';
    }
    return '我的词书';
  }
}
