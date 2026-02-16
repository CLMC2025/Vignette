
import { ColorsInterface } from './TokenInterfaces';

export enum ThemeType {
  LIGHT = 'light',
  DARK = 'dark'
}

export interface Theme {
  id: string;
  name: string;
  type: ThemeType;
  colors: ColorsInterface;
  isCustom?: boolean;
}

export interface ThemePalette {
  primary: string;
  secondary: string;
  background: string;
  surface: string;
}
