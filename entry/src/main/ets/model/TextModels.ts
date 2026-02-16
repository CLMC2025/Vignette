
export type TextSourceType = 'paste' | 'file';

export class TextItem {
  id: number;
  title: string;
  content: string;
  sourceType: TextSourceType;
  sourceRef: string;
  createdAt: number;
  updatedAt: number;

  constructor(
    id: number,
    title: string,
    content: string,
    sourceType: TextSourceType = 'paste',
    sourceRef: string = '',
    createdAt: number = Date.now(),
    updatedAt: number = Date.now()
  ) {
    this.id = id;
    this.title = title;
    this.content = content;
    this.sourceType = sourceType;
    this.sourceRef = sourceRef;
    this.createdAt = createdAt;
    this.updatedAt = updatedAt;
  }

  clone(): TextItem {
    return new TextItem(
      this.id,
      this.title,
      this.content,
      this.sourceType,
      this.sourceRef,
      this.createdAt,
      this.updatedAt
    );
  }
}

